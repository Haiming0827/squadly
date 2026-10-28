import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/memory_conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/pending_operation.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_controller.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  test('recent reload replaces photo with tombstone and preserves older history without duplicates', () async {
    final repository = _MemoryConversationRepository();
    addTearDown(repository.dispose);
    final photo = TimelineEntry(
      id: 'photo',
      squadId: 'squad-a',
      authorId: 'alice',
      authorName: 'A',
      kind: TimelineEntryKind.photo,
      clientNonce: 'nonce',
      createdAt: DateTime.utc(2026),
      photo: const PhotoAttachment(
        mediaId: 'media',
        width: 4,
        height: 3,
        byteLength: 600,
        isRevoked: false,
      ),
    );
    repository._entries.add(photo);
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.sendText('older retained message');
    repository._entries
      ..clear()
      ..add(
        TimelineEntry(
          id: photo.id,
          squadId: photo.squadId,
          authorId: photo.authorId,
          authorName: photo.authorName,
          kind: photo.kind,
          clientNonce: photo.clientNonce,
          createdAt: photo.createdAt,
          photo: photo.photo!.copyWith(isRevoked: true),
        ),
      );
    await controller.reloadRecent();
    expect(controller.state.entries, hasLength(2));
    expect(
      controller.state.entries
          .singleWhere((e) => e.id == 'photo')
          .photo!
          .isRevoked,
      isTrue,
    );
    expect(
      controller.state.entries.where((e) => e.text == 'older retained message'),
      hasLength(1),
    );
  });
  for (final phase in ['list', 'put']) {
    for (final card in [false, true]) {
      test(
        'disposing during outbox $phase prevents ${card ? 'card' : 'text'} send',
        () async {
          final repository = _MemoryConversationRepository();
          addTearDown(repository.dispose);
          final outbox = _BlockingOutbox(phase);
          final controller = ConversationController(
            repository: repository,
            outbox: outbox,
            squadId: 'squad-a',
            currentUserId: 'alice',
          );
          final sending = card
              ? controller.publishCard(
                  cardId: 'card-a',
                  snapshot: CardSnapshot(
                    kind: CardKind.activity,
                    payload: const {'title': '跑步'},
                  ),
                )
              : controller.sendText('账号切换前确认的消息');
          await outbox.entered.future;
          controller.dispose();
          outbox.release.complete();

          expect((await sending).isLeft(), isTrue);
          expect(repository.sentPlanIds, isEmpty);
          expect(repository.publishCalls, 0);
          final retained = await outbox.storage.listFor(
            userId: 'alice',
            squadId: 'squad-a',
          );
          expect(retained, hasLength(phase == 'put' ? 1 : 0));
          expect(
            await outbox.storage.listFor(userId: 'bob', squadId: 'squad-a'),
            isEmpty,
          );
        },
      );
    }
  }

  test('a disposed controller rejects retained send callbacks', () async {
    final repository = _MemoryConversationRepository();
    addTearDown(repository.dispose);
    final outbox = MemoryConversationOutbox();
    final controller = ConversationController(
      repository: repository,
      outbox: outbox,
      squadId: 'squad-a',
      currentUserId: 'alice',
    )..dispose();

    expect(
      (await controller.sendText(
        '旧回调',
        replyToEntryId: 'old-message',
      )).isLeft(),
      isTrue,
    );
    expect(
      (await controller.publishCard(
        cardId: 'old-card',
        snapshot: CardSnapshot(
          kind: CardKind.activity,
          payload: const {'title': '跑步'},
        ),
      )).isLeft(),
      isTrue,
    );
    expect(repository.sentPlanIds, isEmpty);
    expect(repository.publishCalls, 0);
    expect(await outbox.listFor(userId: 'alice', squadId: 'squad-a'), isEmpty);
  });

  test(
    'disposing during local acknowledgement keeps server success authoritative',
    () async {
      final repository = _MemoryConversationRepository();
      addTearDown(repository.dispose);
      final outbox = _BlockingOutbox('remove');
      final controller = ConversationController(
        repository: repository,
        outbox: outbox,
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      final sending = controller.sendText('已送达消息');
      await outbox.entered.future;
      controller.dispose();
      outbox.release.complete();

      expect((await sending).isRight(), isTrue);
      expect(repository.sentPlanIds, hasLength(1));
      expect(
        await outbox.storage.listFor(userId: 'alice', squadId: 'squad-a'),
        isEmpty,
      );
    },
  );

  test('a sent text remains one entry after realtime refresh', () async {
    final repository = _MemoryConversationRepository();
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(() {
      controller.dispose();
      repository.dispose();
    });

    await controller.initialize();
    await controller.sendText('今晚一起跑');
    repository.notifyChange();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.entries, hasLength(1));
    expect(controller.state.entries.single.text, '今晚一起跑');
  });

  test('plan discussion sends stay inside their plan target', () async {
    final repository = _MemoryConversationRepository();
    addTearDown(repository.dispose);
    final controller = ConversationController(
      squadId: 'squad-a',
      planId: 'plan-a',
      repository: repository,
      outbox: MemoryConversationOutbox(),
      currentUserId: 'alice',
    );
    addTearDown(controller.dispose);

    final result = await controller.sendText('集合时间定好了');

    expect(result.isRight(), isTrue);
    expect(repository.sentPlanIds, ['plan-a']);
    expect(controller.state.entries.single.planId, 'plan-a');
  });

  test(
    'a reply cannot reference an entry outside the loaded squad timeline',
    () async {
      final repository = _MemoryConversationRepository();
      final controller = ConversationController(
        repository: repository,
        outbox: MemoryConversationOutbox(),
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      addTearDown(() {
        controller.dispose();
        repository.dispose();
      });

      await controller.initialize();
      final result = await controller.sendText(
        '回复',
        replyToEntryId: 'some-other-squad-card',
      );

      expect(result.isLeft(), isTrue);
      expect(controller.state.entries, isEmpty);
    },
  );

  test('route flag cannot be published without an encrypted bundle', () async {
    final repository = _MemoryConversationRepository();
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(() {
      controller.dispose();
      repository.dispose();
    });

    final result = await controller.publishCard(
      cardId: 'card-a',
      snapshot: CardSnapshot(
        kind: CardKind.activity,
        payload: const {'title': '跑步'},
        hasEncryptedRoute: true,
      ),
    );
    expect(result.isLeft(), isTrue);
    expect(repository.publishCalls, 0);
  });

  test('resume drains more than one page without skipping messages', () async {
    final repository = _PagedConversationRepository();
    repository.addEntry(0);
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(() {
      controller.dispose();
      repository.dispose();
    });
    await controller.initialize();
    for (var index = 1; index <= 120; index++) {
      repository.addEntry(index);
    }

    await controller.refresh();

    expect(controller.state.entries, hasLength(121));
    expect(
      controller.state.entries.map((entry) => entry.text),
      List.generate(121, (index) => 'message-$index'),
    );
    expect(repository.afterCalls, 3);
  });

  test(
    'refresh uses the message id to break equal timestamp cursor ties',
    () async {
      final repository = _PagedConversationRepository();
      final timestamp = DateTime.utc(2026, 10, 8, 12);
      repository.addEntry(0, createdAt: timestamp);
      final controller = ConversationController(
        repository: repository,
        outbox: MemoryConversationOutbox(),
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      addTearDown(() {
        controller.dispose();
        repository.dispose();
      });
      await controller.initialize();

      repository.addEntry(1, createdAt: timestamp);
      await controller.refresh();

      expect(repository.afterCalls, 1);
      expect(controller.state.entries.map((entry) => entry.text), [
        'message-0',
        'message-1',
      ]);
    },
  );

  test(
    'refresh consumes timeline hints received during pending retry',
    () async {
      final repository = _GatedRetryConversationRepository();
      repository.addEntry(0);
      final outbox = MemoryConversationOutbox();
      final controller = ConversationController(
        repository: repository,
        outbox: outbox,
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      addTearDown(() {
        controller.dispose();
        repository.dispose();
      });
      await controller.initialize();
      await outbox.put(
        PendingConversationOperation.text(
          userId: 'alice',
          squadId: 'squad-a',
          clientNonce: 'pending-nonce',
          createdAt: DateTime.utc(2026, 10, 8, 12),
          body: 'queued',
        ),
      );

      final refresh = controller.refresh();
      await repository.sendStarted.future;
      repository.addEntry(1);
      repository.notifyChange();
      await Future<void>.delayed(Duration.zero);
      repository.sendGate.complete();
      await refresh;

      expect(repository.afterCalls, greaterThanOrEqualTo(2));
      expect(
        controller.state.entries.map((entry) => entry.text),
        containsAll(['message-0', 'message-1', 'queued']),
      );
    },
  );

  test('retry after a lost acknowledgement reuses the text nonce', () async {
    final repository = _LostAcknowledgementRepository();
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(() {
      controller.dispose();
      repository.dispose();
    });
    await controller.initialize();

    final first = await controller.sendText('今晚一起跑');
    expect(first.isLeft(), isTrue);
    final retry = await controller.sendText('今晚一起跑');
    expect(retry.isRight(), isTrue);
    expect(repository.sentNonces[0], repository.sentNonces[1]);
    expect(controller.state.entries, hasLength(1));

    await controller.sendText('今晚一起跑');
    expect(repository.sentNonces[2], isNot(repository.sentNonces[1]));
    expect(controller.state.entries, hasLength(2));
  });

  test(
    'reopen retries the durable text attempt with its original nonce',
    () async {
      final repository = _LostAcknowledgementRepository();
      final outbox = MemoryConversationOutbox();
      final firstController = ConversationController(
        repository: repository,
        outbox: outbox,
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      await firstController.initialize();
      final first = await firstController.sendText('恢复后仍只出现一条');
      expect(first.isLeft(), isTrue);
      expect(firstController.state.pendingCount, 1);
      firstController.dispose();

      final reopened = ConversationController(
        repository: repository,
        outbox: outbox,
        squadId: 'squad-a',
        currentUserId: 'alice',
      );
      addTearDown(() {
        reopened.dispose();
        repository.dispose();
      });
      await reopened.initialize();

      expect(repository.sentNonces, hasLength(2));
      expect(repository.sentNonces[0], repository.sentNonces[1]);
      expect(reopened.state.pendingCount, 0);
      expect(
        reopened.state.entries.where((entry) => entry.text == '恢复后仍只出现一条'),
        hasLength(1),
      );
    },
  );

  test('restoring network retries an unsent message', () async {
    final repository = _LostAcknowledgementRepository();
    final outbox = MemoryConversationOutbox();
    final connectivity = StreamController<bool>.broadcast();
    final controller = ConversationController(
      repository: repository,
      outbox: outbox,
      squadId: 'squad-a',
      currentUserId: 'alice',
      onlineEvents: connectivity.stream,
    );
    addTearDown(() async {
      await connectivity.close();
      controller.dispose();
      repository.dispose();
    });
    await controller.initialize();

    final failed = await controller.sendText('等联网后自动重试');
    expect(failed.isLeft(), isTrue);
    expect(controller.state.pendingCount, 1);

    connectivity.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repository.sentNonces, hasLength(2));
    expect(repository.sentNonces[0], repository.sentNonces[1]);
    expect(controller.state.pendingCount, 0);
    expect(controller.state.entries, hasLength(1));
  });

  test(
    'restoring network immediately catches up missed timeline entries',
    () async {
      final repository = _PagedConversationRepository();
      repository.addEntry(0);
      final connectivity = StreamController<bool>.broadcast();
      final controller = ConversationController(
        repository: repository,
        outbox: MemoryConversationOutbox(),
        squadId: 'squad-a',
        currentUserId: 'alice',
        onlineEvents: connectivity.stream,
      );
      addTearDown(() async {
        await connectivity.close();
        controller.dispose();
        repository.dispose();
      });
      await controller.initialize();

      repository.addEntry(1);
      connectivity.add(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(repository.afterCalls, 1);
      expect(controller.state.entries.map((entry) => entry.text), [
        'message-0',
        'message-1',
      ]);
    },
  );

  test('late initial page does not overwrite a realtime refresh', () async {
    final repository = _RacingConversationRepository();
    repository.addEntry(0);
    final older = repository._entries.single;
    final controller = ConversationController(
      repository: repository,
      outbox: MemoryConversationOutbox(),
      squadId: 'squad-a',
      currentUserId: 'alice',
    );
    addTearDown(() {
      controller.dispose();
      repository.dispose();
    });
    final initialLoad = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    repository.addEntry(1);
    repository.notifyChange();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    repository.completeInitial([older]);
    await initialLoad;

    expect(controller.state.entries.map((entry) => entry.text), [
      'message-0',
      'message-1',
    ]);
  });
}

final class _BlockingOutbox implements ConversationOutbox {
  _BlockingOutbox(this.phase);

  final String phase;
  final storage = MemoryConversationOutbox();
  final entered = Completer<void>();
  final release = Completer<void>();

  Future<void> _wait(String operation) async {
    if (operation != phase) return;
    entered.complete();
    await release.future;
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
    String? planId,
  }) async {
    await _wait('list');
    return storage.listFor(userId: userId, squadId: squadId, planId: planId);
  }

  @override
  Future<void> put(PendingConversationOperation operation) async {
    await storage.put(operation);
    await _wait('put');
  }

  @override
  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
    String? planId,
  }) async {
    await _wait('remove');
    await storage.remove(
      userId: userId,
      squadId: squadId,
      clientNonce: clientNonce,
      planId: planId,
    );
  }
}

