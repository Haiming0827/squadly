import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/offline_access_provider.dart';
import '../../../app/providers/offline_conversation_provider.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_section.dart';
import '../domain/timeline_entry.dart';

final class OfflineConversationsScreen extends ConsumerStatefulWidget {
  const OfflineConversationsScreen({super.key});
  @override
  ConsumerState<OfflineConversationsScreen> createState() =>
      _OfflineConversationsScreenState();
}

final class _OfflineConversationsScreenState
    extends ConsumerState<OfflineConversationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(offlineAccessProvider.notifier).checkExpiry();
    }
  }

  void _login() {
    ref.read(requireOnlineLoginProvider)();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(offlineAccessProvider);
    final allowed = access.canReadAt(DateTime.now());
    final archive = ref.watch(offlineConversationProvider);
    final controller = ref.read(offlineConversationProvider.notifier);
    final selected = allowed ? archive.selected : null;
    return PopScope(
      canPop: selected == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected != null) controller.back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selected == null
              ? null
              : BackButton(onPressed: controller.back),
          title: Text(
            selected?.title ?? '本机聊天记录',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: !allowed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (access.status == OfflineAccessStatus.checking)
                        const AppLoadingState(label: '正在检查本机会话')
                      else ...[
                        EmptyState(
                          icon: Icons.lock_outline,
                          title: access.status == OfflineAccessStatus.expired
                              ? '登录已过期'
                              : '请先联网登录',
                          subtitle: '联网登录后可查看已下载的本机记录。',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _login,
                          child: const Text('前往登录'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      selected?.target.isPlanDiscussion == true
                          ? '${selected!.squadName} · 本机副本 · 只读'
                          : '本机副本 · 只读',
                    ),
                  ),
                  if (archive.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(archive.error!),
                    ),
                  if (archive.isLoading && archive.entries.isEmpty)
                    const Expanded(
                      child: Center(child: AppLoadingState(label: '正在读取本机记录')),
                    )
                  else if (selected == null && archive.threads.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: '还没有本机聊天记录',
                              subtitle: '联网打开会话后，已下载的记录会保存在这里。',
                            ),
                            if (archive.error != null)
                              TextButton(
                                onPressed: controller.initialize,
                                child: const Text('重试'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else if (selected == null)
                    Expanded(
                      child: ListView.builder(
                        itemCount: archive.threads.length,
                        itemBuilder: (context, index) {
                          final thread = archive.threads[index];
                          return ListTile(
                            title: Text(
                              thread.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${thread.target.isPlanDiscussion ? '${thread.squadName} · ' : ''}${_preview(thread.latestEntry)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => controller.open(thread),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (archive.hasOlder)
                            TextButton(
                              onPressed: archive.isLoading
                                  ? null
                                  : controller.loadOlder,
                              child: Text(
                                archive.isLoading ? '正在读取…' : '查看更早记录',
                              ),
                            ),
                          if (archive.error != null && archive.entries.isEmpty)
                            TextButton(
                              onPressed: () => controller.open(selected),
                              child: const Text('重试'),
                            ),
                          if (archive.entries.isEmpty && archive.error == null)
                            const Text('此会话没有已下载的记录'),
                          for (final entry in archive.entries)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.authorName} · ${_time(entry.createdAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(_body(entry)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

String _preview(TimelineEntry entry) =>
    '${entry.authorName}：${entry.kind == TimelineEntryKind.text
        ? entry.text
        : entry.kind == TimelineEntryKind.photo
        ? '分享了一张照片'
        : '分享了一张卡片'}';
String _body(TimelineEntry entry) => entry.kind == TimelineEntryKind.text
    ? entry.text ?? ''
    : entry.kind == TimelineEntryKind.photo
    ? (entry.photo?.isRevoked == true ? '照片已撤回' : '照片需联网查看')
    : '卡片摘要：${entry.cardSnapshot?.payload['title'] ?? '小队里的这一刻'}';
String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.year}/${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
