import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/memory_conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_controller.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
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

class _MemoryConversationRepository implements ConversationRepository {
  final _changed = StreamController<void>.broadcast();
  final List<TimelineEntry> _entries = [];
  int publishCalls = 0;

  void notifyChange() => _changed.add(null);
  void dispose() => _changed.close();

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId,
  ) async => right(List.unmodifiable(_entries));

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  ) async => right(
    _entries
        .where((entry) => entry.createdAt.isAfter(cursor.createdAt))
        .toList(),
  );

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor,
  ) async => right(const []);

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
  }) async {
    final entry = TimelineEntry(
      id: 'server-1',
      squadId: squadId,
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
  Stream<void> watchTimeline(String squadId) => _changed.stream;
}

class _PagedConversationRepository extends _MemoryConversationRepository {
  int afterCalls = 0;

  void addEntry(int index) {
    _entries.add(
      TimelineEntry(
        id: 'message-$index',
        squadId: 'squad-a',
        authorId: 'alice',
        authorName: '阿晴',
        kind: TimelineEntryKind.text,
        text: 'message-$index',
        clientNonce: 'nonce-$index',
        createdAt: DateTime.utc(2026, 10, 8, 12).add(Duration(seconds: index)),
      ),
    );
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId,
  ) async => right(List.unmodifiable(_entries));

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  ) async {
    afterCalls++;
    return right(
      _entries
          .where((entry) => entry.createdAt.isAfter(cursor.createdAt))
          .take(50)
          .toList(),
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
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(String squadId) {
    _recentCalls++;
    if (_recentCalls == 1) return _firstPage.future;
    return super.loadRecent(squadId);
  }
}
