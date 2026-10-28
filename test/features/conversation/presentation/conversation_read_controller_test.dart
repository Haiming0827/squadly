import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/domain/conversation_read_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_target.dart';
import 'package:squadly/features/conversation/domain/message_read_receipt.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_read_controller.dart';

const _target = ConversationTarget(squadId: 'squad', planId: 'plan');
TimelineEntry _entry(
  String id, {
  String squad = 'squad',
  String? plan = 'plan',
  int minute = 0,
}) => TimelineEntry(
  id: id,
  squadId: squad,
  planId: plan,
  authorId: 'other',
  authorName: '成员',
  kind: TimelineEntryKind.text,
  clientNonce: id,
  text: 'Synthetic test',
  createdAt: DateTime.utc(2026, 10, 22, 10, minute),
);

final class _ReadRepository implements ConversationReadRepository {
  final ids = <String>[];
  Either<Failure, Unit> result = right(unit);
  Completer<Either<Failure, Unit>>? gate;
  bool throws = false;
  @override
  Future<Either<Failure, Unit>> advance({
    required ConversationTarget target,
    required String messageId,
  }) async {
    ids.add(messageId);
    if (throws) throw StateError('synthetic private error');
    return gate == null ? result : await gate!.future;
  }

  @override
  Future<Either<Failure, List<MessageReadReceipt>>> loadForMessages({
    required ConversationTarget target,
    required List<String> messageIds,
  }) async => right([]);
}

void main() {
  ConversationReadController create(
    _ReadRepository? repo, {
    String user = 'user',
    DateTime Function()? clock,
  }) {
    final controller = ConversationReadController(
      repository: repo,
      target: _target,
      currentUserId: user,
      clock: clock,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'only an active visible message in the exact thread can advance',
    () async {
      final repo = _ReadRepository();
      final controller = create(repo);
      await controller.acknowledgeVisible(_entry('1'), active: false);
      await controller.acknowledgeVisible(
        _entry('1', squad: 'other'),
        active: true,
      );
      await controller.acknowledgeVisible(
        _entry('1', plan: null),
        active: true,
      );
      await controller.acknowledgeVisible(
        _entry('1', plan: 'other'),
        active: true,
      );
      expect(repo.ids, isEmpty);
      await controller.acknowledgeVisible(_entry('1'), active: true);
      expect(repo.ids, ['1']);
    },
  );
  test('missing account or disabled repository does not submit', () async {
    final repo = _ReadRepository();
    await create(repo, user: '').acknowledgeVisible(_entry('1'), active: true);
    await create(null).acknowledgeVisible(_entry('1'), active: true);
    expect(repo.ids, isEmpty);
  });
  test(
    'same timestamp uses the stable ID and late calls cannot regress',
    () async {
      final repo = _ReadRepository();
      final controller = create(repo);
      await controller.acknowledgeVisible(_entry('2'), active: true);
      await controller.acknowledgeVisible(_entry('1'), active: true);
      await controller.acknowledgeVisible(_entry('2'), active: true);
      await controller.acknowledgeVisible(_entry('3'), active: true);
      await controller.acknowledgeVisible(_entry('0', minute: 1), active: true);
      expect(repo.ids, ['2', '3', '0']);
      expect(controller.state.acknowledged?.id, '0');
    },
  );
  test('network failure does not falsely acknowledge and is retried after cooldown', () async {
    var now = DateTime.utc(2026, 10, 22);
    final repo = _ReadRepository()..result = left(const Failure.network());
    final controller = create(repo, clock: () => now);
    await controller.acknowledgeVisible(_entry('1'), active: true);
    expect(controller.state.acknowledged, isNull);
    await controller.acknowledgeVisible(_entry('1'), active: true);
    expect(repo.ids.length, 1);
    now = now.add(const Duration(seconds: 5));
    repo.result = right(unit);
    await controller.acknowledgeVisible(_entry('1'), active: true);
    expect(repo.ids.length, 2);
    expect(controller.state.error, isNull);
    expect(controller.state.acknowledged?.id, '1');
  });
  test(
    'does not queue a later write behind an in-flight visible message',
    () async {
      final repo = _ReadRepository()..gate = Completer();
      final controller = create(repo);
      final pending = controller.acknowledgeVisible(_entry('1'), active: true);
      await controller.acknowledgeVisible(_entry('2'), active: true);
      repo.gate!.complete(right(unit));
      await pending;
      expect(repo.ids, ['1']);
      await controller.acknowledgeVisible(_entry('2'), active: false);
      expect(repo.ids, ['1']);
      await controller.acknowledgeVisible(_entry('2'), active: true);
      expect(repo.ids, ['1', '2']);
    },
  );
  test('disposing during transport discards its result and blocks subsequent writes', () async {
    final repo = _ReadRepository()..gate = Completer();
    final controller = ConversationReadController(
      repository: repo,
      target: _target,
      currentUserId: 'user',
    );
    final pending = controller.acknowledgeVisible(_entry('1'), active: true);
    controller.dispose();
    repo.gate!.complete(right(unit));
    await pending;
    await controller.acknowledgeVisible(_entry('2'), active: true);
    expect(repo.ids, ['1']);
  });
  test('unexpected failures use a safe message and preserve the acknowledged cursor', () async {
    final repo = _ReadRepository();
    final controller = create(repo);
    await controller.acknowledgeVisible(_entry('1'), active: true);
    repo.throws = true;
    await controller.acknowledgeVisible(_entry('2'), active: true);
    expect(controller.state.acknowledged?.id, '1');
    expect(controller.state.error, const Failure.network(message: '无法同步已读状态'));
  });
}
