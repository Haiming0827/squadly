import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../conversation/presentation/conversation_list_controls.dart';
import '../../../social/domain/entities/circle_message.dart';
import '../../../squad/domain/entities/squad.dart';

final class DemoConversationListScreen extends ConsumerStatefulWidget {
  const DemoConversationListScreen({
    required this.onOpenConversation,
    required this.onOpenSquads,
    super.key,
  });

  final ValueChanged<Squad> onOpenConversation;
  final VoidCallback onOpenSquads;

  @override
  ConsumerState<DemoConversationListScreen> createState() =>
      _DemoConversationListScreenState();
}

final class _DemoConversationListScreenState
    extends ConsumerState<DemoConversationListScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _filter = ConversationActivityFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoAppStoreProvider);
    final colors = Theme.of(context).colorScheme;
    final conversations =
        [
          for (final squad in state.mySquads)
            _DemoConversation(
              squad: squad,
              latestMessage: state.messagesFor(squad.id).lastOrNull,
            ),
        ]..sort((a, b) {
          final aDate = a.latestMessage?.createdAt;
          final bDate = b.latestMessage?.createdAt;
          if (aDate == null) return bDate == null ? 0 : 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text('还没有会话', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '创建或加入小队后，就能和伙伴开始交流。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onOpenSquads,
                child: const Text('创建或加入小队'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = [
      for (final conversation in conversations)
        if (matchesConversationActivity(
              _filter,
              conversation.latestMessage != null,
            ) &&
            matchesConversationSearch(
              query: _query,
              squadName: conversation.squad.name,
              preview: _previewFor(conversation.latestMessage),
            ))
          conversation,
    ];

    return ListView(
      children: [
        ConversationListControls(
          controller: _searchController,
          query: _query,
          filter: _filter,
          onQueryChanged: (value) => setState(() => _query = value),
          onFilterChanged: (value) => setState(() => _filter = value),
        ),
        if (filtered.isEmpty)
          ConversationListNoResults(
            onReset: () {
              _searchController.clear();
              setState(() {
                _query = '';
                _filter = ConversationActivityFilter.all;
              });
            },
          )
        else
          for (var index = 0; index < filtered.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 72),
            _ConversationTile(
              key: ValueKey('demo-conversation-${filtered[index].squad.id}'),
              conversation: filtered[index],
              onTap: () => widget.onOpenConversation(filtered[index].squad),
            ),
          ],
      ],
    );
  }
}

final class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    super.key,
  });

  final _DemoConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final squad = conversation.squad;
    final latestMessage = conversation.latestMessage;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
        child: Text(squad.name.characters.first),
      ),
      title: Text(squad.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _previewFor(latestMessage),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (latestMessage != null)
            Text(
              _formatTime(latestMessage.createdAt),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: 4),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
  }
}

String _previewFor(CircleMessage? message) =>
    message == null ? '还没有消息，发起第一次交流' : '${message.authorName}：${message.text}';

final class _DemoConversation {
  const _DemoConversation({required this.squad, required this.latestMessage});

  final Squad squad;
  final CircleMessage? latestMessage;
}
