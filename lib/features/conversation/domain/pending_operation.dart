import 'package:freezed_annotation/freezed_annotation.dart';

import '../../cards/domain/card_composer.dart';
import '../../secure_route/domain/route_models.dart';

part 'pending_operation.freezed.dart';

/// A user-confirmed send attempt. The same nonce is used until server ack.
@freezed
sealed class PendingConversationOperation with _$PendingConversationOperation {
  const factory PendingConversationOperation.text({
    required String userId,
    required String squadId,
    required String clientNonce,
    required DateTime createdAt,
    required String body,
    String? replyToEntryId,
  }) = PendingTextOperation;

  const factory PendingConversationOperation.card({
    required String userId,
    required String squadId,
    required String clientNonce,
    required DateTime createdAt,
    required String cardId,
    required CardSnapshot snapshot,
    EncryptedRouteBundle? encryptedRoute,
  }) = PendingCardOperation;
}
