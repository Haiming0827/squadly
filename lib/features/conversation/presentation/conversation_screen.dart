import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/current_user_provider.dart';
import '../../../app/providers/offline_access_provider.dart';
import '../../../app/providers/offline_conversation_provider.dart';
import '../../../core/error/failures.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_section.dart';
import '../../cards/domain/card_composer.dart';
import '../domain/conversation_target.dart';
import '../domain/timeline_entry.dart';
import 'conversation_provider.dart';
import 'conversation_read_provider.dart';
import 'message_read_receipt_button.dart';

/// The real squad conversation. Demo mode continues to use CircleScreen until
/// the home shell selects this screen for remote mode.
final class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.onCreateCard,
    this.planId,
    this.planTitle,
    this.onOpenCard,
    this.onCreatePhoto,
    this.photoBuilder,
  });

  final String squadId;
  final String squadName;
  final VoidCallback onCreateCard;
  final String? planId;
  final String? planTitle;
  final ValueChanged<TimelineEntry>? onOpenCard;
  final VoidCallback? onCreatePhoto;
  final Widget Function(
    BuildContext,
    TimelineEntry,
    bool canRead,
    ValueChanged<bool> onDisplayChanged,
  )?
  photoBuilder;

  ConversationTarget get target =>
      ConversationTarget(squadId: squadId, planId: planId);

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

