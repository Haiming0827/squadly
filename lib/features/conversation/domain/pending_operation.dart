import 'package:freezed_annotation/freezed_annotation.dart';

import '../../cards/domain/card_composer.dart';
import '../../photos/domain/photo.dart';
import '../../secure_route/domain/route_models.dart';

part 'pending_operation.freezed.dart';

/// A user-confirmed send attempt. The same nonce is used until server ack.
@freezed
sealed class PendingConversationOperation with _$PendingConversationOperation {
  const PendingConversationOperation._();

  String? get planId => switch (this) {
    PendingTextOperation(:final planId) => planId,
    PendingCardOperation(:final planId) => planId,
    PendingPhotoOperation() => null,
  };

  const factory PendingConversationOperation.photo({
    required String userId,
    required String squadId,
    required String squadName,
    required String clientNonce,
    required DateTime createdAt,
    required PhotoImage image,
    String? replyToEntryId,
  }) = PendingPhotoOperation;
  const factory PendingConversationOperation.text({
    required String userId,
    required String squadId,
    required String clientNonce,
    required DateTime createdAt,
    required String body,
    String? planId,
    String? replyToEntryId,
  }) = PendingTextOperation;

  const factory PendingConversationOperation.card({
    required String userId,
    required String squadId,
    required String clientNonce,
    required DateTime createdAt,
    required String cardId,
    required CardSnapshot snapshot,
    String? planId,
    EncryptedRouteBundle? encryptedRoute,
  }) = PendingCardOperation;
}

extension PendingPhotoDraft on PendingPhotoOperation {
  PhotoDraft get draft => PhotoDraft(
    target: PhotoTarget(
      userId: userId,
      squadId: squadId,
      squadName: squadName,
      replyToMessageId: replyToEntryId,
    ),
    image: image,
    clientNonce: clientNonce,
    preparedAt: createdAt,
  );
}
