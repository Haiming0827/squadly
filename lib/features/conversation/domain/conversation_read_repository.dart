import 'package:fpdart/fpdart.dart';

import '../../../core/error/failures.dart';
import 'conversation_target.dart';
import 'message_read_receipt.dart';

abstract interface class ConversationReadRepository {
  /// Server derives the position from an authorized message in this thread.
  /// Identity is the authenticated caller; no user ID or timestamp is accepted.
  Future<Either<Failure, Unit>> advance({
    required ConversationTarget target,
    required String messageId,
  });

  /// One batched projection for at most 50 messages, with no message content or
  /// original read positions. Authorization is rechecked on every server call.
  Future<Either<Failure, List<MessageReadReceipt>>> loadForMessages({
    required ConversationTarget target,
    required List<String> messageIds,
  });
}
