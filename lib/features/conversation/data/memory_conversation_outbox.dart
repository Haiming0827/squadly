import '../../photos/domain/photo_submission.dart';
import '../domain/conversation_outbox.dart';
import '../domain/pending_operation.dart';

/// Demo and test adapter. Production uses an encrypted Drift adapter.
final class MemoryConversationOutbox implements ConversationOutbox {
  final _entries =
      <(String, String, String, String), PendingConversationOperation>{};

  @override
  Future<void> put(PendingConversationOperation operation) async {
    final previous =
        _entries[(
          operation.userId,
          operation.squadId,
          operation.planId ?? '',
          operation.clientNonce,
        )];
    if (previous != null &&
        (previous is PendingPhotoOperation ||
            operation is PendingPhotoOperation) &&
        (previous is! PendingPhotoOperation ||
            operation is! PendingPhotoOperation ||
            !sameConfirmedPhoto(previous.draft, operation.draft))) {
      throw StateError('Conflicting confirmed photo identity');
    }
    _entries.putIfAbsent((
      operation.userId,
      operation.squadId,
      operation.planId ?? '',
      operation.clientNonce,
    ), () => operation);
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
    String? planId,
  }) async {
    final matches =
        _entries.values
            .where(
              (entry) =>
                  entry.userId == userId &&
                  entry.squadId == squadId &&
                  entry.planId == planId,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(matches);
  }

  @override
  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
    String? planId,
  }) async {
    _entries.remove((userId, squadId, planId ?? '', clientNonce));
  }
}
