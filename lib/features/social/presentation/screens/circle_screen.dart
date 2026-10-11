import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../squad/domain/entities/squad_member.dart';
import '../../domain/entities/circle_message.dart';
import '../../domain/entities/social_post.dart';

enum _CircleTab { feed, chat }

/// The shared space for one small circle. The parent owns app navigation and
/// opens the data-post composer through [onCreatePost].
class CircleScreen extends ConsumerStatefulWidget {
  const CircleScreen({super.key, required this.onCreatePost});

  final VoidCallback onCreatePost;

  @override
  ConsumerState<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends ConsumerState<CircleScreen> {
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  _CircleTab _tab = _CircleTab.feed;

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String squadId) {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      ref
          .read(demoAppStoreProvider.notifier)
          .sendCircleMessage(squadId: squadId, text: message);
      _messageController.clear();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chatScrollController.hasClients) return;
        _chatScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoAppStoreProvider);
    final squad = state.currentSquad;
    final colors = Theme.of(context).colorScheme;

    if (squad == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_2_outlined, size: 44, color: colors.secondary),
              const SizedBox(height: 16),
              Text('先找到你的小队', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '加入小队后，大家的消息和分享会出现在这里。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final members = state.membersFor(squad.id);
    final posts = state.postsFor(squad.id);
    final messages = state.messagesFor(squad.id);
    final currentUserId = state.currentUser?.id;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          children: [
            _CircleHeader(
              squadName: squad.name,
              description: squad.description,
              members: members,
              currentUserId: currentUserId,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _CircleTabSwitch(
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: _tab == _CircleTab.feed
                  ? _FeedView(
                      posts: posts,
                      currentUserId: currentUserId,
                      onCreatePost: widget.onCreatePost,
                      onReact: (postId) {
                        ref
                            .read(demoAppStoreProvider.notifier)
                            .togglePostReaction(postId);
                      },
                    )
                  : _ChatView(
                      messages: messages,
                      currentUserId: currentUserId,
                      scrollController: _chatScrollController,
                    ),
            ),
            if (_tab == _CircleTab.chat)
              _MessageComposer(
                controller: _messageController,
                enabled: currentUserId != null,
                onChanged: () => setState(() {}),
                onSend: () => _sendMessage(squad.id),
                onCreatePost: widget.onCreatePost,
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleHeader extends StatelessWidget {
  const _CircleHeader({
    required this.squadName,
    required this.description,
    required this.members,
    required this.currentUserId,
  });

  final String squadName;
  final String? description;
  final List<SquadMember> members;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '和大家在一起',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description?.trim().isNotEmpty == true
                ? '$squadName · ${description!.trim()}'
                : '$squadName · ${members.length} 位成员',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final member = members[index];
                final name = member.nickname ?? '成员';
                return Semantics(
                  label:
                      '$name${member.userId == currentUserId ? '，我' : ''}${member.role == 'captain' ? '，队长' : ''}',
                  child: Column(
                    children: [
                      _MemberAvatar(
                        id: member.userId,
                        name: name,
                        size: 42,
                        showCaptain: member.role == 'captain',
                      ),
                      const SizedBox(height: 3),
                      Text(
                        member.userId == currentUserId ? '我' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleTabSwitch extends StatelessWidget {
  const _CircleTabSwitch({required this.selected, required this.onSelected});

  final _CircleTab selected;
  final ValueChanged<_CircleTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tabButton(
            context,
            _CircleTab.feed,
            '动态',
            Icons.view_timeline_outlined,
          ),
          _tabButton(
            context,
            _CircleTab.chat,
            '聊天',
            Icons.chat_bubble_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    BuildContext context,
    _CircleTab tab,
    String label,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = selected == tab;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => onSelected(tab),
            child: SizedBox(
              height: 43,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView({
    required this.posts,
    required this.currentUserId,
    required this.onCreatePost,
    required this.onReact,
  });

  final List<SocialPost> posts;
  final String? currentUserId;
  final VoidCallback onCreatePost;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      key: const PageStorageKey('circle-feed'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onCreatePost,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('分享一件新鲜事', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          '把你的数据整理成好看的卡片',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text('大家的新鲜事', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          const _EmptyPanel(
            icon: Icons.auto_stories_outlined,
            title: '这里还没有动态',
            subtitle: '第一张分享卡片，等你来发布。',
          )
        else
          for (final post in posts) ...[
            _PostCard(
              post: post,
              isReacted: post.reactionUserIds.contains(currentUserId),
              onReact: () => onReact(post.id),
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isReacted,
    required this.onReact,
  });

  final SocialPost post;
  final bool isReacted;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = context.squadlyPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MemberAvatar(
                  id: post.authorId,
                  name: post.authorName,
                  size: 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: theme.textTheme.titleSmall),
                      Text(
                        _timeAgo(post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.visibility == 'selected')
                  Tooltip(
                    message: '仅指定成员可见',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: palette.privacy,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '指定成员',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.privacy,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    '小队可见',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(post.title, style: theme.textTheme.titleLarge),
            if (post.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post.body, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          post.metricValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          post.metricUnit,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (post.trend.length > 1) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TrendPainter(
                          values: post.trend,
                          color: palette.info,
                          guideColor: colors.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${post.sourceLabel} · ${_dateRange(post.rangeStart, post.rangeEnd)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onReact,
                  style: TextButton.styleFrom(
                    foregroundColor: isReacted
                        ? palette.accent
                        : colors.onSurfaceVariant,
                    minimumSize: const Size(48, 44),
                  ),
                  icon: Icon(
                    isReacted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  label: Text('喜欢 ${post.reactionUserIds.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView({
    required this.messages,
    required this.currentUserId,
    required this.scrollController,
  });

  final List<CircleMessage> messages;
  final String? currentUserId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: _EmptyPanel(
          icon: Icons.waving_hand_outlined,
          title: '来打个招呼吧',
          subtitle: '从一句话开始，让小队热闹起来。',
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('circle-chat'),
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _MessageBubble(
            message: message,
            isMe: message.authorId == currentUserId,
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final CircleMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) ...[
          _MemberAvatar(
            id: message.authorId,
            name: message.authorName,
            size: 34,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    '${isMe ? '我' : message.authorName} · ${_timeAgo(message.createdAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? colors.surfaceContainerHigh
                        : colors.surfaceContainerLow,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(message.text, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onCreatePost,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: '分享数据卡片',
              onPressed: onCreatePost,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '和大家说点什么…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送消息',
              onPressed: enabled && controller.text.trim().isNotEmpty
                  ? onSend
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.id,
    required this.name,
    required this.size,
    this.showCaptain = false,
  });

  final String id;
  final String name;
  final double size;
  final bool showCaptain;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const hues = [205.0, 264.0, 160.0, 344.0, 45.0];
    final hue =
        hues[id.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            hues.length];
    final background = HSLColor.fromAHSL(
      1,
      hue,
      0.34,
      dark ? 0.27 : 0.89,
    ).toColor();
    final foreground = HSLColor.fromAHSL(
      1,
      hue,
      0.45,
      dark ? 0.84 : 0.30,
    ).toColor();
    final label = name.characters.take(2).toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: background,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: foreground,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showCaptain)
          Positioned(
            right: -2,
            bottom: -1,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                size: 13,
                color: context.squadlyPalette.accent,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.color,
    required this.guideColor,
  });

  final List<double> values;
  final Color color;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final span = highest - lowest;
    final baseline = size.height - 3;

    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = guideColor
        ..strokeWidth = 1,
    );

    final line = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = span == 0
          ? size.height / 2
          : 5 + (1 - (values[index] - lowest) / span) * (size.height - 11);
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final lastY = span == 0
        ? size.height / 2
        : 5 + (1 - (values.last - lowest) / span) * (size.height - 11);
    canvas.drawCircle(Offset(size.width, lastY), 3.3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      color != oldDelegate.color ||
      guideColor != oldDelegate.guideColor;
}

String _dateRange(DateTime start, DateTime end) {
  String shortDate(DateTime date) => '${date.month}月${date.day}日';
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return shortDate(start);
  }
  return '${shortDate(start)}—${shortDate(end)}';
}

String _timeAgo(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return '刚刚';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} 分钟前';
  if (elapsed.inHours < 24) return '${elapsed.inHours} 小时前';
  if (elapsed.inDays < 7) return '${elapsed.inDays} 天前';
  return '${time.month}月${time.day}日';
}
