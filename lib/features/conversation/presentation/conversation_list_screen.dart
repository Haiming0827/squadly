import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/conversation_cache_provider.dart';
import '../../../app/providers/conversation_customization_providers.dart';
import '../../../app/providers/current_user_provider.dart';
import '../../../app/providers/offline_access_provider.dart';
import '../../../app/providers/plan_providers.dart';
import '../../../app/providers/squad_context_providers.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_section.dart';
import '../../../shared/widgets/squad_avatar.dart';
import '../../plan/domain/entities/squad_plan.dart';
import '../../squad/domain/entities/squad.dart';
import '../domain/conversation_preference.dart';
import '../domain/conversation_target.dart';
import '../domain/timeline_entry.dart';
import 'conversation_list_controls.dart';
import 'conversation_provider.dart';
import 'frequent_squads.dart';

final remoteConversationSummariesProvider =
    FutureProvider<List<ConversationListItem>>((ref) async {
      final userId = ref.watch(currentUserProvider).asData?.value?.id ?? '';
      final cache = ref.watch(conversationCacheProvider);
      final lease = cache?.lease(userId);
      Future<void> remember(Squad squad, [SquadPlan? plan]) async {
        if (!ref.mounted || cache == null || lease == null) return;
        try {
          await cache.rememberThread(
            lease,
            squad.id,
            squad.name,
            planId: plan?.id,
            planTitle: plan?.title,
          );
        } catch (_) {
          /* Downloaded messages stay available when labels fail. */
        }
      }

      final squads = await ref.watch(mySquadsProvider.future);
      if (squads.isEmpty) return const [];
      final repository = ref.watch(conversationRepositoryProvider);
      final planFutures = [
        for (final squad in squads)
          ref.watch(squadPlansProvider(squad.id).future),
      ];
      final summaries = <ConversationListItem>[];
      for (var index = 0; index < squads.length; index++) {
        final squad = squads[index];
        final plans = await planFutures[index];
        final result = await repository.loadRecent(squad.id);
        if (result.isRight()) await remember(squad);
        summaries.add(
          result.match(
            (failure) => throw StateError(failure.toString()),
            (entries) => ConversationListItem(
              squad: squad,
              latestEntry: entries.lastOrNull,
            ),
          ),
        );
        final planThreads = await Future.wait(
          plans.map((plan) async {
            final result = await repository.loadRecent(
              squad.id,
              planId: plan.id,
            );
            if (result.isRight()) await remember(squad, plan);
            return result.match(
              (failure) => throw StateError(failure.toString()),
              (entries) => ConversationListItem(
                squad: squad,
                plan: plan,
                latestEntry: entries.lastOrNull,
              ),
            );
          }),
        );
        summaries.addAll(planThreads);
      }
      summaries.sort((a, b) {
        final aDate = a.latestEntry?.createdAt;
        final bDate = b.latestEntry?.createdAt;
        if (aDate == null) return bDate == null ? 0 : 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return summaries;
    });

final class ConversationListItem {
  const ConversationListItem({
    required this.squad,
    this.plan,
    this.latestEntry,
  });

  final Squad squad;
  final SquadPlan? plan;
  final TimelineEntry? latestEntry;

  ConversationTarget get target =>
      ConversationTarget(squadId: squad.id, planId: plan?.id);
}

final class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({
    required this.onOpenConversation,
    required this.onOpenSquads,
    this.onOpenPlanConversation,
    super.key,
  });

  final ValueChanged<Squad> onOpenConversation;
  final ValueChanged<ConversationListItem>? onOpenPlanConversation;
  final VoidCallback onOpenSquads;

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

final class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
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
    final summaries = ref.watch(remoteConversationSummariesProvider);
    final preferences = ref.watch(conversationPreferenceMapProvider);
    final customization = ref.watch(conversationPreferencesProvider);
    final offlineAccess = ref.watch(offlineAccessProvider);
    return summaries.when(
      loading: () => const Center(child: AppLoadingState(label: '正在加载会话')),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: '会话加载失败',
              subtitle: '请检查网络后重试。',
            ),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(remoteConversationSummariesProvider),
              child: const Text('重试'),
            ),
            if (offlineAccess.status == OfflineAccessStatus.available ||
                offlineAccess.status == OfflineAccessStatus.expired)
              TextButton(
                onPressed: () => context.push('/offline'),
                child: const Text('查看本机聊天记录'),
              ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: '还没有会话',
                    subtitle: '创建或加入小队后，就能和伙伴开始交流。',
                  ),
                  const SizedBox(height: 12),
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
          for (final summary in items)
            if (matchesConversationActivity(
                  _filter,
                  summary.latestEntry != null,
                  isPlan: summary.plan != null,
                  isPinned: preferences[summary.squad.id]?.isPinned ?? false,
                ) &&
                matchesConversationSearch(
                  query: _query,
                  squadName:
                      '${summary.squad.name} ${preferences[summary.squad.id]?.remark ?? ''} ${summary.plan?.title ?? ''}',
                  preview: _previewFor(summary.latestEntry),
                ))
              summary,
        ];

        // Stable sort: preserve the existing message order within pin groups.
        final ordered = [
          ...filtered.where(
            (item) =>
                item.plan == null &&
                (preferences[item.squad.id]?.isPinned ?? false),
          ),
          ...filtered.where(
            (item) =>
                item.plan != null ||
                !(preferences[item.squad.id]?.isPinned ?? false),
          ),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mySquadsProvider);
            ref.invalidate(remoteConversationSummariesProvider);
            ref.invalidate(conversationPreferencesProvider);
            await ref.read(remoteConversationSummariesProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConversationListControls(
                controller: _searchController,
                query: _query,
                filter: _filter,
                onQueryChanged: (value) => setState(() => _query = value),
                onFilterChanged: (value) => setState(() => _filter = value),
              ),
              FrequentSquads(
                squads: [
                  for (final item in items)
                    if (item.plan == null) item.squad,
                ],
                preferences: preferences,
                onOpen: widget.onOpenConversation,
              ),
              if (customization.hasError)
                ListTile(
                  dense: true,
                  title: const Text('个人会话设置暂未加载'),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.invalidate(conversationPreferencesProvider),
                    child: const Text('重试'),
                  ),
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
                for (var index = 0; index < ordered.length; index++) ...[
                  if (index > 0) const Divider(height: 1, indent: 72),
                  _ConversationTile(
                    key: ValueKey(
                      ordered[index].plan == null
                          ? 'conversation-${ordered[index].squad.id}'
                          : 'conversation-${ordered[index].squad.id}-${ordered[index].plan!.id}',
                    ),
                    summary: ordered[index],
                    preference: preferences[ordered[index].squad.id],
                    onTap: () {
                      final item = ordered[index];
                      if (item.plan == null) {
                        widget.onOpenConversation(item.squad);
                      } else {
                        widget.onOpenPlanConversation?.call(item);
                      }
                    },
                  ),
                ],
            ],
          ),
        );
      },
    );
  }
}

