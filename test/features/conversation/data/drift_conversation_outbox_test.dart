import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/conversation_outbox_database.dart';
import 'package:squadly/features/conversation/data/drift_conversation_outbox.dart';
import 'package:squadly/features/conversation/data/outbox_key_vault.dart';
import 'package:squadly/features/conversation/domain/pending_operation.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  // The reopen test deliberately opens the same SQLite file twice in sequence.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late ConversationOutboxDatabase database;
  late _MemoryKeyVault vault;

  setUp(() {
    database = ConversationOutboxDatabase(NativeDatabase.memory());
    vault = _MemoryKeyVault();
  });

  tearDown(() async => database.close());

  test('text remains encrypted across adapter recreation', () async {
    const body = '一段只应保存在加密本机队列里的聊天正文';
    final firstAdapter = DriftConversationOutbox(
      database: database,
      vault: vault,
    );
    await firstAdapter.put(
      PendingConversationOperation.text(
        userId: 'alice',
        squadId: 'squad-a',
        clientNonce: 'nonce-1',
        createdAt: DateTime.utc(2026, 10, 10, 12),
        body: body,
        replyToEntryId: 'reply-1',
      ),
    );
    final stored = (await database.listEncrypted(
      userId: 'alice',
      squadId: 'squad-a',
      planId: '',
    )).single;
    expect(stored.encryptedPayload, isNot(contains(body)));

    final reopened = DriftConversationOutbox(database: database, vault: vault);
    final recovered =
        (await reopened.listFor(userId: 'alice', squadId: 'squad-a')).single
            as PendingTextOperation;
    expect(recovered.body, body);
    expect(recovered.replyToEntryId, 'reply-1');
    expect(recovered.clientNonce, 'nonce-1');
  });

  test('outbox survives closing and reopening its SQLite file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'squadly-outbox-reopen-',
    );
    final file = File('${directory.path}/outbox.sqlite');
    final firstDatabase = ConversationOutboxDatabase(NativeDatabase(file));
    await DriftConversationOutbox(
      database: firstDatabase,
      vault: vault,
    ).put(_textAttempt(userId: 'alice', squadId: 'squad-a'));
    await firstDatabase.close();

    final reopenedDatabase = ConversationOutboxDatabase(NativeDatabase(file));
    try {
      final reopened = DriftConversationOutbox(
        database: reopenedDatabase,
        vault: vault,
      );
      final pending = await reopened.listFor(
        userId: 'alice',
        squadId: 'squad-a',
      );
      expect(pending, hasLength(1));
      expect((pending.single as PendingTextOperation).body, 'hello');
    } finally {
      await reopenedDatabase.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'version 2 rebuilds the key while preserving version 1 queue rows',
    () async {
      final legacyExecutor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE outbox_entries (
            user_id TEXT NOT NULL,
            squad_id TEXT NOT NULL,
            client_nonce TEXT NOT NULL,
            created_at_micros INTEGER NOT NULL,
            encrypted_payload TEXT NOT NULL,
            PRIMARY KEY (user_id, squad_id, client_nonce)
          )
        ''');
          database.execute('''
          INSERT INTO outbox_entries (
            user_id, squad_id, client_nonce, created_at_micros,
            encrypted_payload
          ) VALUES ('alice', 'squad-a', 'nonce-1', 1, 'sealed-v1')
        ''');
          database.execute('PRAGMA user_version = 1');
        },
      );
      final upgraded = ConversationOutboxDatabase(legacyExecutor);
      addTearDown(upgraded.close);

      final rows = await upgraded
          .customSelect('PRAGMA table_info(outbox_entries)')
          .get();
      final planId = rows.singleWhere(
        (row) => row.read<String>('name') == 'plan_id',
      );
      expect(planId.read<int>('pk'), 3);
      expect(
        (await upgraded
                .customSelect('SELECT plan_id FROM outbox_entries')
                .get())
            .single
            .read<String>('plan_id'),
        '',
      );
      expect(
        (await upgraded.listEncrypted(
          userId: 'alice',
          squadId: 'squad-a',
          planId: '',
        )).single.encryptedPayload,
        'sealed-v1',
      );
    },
  );

  test(
    'card snapshot and encrypted route round-trip without exposing data',
    () async {
      final secret = _routeBundle();
      final adapter = DriftConversationOutbox(database: database, vault: vault);
      await adapter.put(
        PendingConversationOperation.card(
          userId: 'alice',
          squadId: 'squad-a',
          clientNonce: 'card-nonce',
          createdAt: DateTime.utc(2026, 10, 10, 12),
          cardId: 'card-1',
          snapshot: CardSnapshot(
            kind: CardKind.activity,
            payload: const {
              'title': '今日跑步',
              'distance_m': 5000,
              'avg_heart_rate_bpm': 128,
              'confirmed_sensitive_fields': ['avg_heart_rate_bpm'],
            },
            hasEncryptedRoute: true,
          ),
          encryptedRoute: secret,
        ),
      );
      final row = (await database.listEncrypted(
        userId: 'alice',
        squadId: 'squad-a',
        planId: '',
      )).single;
      expect(row.encryptedPayload, isNot(contains('今日跑步')));
      expect(row.encryptedPayload, isNot(contains('ciphertext-from-route')));

      final recovered =
          (await DriftConversationOutbox(
                database: database,
                vault: vault,
              ).listFor(userId: 'alice', squadId: 'squad-a')).single
              as PendingCardOperation;
      expect(recovered.cardId, 'card-1');
      expect(recovered.snapshot.payload['avg_heart_rate_bpm'], 128);
      expect(recovered.encryptedRoute?.toJson(), secret.toJson());
    },
  );

  test('queue reads are scoped to both account and squad', () async {
    final adapter = DriftConversationOutbox(database: database, vault: vault);
    await adapter.put(_textAttempt(userId: 'alice', squadId: 'squad-a'));
    await adapter.put(_textAttempt(userId: 'bob', squadId: 'squad-a'));
    await adapter.put(_textAttempt(userId: 'alice', squadId: 'squad-b'));

    final aliceA = await adapter.listFor(userId: 'alice', squadId: 'squad-a');
    expect(aliceA, hasLength(1));
    expect(aliceA.single.userId, 'alice');
    expect(aliceA.single.squadId, 'squad-a');
    expect(
      await adapter.listFor(userId: 'charlie', squadId: 'squad-a'),
      isEmpty,
    );
  });

  test('plan discussion retries are isolated by plan id', () async {
    final adapter = DriftConversationOutbox(database: database, vault: vault);
    for (final planId in ['plan-a', 'plan-b']) {
      await adapter.put(
        PendingConversationOperation.text(
          userId: 'alice',
          squadId: 'squad-a',
          planId: planId,
          clientNonce: 'nonce-$planId',
          createdAt: DateTime.utc(2026, 10, 10, 12),
          body: 'belongs to $planId',
        ),
      );
    }

    final planA = await adapter.listFor(
      userId: 'alice',
      squadId: 'squad-a',
      planId: 'plan-a',
    );
    final planB = await adapter.listFor(
      userId: 'alice',
      squadId: 'squad-a',
      planId: 'plan-b',
    );
    final general = await adapter.listFor(userId: 'alice', squadId: 'squad-a');

    expect((planA.single as PendingTextOperation).body, 'belongs to plan-a');
    expect((planB.single as PendingTextOperation).body, 'belongs to plan-b');
    expect(general, isEmpty);
  });

  test('a lost local key never gets silently replaced', () async {
    final adapter = DriftConversationOutbox(database: database, vault: vault);
    await adapter.put(_textAttempt(userId: 'alice', squadId: 'squad-a'));
    vault.values.clear();

    final reopened = DriftConversationOutbox(database: database, vault: vault);
    await expectLater(
      reopened.listFor(userId: 'alice', squadId: 'squad-a'),
      throwsA(isA<OutboxKeyUnavailable>()),
    );
    await expectLater(
      reopened.put(_textAttempt(userId: 'alice', squadId: 'squad-b')),
      throwsA(isA<OutboxKeyUnavailable>()),
    );
    expect(vault.values, isEmpty);
  });

  test('tampered encrypted payload is rejected', () async {
    final adapter = DriftConversationOutbox(database: database, vault: vault);
    await adapter.put(_textAttempt(userId: 'alice', squadId: 'squad-a'));
    await (database.update(
      database.outboxEntries,
    )..where((row) => row.userId.equals('alice'))).write(
      const OutboxEntriesCompanion(encryptedPayload: Value('tampered')),
    );

    await expectLater(
      adapter.listFor(userId: 'alice', squadId: 'squad-a'),
      throwsA(isA<OutboxPayloadUnavailable>()),
    );
  });
}

PendingConversationOperation _textAttempt({
  required String userId,
  required String squadId,
}) => PendingConversationOperation.text(
  userId: userId,
  squadId: squadId,
  clientNonce: '$userId-$squadId',
  createdAt: DateTime.utc(2026, 10, 10),
  body: 'hello',
);

EncryptedRouteBundle _routeBundle() => EncryptedRouteBundle(
  route: const RouteCiphertext(
    nonce: 'nonce-from-route',
    ciphertext: 'ciphertext-from-route',
    mac: 'mac-from-route',
  ),
  envelopes: const [],
);

final class _MemoryKeyVault implements OutboxKeyVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
