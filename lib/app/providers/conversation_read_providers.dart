import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/error/failures.dart';
import '../../core/network/cloudbase_client_provider.dart';
import '../../features/conversation/data/cloudbase_conversation_read_repository.dart';
import '../../features/conversation/domain/conversation_read_repository.dart';
import '../../features/conversation/domain/conversation_target.dart';
import '../../features/conversation/domain/message_read_receipt.dart';
import '../../features/conversation/presentation/conversation_read_controller.dart';
import 'account_postgres_provider.dart';
import 'current_user_provider.dart';

final conversationReadRepositoryProvider =
    Provider<ConversationReadRepository?>((ref) {
      // Enable only in an explicitly opted-in staging build until real JWT/RLS
      // acceptance has passed. Missing receipts must never look like unread.
      if (!const bool.fromEnvironment('ENABLE_CONVERSATION_READ_RECEIPTS') ||
          ref.watch(cloudBaseConfigProvider).useDemo) {
        return null;
      }
      return CloudBaseConversationReadRepository(
        ref.watch(accountPostgresClientProvider).rest,
      );
    });

final conversationReadControllerProvider = StateNotifierProvider.autoDispose
    .family<ConversationReadController, ReadCursorState, ConversationTarget>((
      ref,
      target,
    ) {
      final userId = ref.watch(
        currentUserProvider.select((value) => value.value?.id ?? ''),
      );
      return ConversationReadController(
        repository: ref.watch(conversationReadRepositoryProvider),
        target: target,
        currentUserId: userId,
      );
    });

typedef ReadReceiptRequest = ({
  ConversationTarget target,
  String messageId,
  String authorId,
});

final messageReadReceiptProvider = FutureProvider.autoDispose
    .family<MessageReadReceipt, ReadReceiptRequest>((ref, request) async {
      final userId = ref.watch(
        currentUserProvider.select((value) => value.value?.id),
      );
      final repository = ref.watch(conversationReadRepositoryProvider);
      if (userId == null || userId != request.authorId) {
        throw const Failure.permissionDenied(message: '仅消息作者可以查看已读明细');
      }
      if (repository == null) throw const Failure.server(message: '已读状态暂不可用');
      final result = await repository.loadForMessages(
        target: request.target,
        messageIds: [request.messageId],
      );
      return result.match(
        (failure) => throw failure,
        (receipts) => receipts.single,
      );
    });
