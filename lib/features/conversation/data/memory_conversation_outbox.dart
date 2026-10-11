import '../domain/conversation_outbox.dart';
import '../domain/pending_operation.dart';

/// Demo and test adapter. Production uses an encrypted Drift adapter.
final class MemoryConversationOutbox implements ConversationOutbox {
  final _entries = <(String, String, String), PendingConversationOperation>{};

  @override
  Future<void> put(PendingConversationOperation operation) async {
    _entries[(operation.userId, operation.squadId, operation.clientNonce)] =
        operation;
  }

  @override
  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
  }) async {
    final matches =
        _entries.values
            .where(
              (entry) => entry.userId == userId && entry.squadId == squadId,
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
  }) async {
    _entries.remove((userId, squadId, clientNonce));
  }
}
