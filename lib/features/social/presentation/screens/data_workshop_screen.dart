import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/data_connection.dart';
import '../../domain/entities/external_data_item.dart';
import '../widgets/data_story_card.dart';

/// Personal, private staging area for imported material.
class DataWorkshopScreen extends ConsumerWidget {
  const DataWorkshopScreen({super.key, required this.onShareItem});

  final ValueChanged<String> onShareItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoAppStoreProvider);
    final items = state.myImportedData;
    final connections = state.myDataConnections;
    final canShare = state.currentSquad != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = context.squadlyPalette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 104),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('数据工坊', style: theme.textTheme.headlineSmall),
                    ),
                    const SizedBox(width: 12),
                    _PrivacyBadge(color: palette.privacy),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '把散落在各处的记录，讲成自己的故事。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '当前为演示导入样本，尚未读取你的 Apple、小米或华为账户。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionHeading(title: '外部来源', trailing: '数据先留在个人空间'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _sources.length; index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            indent: 60,
                            color: colors.outlineVariant,
                          ),
                        _SourceRow(
                          source: _sources[index],
                          connection: _connectionFor(
                            connections,
                            _sources[index].key,
                          ),
                          sampleCount: items
                              .where(
                                (item) => item.source == _sources[index].key,
                              )
                              .length,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _SectionHeading(
                  title: '我的素材',
                  trailing: '${items.length} 份 · 仅自己可见',
                ),
                const SizedBox(height: 12),
                if (!canShare && items.isNotEmpty) ...[
                  Text(
                    '加入小队后即可选择成员分享。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isEmpty)
                  const _EmptyMaterials()
                else ...[
                  DataStoryCard(
                    title: items.first.title,
                    body: items.first.summary,
                    value: items.first.value,
                    unit: items.first.unit,
                    sourceLabel: items.first.sourceLabel,
                    rangeStart: items.first.rangeStart,
                    rangeEnd: items.first.rangeEnd,
                    template: 'story',
                    audienceLabel: '仅自己可见',
                    authorName: state.currentUser?.nickname,
                    trend: items.first.trend,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canShare
                          ? () => onShareItem(items.first.id)
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: const Text('用这条记录做分享'),
                    ),
                  ),
                  if (items.length > 1) ...[
                    const SizedBox(height: 20),
                    for (final item in items.skip(1)) ...[
                      Divider(height: 1, color: colors.outlineVariant),
                      _MaterialRow(
                        item: item,
                        onTap: canShare ? () => onShareItem(item.id) : null,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '私人空间',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDefinition {
  const _SourceDefinition(this.key, this.name, this.icon);

  final String key;
  final String name;
  final IconData icon;
}

const _sources = [
  _SourceDefinition('apple_health', 'Apple 健康', Icons.favorite_border_rounded),
  _SourceDefinition('mi_fitness', '小米运动健康', Icons.directions_run_rounded),
  _SourceDefinition('huawei_health', '华为运动健康', Icons.monitor_heart_outlined),
];

DataConnection? _connectionFor(
  List<DataConnection> connections,
  String provider,
) {
  for (final connection in connections) {
    if (connection.provider == provider) return connection;
  }
  return null;
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.connection,
    required this.sampleCount,
  });

  final _SourceDefinition source;
  final DataConnection? connection;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final importMode = switch (connection?.mode) {
      'sync' => '授权同步',
      'file_import' => '文件导入',
      _ => null,
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(source.icon, size: 22, color: colors.onSurface),
      ),
      title: Text(source.name, style: theme.textTheme.titleSmall),
      subtitle: Text(
        sampleCount == 0 ? '尚无演示素材' : '$sampleCount 份演示素材',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  importMode == null
                      ? '真实接入方式尚未确定。当前素材为内置演示样本。'
                      : '界面演示$importMode流程。真实同步与导入尚未开放，当前素材为内置演示样本。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  '未来导入后，数据会先进入个人空间；只有你预览并确认发布的内容才会与小队共享。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.item, required this.onTap});

  final ExternalDataItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${item.sourceLabel} · ${item.summary}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        onTap == null
            ? Icons.lock_outline_rounded
            : Icons.arrow_forward_rounded,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _EmptyMaterials extends StatelessWidget {
  const _EmptyMaterials();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('这里还没有素材', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '外部数据导入开放后，个人记录会先出现在这里。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