final class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  String? _replyToId;
  String? _replyTitle;
  bool _sending = false;
  final _timelineScroll = ScrollController();
  final _timelineViewport = GlobalKey();
  final _latestMessage = GlobalKey();
  Animation<double>? _routeAnimation;
  bool _windowFocused = true;
  bool _readCheckScheduled = false;
  String? _paintedLatestId;
  final _displayedPhotos = <String>{};

  void _photoDisplayChanged(String messageId, bool displayed) {
    if (!mounted) return;
    if (displayed) {
      _displayedPhotos.add(messageId);
    } else {
      _displayedPhotos.remove(messageId);
    }
    _scheduleReadCheck();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timelineScroll.addListener(_scheduleReadCheck);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(_routeAnimation, animation)) {
      _routeAnimation?.removeStatusListener(_routeStatusChanged);
      _routeAnimation = animation;
      animation?.addStatusListener(_routeStatusChanged);
    }
    _scheduleReadCheck();
  }

  void _routeStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scheduleReadCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeAnimation?.removeStatusListener(_routeStatusChanged);
    _timelineScroll.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(offlineAccessProvider.notifier).checkExpiry();
      if (_localViewingLocked()) return;
      ref
          .read(conversationControllerProvider(widget.target).notifier)
          .refresh();
    }
  }

  @override
  void didChangeMetrics() => _scheduleReadCheck();

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (!mounted || event.viewId != View.of(context).viewId) return;
    _windowFocused = event.state == ViewFocusState.focused;
    _scheduleReadCheck();
  }

  void _scheduleReadCheck() {
    if (_readCheckScheduled || !mounted) return;
    _readCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readCheckScheduled = false;
      _checkReadVisibility();
    });
  }

  void _checkReadVisibility() {
    if (!mounted ||
        !_windowFocused ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        ModalRoute.of(context)?.animation?.status !=
            AnimationStatus.completed ||
        !TickerMode.valuesOf(context).enabled ||
        !_timelineScroll.hasClients) {
      return;
    }
    if (_localViewingLocked()) return;
    final scroll = _timelineScroll.position;
    if (scroll.outOfRange ||
        scroll.isScrollingNotifier.value ||
        (scroll.pixels - scroll.minScrollExtent).abs() > 1) {
      return;
    }
    final latest = ref
        .read(conversationControllerProvider(widget.target))
        .entries
        .lastOrNull;
    if (latest == null || latest.id != _paintedLatestId) return;
    if (latest.kind == TimelineEntryKind.photo &&
        latest.photo?.isRevoked != true &&
        !_displayedPhotos.contains(latest.id)) {
      return;
    }
    final viewport = _timelineViewport.currentContext?.findRenderObject();
    final message = _latestMessage.currentContext?.findRenderObject();
    if (viewport is! RenderBox ||
        message is! RenderBox ||
        !viewport.attached ||
        !message.attached ||
        !viewport.hasSize ||
        !message.hasSize) {
      return;
    }
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    final rect = message.localToGlobal(Offset.zero) & message.size;
    // The end of the newest message must actually be inside the visible list.
    if (rect.bottom > bounds.bottom ||
        rect.bottom <= bounds.top ||
        rect.right <= bounds.left ||
        rect.left >= bounds.right) {
      return;
    }
    unawaited(
      ref
          .read(conversationReadControllerProvider(widget.target).notifier)
          .acknowledgeVisible(latest, active: true),
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final result = await ref
        .read(conversationControllerProvider(widget.target).notifier)
        .sendText(body, replyToEntryId: _replyToId);
    if (!mounted) return;
    setState(() => _sending = false);
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('发送失败，请检查网络或小队权限'))),
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
      _replyTitle = entry.kind == TimelineEntryKind.photo
          ? (entry.photo?.isRevoked == true ? '已撤回的照片' : '这张照片')
          : entry.kind == TimelineEntryKind.card
          ? (entry.cardSnapshot?.payload['title'] as String? ?? '这张卡片')
          : (entry.text ?? '这条消息');
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(offlineAccessProvider);
    ref.watch(currentUserProvider);
    if (_localViewingLocked()) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请联网登录后查看聊天记录'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(requireOnlineLoginProvider)();
                  context.go('/login');
                },
                child: const Text('前往登录'),
              ),
            ],
          ),
        ),
      );
    }
    final state = ref.watch(conversationControllerProvider(widget.target));
    final entries = state.entries;
    final readState = ref.watch(
      conversationReadControllerProvider(widget.target),
    );
    _scheduleReadCheck();
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.planTitle ?? widget.squadName,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '刷新消息',
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.target).notifier,
                    )
                    .refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        if (readState.error != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('已读同步暂不可用'),
          ),
        if (entries.any((entry) => entry.isLocalCopy))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('部分记录来自本机副本，联网后同步'),
          ),
        if (state.pendingCount > 0)
          MaterialBanner(
            content: Text('有 ${state.pendingCount} 条待发送；联网后会继续重试'),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.target).notifier,
                    )
                    .retryPending(),
                child: const Text('立即重试'),
              ),
            ],
          )
        else if (state.error != null && entries.isNotEmpty)
          MaterialBanner(
            content: Text(_syncError(state.error)),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(
                      conversationControllerProvider(widget.target).notifier,
                    )
                    .refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(
          child: state.isLoading && entries.isEmpty
              ? const Center(child: AppLoadingState(label: '正在加载消息'))
              : state.error != null && entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: '暂时无法显示消息',
                          subtitle: _syncError(state.error),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(
                                conversationControllerProvider(widget.target)
                                    .notifier,
                              )
                              .refresh(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : entries.isEmpty
              ? const Center(child: Text('还没有消息，来打个招呼吧'))
              : ListView.builder(
                  key: _timelineViewport,
                  controller: _timelineScroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => ref
                              .read(
                                conversationControllerProvider(widget.target)
                                    .notifier,
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
                    if (index == 0) _paintedLatestId = entry.id;
                    return Padding(
                      key: index == 0 ? _latestMessage : null,
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TimelineTile(
                        entry: entry,
                        repliedTo: repliedTo,
                        squadName: widget.squadName,
                        photoContent: entry.kind == TimelineEntryKind.photo
                            ? widget.photoBuilder?.call(
                                    context,
                                    entry,
                                    state.error == null && !entry.isLocalCopy,
                                    (displayed) => _photoDisplayChanged(
                                      entry.id,
                                      displayed,
                                    ),
                                  ) ??
                                  const Text('照片需联网查看')
                            : null,
                        readReceipt: MessageReadReceiptButton(
                          target: widget.target,
                          messageId: entry.id,
                          authorId: entry.authorId,
                        ),
                        onReply: () => _replyTo(entry),
                        onOpenCard: entry.kind == TimelineEntryKind.card
                            ? () => widget.onOpenCard?.call(entry)
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
                if (widget.planId == null && widget.onCreatePhoto != null)
                  IconButton(
                    tooltip: '发照片',
                    onPressed: widget.onCreatePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                if (widget.planId == null)
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

  bool _localViewingLocked() {
    final access = ref.read(offlineAccessProvider);
    if (access.status == OfflineAccessStatus.disabled) return false;
    return !access.canReadAt(DateTime.now()) ||
        access.session?.userId !=
            ref.read(currentUserProvider).asData?.value?.id;
  }
}

final class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.repliedTo,
    required this.squadName,
    required this.onReply,
    required this.onOpenCard,
    this.photoContent,
    this.readReceipt,
  });

  final TimelineEntry entry;
  final TimelineEntry? repliedTo;
  final String squadName;
  final VoidCallback onReply;
  final VoidCallback? onOpenCard;
  final Widget? readReceipt;
  final Widget? photoContent;

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
                    reply.kind == TimelineEntryKind.photo
                        ? '回复照片：${reply.photo?.isRevoked == true ? '已撤回' : '小队里的这一刻'}'
                        : '回复 ${reply.kind == TimelineEntryKind.card ? '卡片' : '消息'}：${reply.cardSnapshot?.payload['title'] ?? reply.text ?? ''}',
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
                else if (entry.kind == TimelineEntryKind.photo)
                  photoContent ?? const Text('照片需联网查看')
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
                ?readReceipt,
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

String _syncError(Object? error) => switch (error) {
  PermissionDeniedFailure() => '你已无权访问此会话',
  UnauthorizedFailure() => '请重新登录后查看',
  _ => '消息同步失败，请检查网络后重试',
};
