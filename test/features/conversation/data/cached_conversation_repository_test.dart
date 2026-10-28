import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/data/cached_conversation_repository.dart';
import 'package:squadly/features/conversation/data/conversation_cache_database.dart';
import 'package:squadly/features/conversation/data/drift_conversation_cache.dart';
import 'package:squadly/features/conversation/data/outbox_key_vault.dart';
import 'package:squadly/features/conversation/domain/conversation_photo_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

void main() {
  late ConversationCacheDatabase db;
  late DriftConversationCache cache;
  late _Remote remote;
  late CachedConversationRepository repository;
  var current = true;
  setUp(() {
    current = true;
    db = ConversationCacheDatabase(NativeDatabase.memory());
    cache = DriftConversationCache(database: db, vault: _Vault());
    remote = _Remote();
    repository = CachedConversationRepository(
      remote: remote,
      cache: cache,
      userId: 'a',
      isCurrentAccount: () => current,
    );
  });
  tearDown(() => db.close());
  test(
    'photo head network failure has no conversation cache fallback',
    () async {
      await repository.loadRecent('s');
      remote.headResult = left(const Failure.network());
      expect(
        (await repository.photoHead('s')).getLeft().toNullable(),
        isA<NetworkFailure>(),
      );
    },
  );
  test(
    'account switch rejects a late head including a valid empty version',
    () async {
      remote.headGate = Completer();
      final pending = repository.photoHead('s');
      current = false;
      remote.headGate!.complete(right(const PhotoHead(revision: '9')));
      expect(
        (await pending).getLeft().toNullable(),
        isA<UnauthorizedFailure>(),
      );
    },
  );
  test('clearing cache invalidates the in-flight head lease', () async {
    remote.headGate = Completer();
    final pending = repository.photoHead('s');
    await cache.clearUser('a');
    remote.headGate!.complete(right(const PhotoHead(revision: '9')));
    expect((await pending).getLeft().toNullable(), isA<UnauthorizedFailure>());
  });
  test(
    'photo queries never fall back to the downloaded conversation',
    () async {
      await repository.loadRecent('s');
      remote.result = left(const Failure.network());
      expect(
        (await repository.pagePhotos('s')).getLeft().toNullable(),
        isA<NetworkFailure>(),
      );
      expect((await cache.page(cache.lease('a')!, 's')).single.text, 'hello');
    },
  );
  test('cache invalidation rejects an older photo query response', () async {
    remote.gate = Completer();
    final pending = repository.pagePhotos('s');
    await cache.clearUser('a');
    remote.gate!.complete(right([]));
    expect((await pending).getLeft().toNullable(), isA<UnauthorizedFailure>());
  });
  test('account change rejects an older photo lookup', () async {
    remote.photoGate = Completer();
    final pending = repository.findPhoto(squadId: 's', messageId: 'one');
    current = false;
    remote.photoGate!.complete(right(null));
    expect((await pending).getLeft().toNullable(), isA<UnauthorizedFailure>());
  });
  test('expired local access cannot use network fallback and does not delete records', () async {
    await repository.loadRecent('s');
    remote.result = left(const Failure.network());
    repository = CachedConversationRepository(
      remote: remote,
      cache: cache,
      userId: 'a',
      isCurrentAccount: () => true,
      canReadCache: () => false,
    );
    expect(
      (await repository.loadRecent('s')).getLeft().toNullable(),
      isA<UnauthorizedFailure>(),
    );
    expect((await cache.page(cache.lease('a')!, 's')).single.text, 'hello');
  });
  test(
    'successful read persists; network failure returns marked local copy',
    () async {
      expect((await repository.loadRecent('s')).isRight(), isTrue);
      remote.result = left(const Failure.network());
      final local = (await repository.loadRecent('s'))
          .getRight()
          .toNullable()!
          .single;
      expect(local.text, 'hello');
      expect(local.isLocalCopy, isTrue);
      remote.result = right([_entry('one')]);
      expect(
        (await repository.loadRecent('s'))
            .getRight()
            .toNullable()!
            .single
            .isLocalCopy,
        isFalse,
      );
    },
  );
  test(
    'permission denial never falls back or deletes retained local copy',
    () async {
      await repository.loadRecent('s');
      for (final failure in [
        const Failure.permissionDenied(),
        const Failure.unauthorized(),
        const Failure.notFound(),
        const Failure.server(message: 'bad format'),
      ]) {
        remote.result = left(failure);
        expect(
          (await repository.loadRecent('s')).getLeft().toNullable(),
          failure,
        );
      }
      expect((await cache.page(cache.lease('a')!, 's')).single.text, 'hello');
    },
  );
  test(
    'network failure without downloaded records remains a failure',
    () async {
      remote.result = left(const Failure.network());
      expect((await repository.loadRecent('s')).isLeft(), isTrue);
    },
  );
  test('offline pagination uses downloaded cursor boundaries', () async {
    await cache.save(cache.lease('a')!, 's', [
      _entry('a'),
      _entry('b'),
      _entry('c'),
    ]);
    remote.result = left(const Failure.network());
    final older = (await repository.loadBefore(
      's',
      _entry('b').cursor,
    )).getRight().toNullable()!;
    final newer = (await repository.loadAfter(
      's',
      _entry('b').cursor,
    )).getRight().toNullable()!;
    expect(older.single.id, 'a');
    expect(newer.single.id, 'c');
  });
  test(
    'manual clear prevents an older in-flight read from repopulating cache',
    () async {
      remote.gate = Completer();
      final request = repository.loadRecent('s');
      await cache.clearUser('a');
      remote.gate!.complete(right([_entry('late')]));
      expect((await request).isRight(), isTrue);
      expect(await cache.page(cache.lease('a')!, 's'), isEmpty);
    },
  );
  test(
    'account change ignores stale response and prevents its cache write',
    () async {
      remote.gate = Completer();
      final request = repository.loadRecent('s');
      current = false;
      await cache.clearUser('a', suspend: true);
      remote.gate!.complete(right([_entry('late')]));
      expect(
        (await request).getLeft().toNullable(),
        isA<UnauthorizedFailure>(),
      );
      cache.resumeUser('a');
      expect(await cache.page(cache.lease('a')!, 's'), isEmpty);
    },
  );
  test(
    'successful sends are cached; failed sends never enter the sent cache',
    () async {
      await repository.sendText(
        squadId: 's',
        body: 'hello',
        clientNonce: 'one',
      );
      expect((await cache.page(cache.lease('a')!, 's')).single.text, 'hello');
      await cache.clearUser('a');
      remote.sendResult = left(const Failure.network());
      await repository.sendText(
        squadId: 's',
        body: 'pending',
        clientNonce: 'two',
      );
      expect(await cache.page(cache.lease('a')!, 's'), isEmpty);
    },
  );
  test(
    'cache write failure does not turn server success into a failed send',
    () async {
      final broken = DriftConversationCache(
        database: db,
        vault: _Vault()..fail = true,
      );
      repository = CachedConversationRepository(
        remote: remote,
        cache: broken,
        userId: 'a',
        isCurrentAccount: () => true,
      );
      expect(
        (await repository.sendText(
          squadId: 's',
          body: 'hello',
          clientNonce: 'one',
        )).isRight(),
        isTrue,
      );
    },
  );
}

