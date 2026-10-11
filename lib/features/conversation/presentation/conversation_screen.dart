import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/domain/card_composer.dart';
import '../../cards/presentation/card_detail_sheet.dart';
import '../domain/timeline_entry.dart';
import 'conversation_provider.dart';

/// The real squad conversation. Demo mode continues to use CircleScreen until
/// the home shell selects this screen for remote mode.
final class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.onCreateCard,
  });

  final String squadId;
  final String squadName;
  final VoidCallback onCreateCard;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

final class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  String? _replyToId;
  String? _replyTitle;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref
          .read(conversationControllerProvider(widget.squadId).notifier)
          .refresh();
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final result = await ref
        .read(conversationControllerProvider(widget.squadId).notifier)
        .sendText(body, replyToEntryId: _replyToId);
    if (!mounted) return;
    setState(() => _sending = false);
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发送失败，请检查网络或小队权限'))),
      (_) {
        _text.clear();
        setState(() {
          _replyToId = null;
          _replyTitle = null;
        });
      },
    );
  }

  void _replyTo(TimelineEntry entry) {
    setState(() {
      _replyToId = entry.id;
      _replyTitle = entry.kind == TimelineEntryKind.card
          ? (entry.cardSnapshot?.payload['title'] as String? ?? '这张卡片')
          : (entry.text ?? '这条消息');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider(widget.squadId));
    final entries = state.entries;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.squadName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '刷新消息',
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.squadId).notifier,
                    )
                    .refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        if (state.pendingCount > 0)
          MaterialBanner(
            content: Text('有 ${state.pendingCount} 条待发送；联网后会继续重试'),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.squadId).notifier,
                    )
                    .retryPending(),
                child: const Text('立即重试'),
              ),
            ],
          )
        else if (state.error != null)
          MaterialBanner(
            content: const Text('消息同步失败，可重试'),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.squadId).notifier,
                    )
                    .refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(
          child: state.isLoading && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : entries.isEmpty
              ? const Center(child: Text('还没有消息，来打个招呼吧'))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => ref
                              .read(
                                conversationControllerProvider(
                                  widget.squadId,
                                ).notifier,
                              )
                              .loadEarlier(),
                          child: const Text('加载更早的消息'),
                        ),
                      );
                    }
                    final entry = entries[entries.length - index - 1];
                    final repliedTo = entry.replyToEntryId == null
                        ? null
                        : entries
                              .where((item) => item.id == entry.replyToEntryId)
                              .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TimelineTile(
                        entry: entry,
                        repliedTo: repliedTo,
                        squadName: widget.squadName,
                        onReply: () => _replyTo(entry),
                        onOpenCard: entry.kind == TimelineEntryKind.card
                            ? () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => CardDetailSheet(
                                  squadId: widget.squadId,
                                  squadName: widget.squadName,
                                  entry: entry,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
        if (_replyToId != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            color: colors.surfaceContainerLow,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '回复：${_replyTitle ?? '这条消息'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '取消回复',
                  onPressed: () => setState(() {
                    _replyToId = null;
                    _replyTitle = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '生成卡片',
                  onPressed: widget.onCreateCard,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: '发给小队…',
                      counterText: '',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '发送消息',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.repliedTo,
    required this.squadName,
    required this.onReply,
    required this.onOpenCard,
  });

  final TimelineEntry entry;
  final TimelineEntry? repliedTo;
  final String squadName;
  final VoidCallback onReply;
  final VoidCallback? onOpenCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final card = entry.cardSnapshot;
    final reply = repliedTo;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.authorName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (reply != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '回复 ${reply.kind == TimelineEntryKind.card ? '卡片' : '消息'}：${reply.cardSnapshot?.payload['title'] ?? reply.text ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (entry.kind == TimelineEntryKind.text)
                  Text(entry.text ?? '')
                else
                  InkWell(
                    onTap: onOpenCard,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card?.kind == CardKind.activity ? '运动记录卡' : '群聊内容卡',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card?.payload['title'] as String? ?? '小队里的这一刻',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '点开查看与保存图片',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onReply,
                    child: Text(
                      entry.kind == TimelineEntryKind.card ? '回复卡片' : '回复',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
