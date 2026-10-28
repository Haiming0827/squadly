import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/conversation_cache_database.dart';
import 'package:squadly/features/conversation/data/drift_conversation_cache.dart';
import 'package:squadly/features/conversation/data/outbox_key_vault.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photos/domain/photo.dart';

void main() {
  late ConversationCacheDatabase db;
  late _Vault vault;
  late DriftConversationCache cache;
  setUp(() {
    db = ConversationCacheDatabase(NativeDatabase.memory());
    vault = _Vault();
    cache = DriftConversationCache(database: db, vault: vault);
  });
  tearDown(() => db.close());

  test('photo metadata and tombstones round-trip beside legacy text in encrypted cache', () async {
    final photo = TimelineEntry(
      id: 'photo-message',
      squadId: 's',
      authorId: 'a',
      authorName: 'A',
      kind: TimelineEntryKind.photo,
      clientNonce: 'photo-nonce',
      createdAt: DateTime.utc(2026),
      replyToEntryId: 'parent',
      photo: const PhotoAttachment(
        mediaId: 'media-id',
        width: 4,
        height: 3,
        byteLength: 600,
        isRevoked: true,
      ),
    );
    final lease = cache.lease('a')!;
    await cache.save(lease, 's', [_entry('legacy-text'), photo]);
    final entries = await cache.page(lease, 's');
    expect(
      entries.map((e) => e.id),
      containsAll(['legacy-text', 'photo-message']),
    );
    final restored = entries.singleWhere(
      (e) => e.kind == TimelineEntryKind.photo,
    );
    expect(restored.photo, photo.photo);
    expect(restored.replyToEntryId, 'parent');
    expect(restored.asLocalCopy().isLocalCopy, isTrue);
    expect(restored.cardSnapshot, isNull);
    final rows = await db
        .customSelect('SELECT encrypted_payload FROM cached_timeline_entries')
        .get();
    expect(
      rows.map((r) => r.read<String>('encrypted_payload')).join(),
      isNot(contains('media-id')),
    );
    expect(await cache.page(cache.lease('b')!, 's'), isEmpty);
  });

  test(
    'interrupted account-switch recovery removes other users only',
    () async {
      await cache.save(cache.lease('a')!, 's', [_entry('old-a')]);
      await cache.save(cache.lease('b')!, 's', [_entry('current-b')]);
      await cache.rememberThread(cache.lease('a')!, 's', 'old account label');
      await cache.clearOtherUsers('b');
      expect(cache.lease('a'), isNull);
      expect(await db.pageRows(userId: 'a', squadId: 's', planId: ''), isEmpty);
      expect(await db.labelFor('a', 's', ''), isNull);
      expect((await cache.page(cache.lease('b')!, 's')).single.id, 'current-b');
    },
  );

  test('latest authenticated account supersedes a pending cleanup', () async {
    await cache.save(cache.lease('a')!, 's', [_entry('current-a')]);
    await cache.save(cache.lease('b')!, 's', [_entry('old-b')]);
    await Future.wait([cache.clearOtherUsers('b'), cache.clearOtherUsers('a')]);
    expect((await cache.page(cache.lease('a')!, 's')).single.id, 'current-a');
    expect(await db.pageRows(userId: 'b', squadId: 's', planId: ''), isEmpty);
  });

  test(
    'encrypted catalog preserves Squad/plan labels and previews by account',
    () async {
      final a = cache.lease('a')!;
      await cache.save(a, 's', [_entry('general')]);
      await cache.save(a, 's', [_entry('plan', planId: 'p')], planId: 'p');
      await cache.rememberThread(a, 's', 'private squad');
      await cache.rememberThread(
        a,
        's',
        'private squad',
        planId: 'p',
        planTitle: 'private plan',
      );
      final threads = await cache.threads(a);
      expect(
        threads.map((thread) => thread.title),
        containsAll(['private squad', 'private plan']),
      );
      expect(threads.every((thread) => thread.latestEntry.isLocalCopy), isTrue);
      expect(await cache.threads(cache.lease('b')!), isEmpty);
      final label = (await db.labelFor('a', 's', 'p'))!;
      expect(label.encryptedPayload, isNot(contains('private squad')));
      expect(label.encryptedPayload, isNot(contains('private plan')));
      await cache.clearUser('a');
      expect(await cache.threads(cache.lease('a')!), isEmpty);
      expect(await db.labelFor('a', 's', 'p'), isNull);
    },
  );

  test(
    'v1 upgrade retains encrypted messages and supplies fallback labels',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'squadly-cache-upgrade',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/cache.sqlite');
      await db.close();
      db = ConversationCacheDatabase(NativeDatabase(file));
      var store = DriftConversationCache(database: db, vault: vault);
      await store.save(store.lease('a')!, 's', [_entry('legacy')]);
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE cached_conversation_labels');
      raw.execute('PRAGMA user_version = 1');
      raw.close();
      db = ConversationCacheDatabase(NativeDatabase(file));
      store = DriftConversationCache(database: db, vault: vault);
      final threads = await store.threads(store.lease('a')!);
      expect(threads.single.title, '小队会话');
      expect(threads.single.latestEntry.text, 'private body');
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        2,
      );
      await store.rememberThread(store.lease('a')!, 's', 'restored title');
      expect(
        (await store.threads(store.lease('a')!)).single.title,
        'restored title',
      );
    },
  );

  test('thread label ciphertext cannot be reassigned to a plan', () async {
    final a = cache.lease('a')!;
    await cache.save(a, 's', [_entry('plan', planId: 'p')], planId: 'p');
    await cache.rememberThread(a, 's', 'sealed squad');
    await db.customStatement(
      "UPDATE cached_conversation_labels SET plan_id = 'p'",
    );
    await expectLater(cache.threads(a), throwsA(anything));
  });

  test(
    'ciphertext hides body and author; downloaded history never expires',
    () async {
      final lease = cache.lease('a')!;
      await cache.save(lease, 's', [_entry('one')]);
      final row = (await db.pageRows(
        userId: 'a',
        squadId: 's',
        planId: '',
      )).single;
      expect(row.encryptedPayload, isNot(contains('private body')));
      expect(row.encryptedPayload, isNot(contains('private author')));
      final entries = await cache.page(lease, 's');
      expect(entries.single.text, 'private body');
      expect(entries.single.createdAt.year, 2020);
    },
  );
  test('file reopen retains records using the independent cache key', () async {
    final directory = await Directory.systemTemp.createTemp(
      'squadly-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/cache.sqlite');
    await db.close();
    var persistent = ConversationCacheDatabase(NativeDatabase(file));
    db = persistent;
    var store = DriftConversationCache(database: persistent, vault: vault);
    await store.save(store.lease('a')!, 's', [_entry('one')]);
    await persistent.close();
    persistent = ConversationCacheDatabase(NativeDatabase(file));
    db = persistent;
    store = DriftConversationCache(database: persistent, vault: vault);
    expect((await store.page(store.lease('a')!, 's')).single.id, 'one');
  });
  test('account, Squad and private plan scopes stay separate', () async {
    final a = cache.lease('a')!;
    await cache.save(a, 's', [_entry('general')]);
    await cache.save(a, 's', [_entry('plan', planId: 'p')], planId: 'p');
    expect((await cache.page(a, 's')).single.id, 'general');
    expect((await cache.page(a, 's', planId: 'p')).single.id, 'plan');
    expect(await cache.page(a, 'other'), isEmpty);
    expect(await cache.page(cache.lease('b')!, 's'), isEmpty);
    await expectLater(
      cache.save(a, 'other', [_entry('bad')]),
      throwsFormatException,
    );
  });
  test('50-row pagination uses stable ID when timestamps match', () async {
    final a = cache.lease('a')!;
    await cache.save(a, 's', [
      for (var i = 0; i < 55; i++) _entry(i.toString().padLeft(3, '0')),
    ]);
    final recent = await cache.page(a, 's');
    expect(recent, hasLength(50));
    expect(recent.first.id, '005');
    final older = await cache.page(a, 's', before: recent.first.cursor);
    expect(older.map((e) => e.id), ['000', '001', '002', '003', '004']);
    final newer = await cache.page(a, 's', after: recent[47].cursor);
    expect(newer.map((e) => e.id), ['053', '054']);
  });
  test('AAD rejects copying a row into another account', () async {
    await cache.save(cache.lease('a')!, 's', [_entry('one')]);
    vault.values[vault.values.keys.single.replaceFirst('YQ==', 'Yg==')] =
        vault.values.values.single;
    await db.customStatement(
      "UPDATE cached_timeline_entries SET user_id = 'b'",
    );
    await expectLater(cache.page(cache.lease('b')!, 's'), throwsA(anything));
  });
  test('tampered encrypted bytes are never returned', () async {
    await cache.save(cache.lease('a')!, 's', [_entry('one')]);
    await db.customStatement(
      "UPDATE cached_timeline_entries SET encrypted_payload = '{}'",
    );
    await expectLater(cache.page(cache.lease('a')!, 's'), throwsA(anything));
  });
  test('clear rotates key, preserves other account and outbox key, invalidates old writes', () async {
    final a = cache.lease('a')!;
    await cache.save(a, 's', [_entry('one')]);
    await cache.save(cache.lease('b')!, 's', [_entry('two')]);
    vault.values['squadly.outbox.v1.a'] = 'outbox-key';
    final oldKey = vault.values.values.first;
    await cache.clearUser('a');
    await cache.save(a, 's', [_entry('late')]);
    expect(await cache.page(cache.lease('a')!, 's'), isEmpty);
    expect((await cache.page(cache.lease('b')!, 's')).single.id, 'two');
    expect(vault.values.values.first, isNot(oldKey));
    expect(vault.values['squadly.outbox.v1.a'], 'outbox-key');
  });
  test('sign-out suspension blocks leases until a new login', () async {
    final old = cache.lease('a')!;
    await cache.clearUser('a', suspend: true);
    expect(cache.lease('a'), isNull);
    cache.resumeUser('a');
    expect(cache.isValid(old), isFalse);
    expect(cache.lease('a'), isNotNull);
  });
  test('missing key and failed clear fail closed', () async {
    await cache.save(cache.lease('a')!, 's', [_entry('one')]);
    vault.values.clear();
    await expectLater(cache.page(cache.lease('a')!, 's'), throwsStateError);
    vault.fail = true;
    await expectLater(cache.clearUser('a', suspend: true), throwsStateError);
    expect(cache.lease('a'), isNull);
  });
  test('card snapshot round-trips; no route payload is stored', () async {
    final card = TimelineEntry(
      id: 'card-message',
      squadId: 's',
      authorId: 'a',
      authorName: 'A',
      kind: TimelineEntryKind.card,
      clientNonce: 'c',
      createdAt: DateTime.utc(2026),
      cardId: 'card',
      cardSnapshot: CardSnapshot(
        kind: CardKind.activity,
        payload: {
          'activity_type': 'run',
          'distance_m': 1234,
          'avg_heart_rate_bpm': 120,
          'confirmed_sensitive_fields': ['avg_heart_rate_bpm'],
        },
        hasEncryptedRoute: true,
      ),
    );
    final a = cache.lease('a')!;
    await cache.save(a, 's', [card]);
    final restored = (await cache.page(a, 's')).single;
    expect(restored.cardSnapshot!.payload['avg_heart_rate_bpm'], 120);
    expect(restored.cardSnapshot!.hasEncryptedRoute, isTrue);
  });
}

TimelineEntry _entry(String id, {String? planId}) => TimelineEntry(
  id: id,
  squadId: 's',
  planId: planId,
  authorId: 'a',
  authorName: 'private author',
  kind: TimelineEntryKind.text,
  text: 'private body',
  clientNonce: 'nonce-$id',
  createdAt: DateTime.utc(2020),
);

class _Vault implements OutboxKeyVault {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }
}