TimelineEntry _entry(String id) => TimelineEntry(
  id: id,
  squadId: 's',
  authorId: 'a',
  authorName: 'A',
  kind: TimelineEntryKind.text,
  text: 'hello',
  clientNonce: id,
  createdAt: DateTime.utc(2026),
);

class _Remote implements ConversationRepository, ConversationPhotoRepository {
  Completer<Either<Failure, TimelineEntry?>>? photoGate;
  Completer<Either<Failure, PhotoHead>>? headGate;
  Either<Failure, PhotoHead> headResult = right(const PhotoHead(revision: '0'));
  @override
  Future<Either<Failure, PhotoHead>> photoHead(String squadId) async =>
      headGate == null ? headResult : headGate!.future;
  @override
  Future<Either<Failure, List<TimelineEntry>>> pagePhotos(
    String squadId, {
    TimelineCursor? before,
    int limit = 50,
  }) async => gate == null ? result : gate!.future;
  @override
  Future<Either<Failure, TimelineEntry?>> findPhoto({
    required String squadId,
    required String messageId,
  }) async => photoGate == null ? right(null) : photoGate!.future;
  Either<Failure, List<TimelineEntry>> result = right([_entry('one')]);
  Either<Failure, TimelineEntry> sendResult = right(_entry('one'));
  Completer<Either<Failure, List<TimelineEntry>>>? gate;
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => gate == null ? result : gate!.future;
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => result;
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => result;
  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async => sendResult;
  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