class _MemoryConversationRepository implements ConversationRepository {
  final _changed = StreamController<void>.broadcast();
  final List<TimelineEntry> _entries = [];
  int publishCalls = 0;
  final sentPlanIds = <String?>[];

  void notifyChange() => _changed.add(null);
  void dispose() => _changed.close();

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => right(List.unmodifiable(_entries));

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right(
    _entries
        .where((entry) => entry.createdAt.isAfter(cursor.createdAt))
        .toList(),
  );

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right(const []);

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async {
    sentPlanIds.add(planId);
    final entry = TimelineEntry(
      id: 'server-1',
      squadId: squadId,
      planId: planId,
      authorId: 'alice',
      authorName: '阿晴',
      kind: TimelineEntryKind.text,
      text: body,
      replyToEntryId: replyToEntryId,
      clientNonce: clientNonce,
      createdAt: DateTime.utc(2026, 10, 8, 12),
    );
    _entries.add(entry);
    return right(entry);
  }

  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async {
    publishCalls++;
    return left(const Failure.server(message: 'Not used'));
  }

  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right(const {});

  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      _changed.stream;
}

class _PagedConversationRepository extends _MemoryConversationRepository {
  int afterCalls = 0;

  void addEntry(int index, {DateTime? createdAt}) {
    _entries.add(
      TimelineEntry(
        id: 'message-$index',
        squadId: 'squad-a',
        authorId: 'alice',
        authorName: '阿晴',
        kind: TimelineEntryKind.text,
        text: 'message-$index',
        clientNonce: 'nonce-$index',
        createdAt:
            createdAt ??
            DateTime.utc(2026, 10, 8, 12).add(Duration(seconds: index)),
      ),
    );
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => right(List.unmodifiable(_entries));

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async {
    afterCalls++;
    return right(
      _entries
          .where(
            (entry) =>
                entry.createdAt.isAfter(cursor.createdAt) ||
                (entry.createdAt.isAtSameMomentAs(cursor.createdAt) &&
                    entry.id.compareTo(cursor.id) > 0),
          )
          .take(50)
          .toList(),
    );
  }
}

final class _GatedRetryConversationRepository
    extends _PagedConversationRepository {
  final sendStarted = Completer<void>();
  final sendGate = Completer<void>();

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async {
    sendStarted.complete();
    await sendGate.future;
    return right(
      TimelineEntry(
        id: 'sent-queued',
        squadId: squadId,
        authorId: 'alice',
        authorName: '阿晴',
        kind: TimelineEntryKind.text,
        text: body,
        replyToEntryId: replyToEntryId,
        clientNonce: clientNonce,
        createdAt: DateTime.utc(
          2026,
          10,
          8,
          12,
        ).add(const Duration(milliseconds: 500)),
      ),
    );
  }
}

final class _LostAcknowledgementRepository
    extends _MemoryConversationRepository {
  final sentNonces = <String>[];
  final _byNonce = <String, TimelineEntry>{};

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async {
    sentNonces.add(clientNonce);
    final entry = _byNonce.putIfAbsent(clientNonce, () {
      final created = TimelineEntry(
        id: 'message-${_byNonce.length}',
        squadId: squadId,
        authorId: 'alice',
        authorName: '阿晴',
        kind: TimelineEntryKind.text,
        text: body,
        replyToEntryId: replyToEntryId,
        clientNonce: clientNonce,
        createdAt: DateTime.utc(
          2026,
          10,
          8,
          12,
        ).add(Duration(seconds: _byNonce.length)),
      );
      _entries.add(created);
      return created;
    });
    if (sentNonces.length == 1) {
      return left(const Failure.network(message: 'Acknowledgement lost'));
    }
    return right(entry);
  }
}

final class _RacingConversationRepository extends _PagedConversationRepository {
  final _firstPage = Completer<Either<Failure, List<TimelineEntry>>>();
  var _recentCalls = 0;

  void completeInitial(List<TimelineEntry> entries) {
    _firstPage.complete(right(entries));
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) {
    _recentCalls++;
    if (_recentCalls == 1) return _firstPage.future;
    return super.loadRecent(squadId);
  }
}