String _previewFor(TimelineEntry? entry) {
  if (entry == null) return '还没有消息，发起第一次交流';
  final body = switch (entry.kind) {
    TimelineEntryKind.text => entry.text ?? '',
    TimelineEntryKind.card => '分享了一张内容卡片',
    TimelineEntryKind.photo =>
      entry.photo?.isHidden == true
          ? '照片已对你隐藏'
          : entry.photo?.isRevoked == true
          ? '照片已撤回'
          : '分享了一张照片',
  };
  return '${entry.authorName}：$body';
}

final class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.summary,
    required this.onTap,
    this.preference,
    super.key,
  });

  final ConversationListItem summary;
  final VoidCallback onTap;
  final ConversationPreference? preference;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final squad = summary.squad;
    final plan = summary.plan;
    final entry = summary.latestEntry;
    final body = entry == null
        ? '还没有消息，发起第一次交流'
        : switch (entry.kind) {
            TimelineEntryKind.text => entry.text ?? '',
            TimelineEntryKind.card => '分享了一张内容卡片',
            TimelineEntryKind.photo =>
              entry.photo?.isHidden == true
                  ? '照片已对你隐藏'
                  : entry.photo?.isRevoked == true
                  ? '照片已撤回'
                  : '分享了一张照片',
          };
    final preview = entry == null ? body : '${entry.authorName}：$body';
    final timestamp = entry?.createdAt;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: SquadAvatar(name: squad.name, avatar: squad.avatarUrl),
      title: Text(
        plan?.title ?? preference?.displayName(squad.name) ?? squad.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        plan == null ? preview : '${squad.name} · $preview',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestamp != null)
            Text(
              _formatTime(timestamp),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: 4),
          if (plan == null && (preference?.isPinned ?? false))
            const Icon(Icons.push_pin_rounded, size: 14),
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
