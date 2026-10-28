import 'pending_operation.dart';

/// Durable send attempts. Implementations must encrypt payloads before disk IO.
abstract interface class ConversationOutbox {
  Future<void> put(PendingConversationOperation operation);

  Future<List<PendingConversationOperation>> listFor({
    required String userId,
    required String squadId,
    String? planId,
  });

  Future<void> remove({
    required String userId,
    required String squadId,
    required String clientNonce,
    String? planId,
  });
}
