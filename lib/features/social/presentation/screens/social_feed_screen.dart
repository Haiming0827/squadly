import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../app/providers/social_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../domain/entities/social_post.dart';
import '../widgets/data_story_card.dart';

/// Full feed and compact preview for published, immutable Squad snapshots.
class SocialFeedScreen extends ConsumerWidget {
  const SocialFeedScreen({required this.squadId, super.key});

  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('小队动态')),
    body: _SocialFeedList(squadId: squadId),
  );
}

class SocialFeedSection extends ConsumerWidget {
  const SocialFeedSection({
    required this.squadId,
    required this.onOpenFeed,
    super.key,
  });

  final String squadId;
  final VoidCallback onOpenFeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(squadSocialPostsProvider(squadId));
    return AppSection(
      title: '小队动态',
      trailing: TextButton(onPressed: onOpenFeed, child: const Text('查看全部')),
      child: posts.when(
        loading: () => const _FeedStatus(
          icon: Icons.hourglass_top_rounded,
          message: '动态加载中',
        ),
        error: (error, _) => _RetryStatus(
          message: error is StateError ? error.message.toString() : '动态加载失败',
          onRetry: () => ref.invalidate(squadSocialPostsProvider(squadId)),
        ),
        data: (items) => items.isEmpty
            ? const _FeedStatus(
                icon: Icons.auto_awesome_outlined,
                message: '还没有小队动态',
              )
            : Column(
                children: [
                  for (final (index, post) in items.take(2).indexed) ...[
                    if (index > 0) const SizedBox(height: 12),
                    _SocialPostCard(post: post, squadId: squadId),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SocialFeedList extends ConsumerWidget {
  const _SocialFeedList({required this.squadId});

  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(squadSocialPostsProvider(squadId));
    return posts.when(
      loading: () => const _FeedStatus(
        icon: Icons.hourglass_top_rounded,
        message: '动态加载中',
      ),
      error: (error, _) => _RetryStatus(
        message: error is StateError ? error.message.toString() : '动态加载失败',
        onRetry: () => ref.invalidate(squadSocialPostsProvider(squadId)),
      ),
      data: (items) => items.isEmpty
          ? const _FeedStatus(
              icon: Icons.auto_awesome_outlined,
              message: '还没有小队动态',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _SocialPostCard(post: items[index], squadId: squadId),
            ),
    );
  }
}

class _SocialPostCard extends ConsumerWidget {
  const _SocialPostCard({required this.post, required this.squadId});

  final SocialPost post;
  final String squadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentSocialUserIdProvider);
    final reacted =
        currentUserId != null && post.reactionUserIds.contains(currentUserId);
    final audience = post.visibility == 'squad' ? '小队可见' : '指定成员可见';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DataStoryCard(
              title: post.title,
              body: post.body,
              value: post.metricValue,
              unit: post.metricUnit,
              sourceLabel: post.sourceLabel,
              rangeStart: post.rangeStart,
              rangeEnd: post.rangeEnd,
              template: post.template,
              audienceLabel: audience,
              authorName: post.authorName,
              trend: post.trend,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: currentUserId == null
                    ? null
                    : () => _toggleReaction(context, ref),
                icon: Icon(
                  reacted ? Icons.favorite_rounded : Icons.favorite_border,
                  size: 18,
                ),
                label: Text(
                  post.reactionUserIds.isEmpty
                      ? '鼓励'
                      : '${post.reactionUserIds.length}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleReaction(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(socialRepositoryProvider)
        .togglePostReaction(postId: post.id, squadId: squadId);
    if (!context.mounted) return;
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_reactionFailureMessage(failure)))),
      (_) => ref.invalidate(squadSocialPostsProvider(squadId)),
    );
  }
}

class _FeedStatus extends StatelessWidget {
  const _FeedStatus({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _RetryStatus extends StatelessWidget {
  const _RetryStatus({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: Text(message),
      trailing: IconButton(
        tooltip: '重试加载动态',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

String _reactionFailureMessage(Failure failure) => switch (failure) {
  UnauthorizedFailure() => '请先登录后再鼓励队友',
  PermissionDeniedFailure() => '你无权操作这条动态',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '操作没有成功，请稍后重试',
};
