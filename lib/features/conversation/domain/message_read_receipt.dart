import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_read_receipt.freezed.dart';

enum ConversationReadStatus { read, unread, notApplicable }

/// A safe per-message projection, never another member's raw thread cursor.
@freezed
abstract class MemberReadReceipt with _$MemberReadReceipt {
  const factory MemberReadReceipt({
    required String membershipId,
    required String userId,
    required String nickname,
    required ConversationReadStatus status,
  }) = _MemberReadReceipt;
}

@freezed
abstract class MessageReadReceipt with _$MessageReadReceipt {
  const MessageReadReceipt._();

  const factory MessageReadReceipt({
    required String messageId,
    required List<MemberReadReceipt> members,
  }) = _MessageReadReceipt;

  int get readCount => members
      .where((member) => member.status == ConversationReadStatus.read)
      .length;

  int get participantCount => members
      .where((member) => member.status != ConversationReadStatus.notApplicable)
      .length;
}
