import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/conversation/data/conversation_outbox_database.dart';
import 'package:squadly/features/conversation/data/drift_conversation_outbox.dart';
import 'package:squadly/features/conversation/data/outbox_key_vault.dart';
import 'package:squadly/features/conversation/domain/pending_operation.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_submission.dart';

const squad = '00000000-0000-4000-8000-000000000001';
const nonce = '00000000-0000-4000-8000-000000000002';
const parent = '00000000-0000-4000-8000-000000000003';
PhotoImage image() => PhotoImage(
  bytes: File('test/features/photos/fixtures/sanitized.jpg').readAsBytesSync(),
  width: 4,
  height: 3,
  sha256: '9c4ad0cc80a44a2d234c284e474e8feff187fb71a568f3b09d6c5737e49e0cd5',
);
PendingPhotoOperation attempt() => PendingPhotoOperation(
  userId: 'alice',
  squadId: squad,
  squadName: '只有本机可读的队名',
  clientNonce: nonce,
  createdAt: DateTime.utc(2026, 10, 28),
  image: image(),
  replyToEntryId: parent,
);

class Vault implements OutboxKeyVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late ConversationOutboxDatabase db;
  late Vault vault;
  late DriftConversationOutbox store;
  setUp(() {
    db = ConversationOutboxDatabase(NativeDatabase.memory());
    vault = Vault();
    store = DriftConversationOutbox(database: db, vault: vault);
  });
  tearDown(() => db.close());

  test('photo bytes, target name and parent are encrypted in a v3 envelope and restored immutably', () async {
    final photo = attempt();
    await store.put(photo);
    final row = (await db.listEncrypted(
      userId: 'alice',
      squadId: squad,
      planId: '',
    )).single;
    expect(jsonDecode(row.encryptedPayload)['version'], 3);
    for (final private in [
      photo.squadName,
      parent,
      photo.image.sha256,
      base64Encode(photo.image.bytes),
    ]) {
      expect(row.encryptedPayload, isNot(contains(private)));
    }
    final recovered =
        (await DriftConversationOutbox(
              database: db,
              vault: vault,
            ).listFor(userId: 'alice', squadId: squad)).single
            as PendingPhotoOperation;
    expect(sameConfirmedPhoto(recovered.draft, photo.draft), isTrue);
    expect(recovered.planId, isNull);
    expect(() => recovered.image.bytes[0] = 0, throwsUnsupportedError);
    expect(await store.listFor(userId: 'bob', squadId: squad), isEmpty);
    expect(
      await store.listFor(userId: 'alice', squadId: squad, planId: 'private'),
      isEmpty,
    );
  });

  test('fixed legacy v1 and v2 ciphertext coexist with photo v3 without rewriting', () async {
    final fixture = jsonDecode(
      File('test/features/conversation/fixtures/outbox-v1-v2.json')
          .readAsStringSync(),
    ) as Map;
    vault.values['squadly.outbox.v1.${base64Url.encode(utf8.encode('alice'))}'] =
        fixture['test_key'] as String;
    for (final raw in fixture['rows'] as List) {
      final r = raw as Map;
      await db.putEncrypted(
        EncryptedOutboxEntry(
          userId: r['user_id'] as String,
          squadId: r['squad_id'] as String,
          planId: r['plan_id'] as String,
          clientNonce: r['client_nonce'] as String,
          createdAtMicros: r['created_at_micros'] as int,
          encryptedPayload: r['encrypted_payload'] as String,
        ),
      );
    }
    await store.put(attempt());
    final general =
        (await store.listFor(userId: 'alice', squadId: 'squad-a')).single
            as PendingTextOperation;
    final plan =
        (await store.listFor(
              userId: 'alice',
              squadId: 'squad-a',
              planId: 'plan-a',
            )).single
            as PendingTextOperation;
    expect(general.body, 'legacy v1 text');
    expect(plan.body, 'legacy v2 text');
    expect(
      (await store.listFor(userId: 'alice', squadId: squad)).single,
      isA<PendingPhotoOperation>(),
    );
    final unchanged = (await db.listEncrypted(
      userId: 'alice',
      squadId: 'squad-a',
      planId: '',
    )).single;
    expect(
      unchanged.encryptedPayload,
      (fixture['rows'] as List).first['encrypted_payload'],
    );
    expect(
      (await db.customSelect('PRAGMA user_version').get()).single.read<int>(
        'user_version',
      ),
      2,
    );
  });

  test('same nonce cannot replace parent, time or pixels through a recreated adapter', () async {
    final photo = attempt();
    await store.put(photo);
    final fresh = DriftConversationOutbox(database: db, vault: vault);
    await fresh.put(attempt());
    for (final changed in [
      photo.copyWith(
        image: PhotoImage(
          bytes: File('test/features/photos/fixtures/alternate-sanitized.jpg')
              .readAsBytesSync(),
          width: 4,
          height: 3,
          sha256: '4017b042fe0c61a3d26c617b519cb31a90c16b328e990a9f2f7e1077aa297cbb',
        ),
      ),
      photo.copyWith(replyToEntryId: null),
      photo.copyWith(
        createdAt: photo.createdAt.add(const Duration(seconds: 1)),
      ),
      photo.copyWith(squadName: 'replacement'),
    ]) {
      await expectLater(fresh.put(changed), throwsFormatException);
    }
    expect(
      sameConfirmedPhoto(
        ((await fresh.listFor(userId: 'alice', squadId: squad)).single
                as PendingPhotoOperation)
            .draft,
        photo.draft,
      ),
      isTrue,
    );
  });

  for (final field in [
    'user',
    'squad',
    'plan',
    'nonce',
    'time',
    'version',
    'ciphertext',
  ]) {
    test('changing photo authenticated $field fails closed', () async {
      await store.put(attempt());
      final row = (await db.listEncrypted(
        userId: 'alice',
        squadId: squad,
        planId: '',
      )).single;
      final otherUser = field == 'user' ? 'bob' : row.userId;
      final otherSquad = field == 'squad'
          ? '00000000-0000-4000-8000-000000000004'
          : row.squadId;
      final otherPlan = field == 'plan' ? 'private-plan' : '';
      final sealed = jsonDecode(row.encryptedPayload) as Map<String, dynamic>;
      if (field == 'version') sealed['version'] = 1;
      if (field == 'ciphertext') sealed['ciphertext'] = base64Encode([1, 2, 3]);
      if (field == 'user') {
        vault.values['squadly.outbox.v1.${base64Url.encode(utf8.encode('bob'))}'] =
            vault.values.values.single;
      }
      await db.customStatement('DELETE FROM outbox_entries');
      await db.putEncrypted(
        EncryptedOutboxEntry(
          userId: otherUser,
          squadId: otherSquad,
          planId: otherPlan,
          clientNonce: field == 'nonce' ? 'other' : row.clientNonce,
          createdAtMicros: row.createdAtMicros + (field == 'time' ? 1 : 0),
          encryptedPayload: jsonEncode(sealed),
        ),
      );
      await expectLater(
        DriftConversationOutbox(database: db, vault: vault).listFor(
          userId: otherUser,
          squadId: otherSquad,
          planId: otherPlan.isEmpty ? null : otherPlan,
        ),
        throwsA(isA<OutboxPayloadUnavailable>()),
      );
    });
  }

  test('invalid prepared checksum or identity fails before generating a key or saving', () async {
    final photo = attempt();
    final invalid = PhotoImage(
      bytes: photo.image.bytes,
      width: 4,
      height: 3,
      sha256: 'a' * 64,
    );
    for (final changed in [
      photo.copyWith(image: invalid),
      photo.copyWith(clientNonce: 'not-uuid'),
      photo.copyWith(replyToEntryId: 'not-uuid'),
    ]) {
      await expectLater(store.put(changed), throwsFormatException);
    }
    expect(vault.values, isEmpty);
    expect(await store.listFor(userId: 'alice', squadId: squad), isEmpty);
  });

  test(
    'encrypted photo survives SQLite file close/reopen with same vault',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'squadly-photo-outbox-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/outbox.sqlite');
      var disk = ConversationOutboxDatabase(NativeDatabase(file));
      final photo = attempt();
      await DriftConversationOutbox(database: disk, vault: vault).put(photo);
      await disk.close();
      disk = ConversationOutboxDatabase(NativeDatabase(file));
      try {
        final recovered =
            (await DriftConversationOutbox(
                  database: disk,
                  vault: vault,
                ).listFor(userId: 'alice', squadId: squad)).single
                as PendingPhotoOperation;
        expect(sameConfirmedPhoto(recovered.draft, photo.draft), isTrue);
      } finally {
        await disk.close();
      }
    },
  );
}
