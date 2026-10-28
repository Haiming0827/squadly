import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/current_user_provider.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../domain/conversation_target.dart';
import '../domain/message_read_receipt.dart';
import 'conversation_read_provider.dart';

final class MessageReadReceiptButton extends ConsumerWidget {
  const MessageReadReceiptButton({
    super.key,
    required this.target,
    required this.messageId,
    required this.authorId,
  });
  final ConversationTarget target;
  final String messageId;
  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider).value?.id;
    final repository = ref.watch(conversationReadRepositoryProvider);
    if (userId != authorId || repository == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ReceiptDetails(
          request: (target: target, messageId: messageId, authorId: authorId),
        ),
      ),
      icon: const Icon(Icons.done_all_rounded, size: 16),
      label: const Text('已读明细'),
    );
  }
}

final class _ReceiptDetails extends ConsumerStatefulWidget {
  const _ReceiptDetails({required this.request});
  final ReadReceiptRequest request;
  @override
  ConsumerState<_ReceiptDetails> createState() => _ReceiptDetailsState();
}

final class _ReceiptDetailsState extends ConsumerState<_ReceiptDetails> {
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        ref.invalidate(messageReadReceiptProvider(widget.request));
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receipt = ref.watch(messageReadReceiptProvider(widget.request));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '已读明细',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新已读',
                    onPressed: () => ref.invalidate(
                      messageReadReceiptProvider(widget.request),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: '关闭已读明细',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: receipt.when(
                skipLoadingOnRefresh: false,
                skipLoadingOnReload: false,
                loading: () =>
                    const Center(child: AppLoadingState(label: '正在加载已读状态')),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('已读状态暂不可用'),
                      TextButton(
                        onPressed: () => ref.invalidate(
                          messageReadReceiptProvider(widget.request),
                        ),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                data: (value) => value.members.isEmpty
                    ? const Center(child: Text('没有其他可查看此消息的成员'))
                    : ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Text(
                              value.participantCount == 0
                                  ? '暂无计入统计的成员'
                                  : '${value.readCount}/${value.participantCount} 人已读',
                            ),
                          ),
                          for (final member in value.members)
                            ListTile(
                              title: Text(member.nickname),
                              subtitle: Text(switch (member.status) {
                                ConversationReadStatus.read => '已读',
                                ConversationReadStatus.unread => '未读',
                                ConversationReadStatus.notApplicable =>
                                  '加入前消息 · 不计入统计',
                              }),
                              leading: Icon(switch (member.status) {
                                ConversationReadStatus.read =>
                                  Icons.done_all_rounded,
                                ConversationReadStatus.unread =>
                                  Icons.radio_button_unchecked_rounded,
                                ConversationReadStatus.notApplicable =>
                                  Icons.person_add_alt_rounded,
                              }),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
