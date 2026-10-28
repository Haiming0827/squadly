import 'package:flutter_riverpod/legacy.dart';

import '../../../core/error/failures.dart';
import '../domain/conversation_read_repository.dart';
import '../domain/conversation_target.dart';
import '../domain/timeline_entry.dart';

final class ReadCursorState {
  const ReadCursorState({this.acknowledged, this.error});
  final TimelineCursor? acknowledged;
  final Failure? error;
}

/// No deferred writes: each attempt needs a fresh foreground/visibility check.
/// Account-bound composition disposes this controller when identity changes.
final class ConversationReadController extends StateNotifier<ReadCursorState> {
  ConversationReadController({
    required this.repository,
    required this.target,
    required this.currentUserId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const ReadCursorState());

  final ConversationReadRepository? repository;
  final ConversationTarget target;
  final String currentUserId;
  final DateTime Function() _clock;
  bool _closed = false;
  bool _inFlight = false;
  DateTime? _failedAt;

  Future<void> acknowledgeVisible(
    TimelineEntry latest, {
    required bool active,
  }) async {
    final repo = repository;
    if (_closed ||
        !active ||
        repo == null ||
        currentUserId.isEmpty ||
        _inFlight ||
        latest.squadId != target.squadId ||
        latest.planId != target.planId) {
      return;
    }
    final previous = state.acknowledged;
    if (previous != null && _compare(latest.cursor, previous) <= 0) return;
    final failedAt = _failedAt;
    if (failedAt != null &&
        _clock().difference(failedAt) < const Duration(seconds: 5)) {
      return;
    }
    _inFlight = true;
    try {
      final result = await repo.advance(target: target, messageId: latest.id);
      if (_closed) return;
      result.match(
        (failure) {
          _failedAt = _clock();
          state = ReadCursorState(
            acknowledged: state.acknowledged,
            error: failure,
          );
        },
        (_) {
          _failedAt = null;
          state = ReadCursorState(acknowledged: latest.cursor);
        },
      );
    } catch (_) {
      if (_closed) return;
      _failedAt = _clock();
      state = ReadCursorState(
        acknowledged: state.acknowledged,
        error: const Failure.network(message: '无法同步已读状态'),
      );
    } finally {
      _inFlight = false;
    }
  }

  static int _compare(TimelineCursor a, TimelineCursor b) {
    final date = a.createdAt.compareTo(b.createdAt);
    return date != 0 ? date : a.id.compareTo(b.id);
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
