import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/activity_source_providers.dart';
import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../app/providers/social_providers.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../activity_import/domain/activity_record.dart';
import '../../../activity_import/domain/activity_source.dart';
import '../../domain/entities/data_connection.dart';
import '../../domain/entities/external_data_item.dart';
import '../widgets/data_story_card.dart';

/// Personal, private staging area for imported material.
class DataWorkshopScreen extends ConsumerWidget {
  const DataWorkshopScreen({super.key, required this.onShareItem});

  final ValueChanged<String> onShareItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(useDemoBackendProvider)) {
      return _RemoteDataWorkshopScreen(onShareItem: onShareItem);
    }
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

class _RemoteDataWorkshopScreen extends ConsumerStatefulWidget {
  const _RemoteDataWorkshopScreen({required this.onShareItem});

  final ValueChanged<String> onShareItem;

  @override
  ConsumerState<_RemoteDataWorkshopScreen> createState() =>
      _RemoteDataWorkshopScreenState();
}

class _RemoteDataWorkshopScreenState
    extends ConsumerState<_RemoteDataWorkshopScreen> {
  bool _importing = false;
  String? _activeUserId;
  int _accountGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final userId = ref.watch(currentUserProvider).asData?.value?.id;
    if (_activeUserId != userId) {
      _activeUserId = userId;
      _accountGeneration++;
    }
    final items = ref
        .watch(myImportedSocialDataProvider)
        .whenData(
          (values) => values
              .where((item) => item.userId == userId)
              .toList(growable: false),
        );
    final connections = ref
        .watch(mySocialConnectionsProvider)
        .whenData(
          (values) => values
              .where((source) => source.userId == userId)
              .toList(growable: false),
        );
    final healthSourceAvailability = ref.watch(healthActivityAvailableProvider);
    final healthSourceLabel = ref.watch(healthActivitySourceLabelProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return items.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLoadingState(label: '正在加载个人素材…'),
            SizedBox(height: 12),
            Text('素材加载中'),
          ],
        ),
      ),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('个人素材加载失败'),
            OutlinedButton(
              onPressed: () => ref.invalidate(myImportedSocialDataProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (values) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('数据工坊', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '个人素材仅自己可见。发布时选择接收范围，并确认单次快照。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('外部来源', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          connections.when(
            loading: () => const ListTile(title: Text('来源状态加载中')),
            error: (_, _) => ListTile(
              title: const Text('来源状态加载失败'),
              trailing: IconButton(
                tooltip: '重试加载来源',
                onPressed: () => ref.invalidate(mySocialConnectionsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            data: (sources) => Card(
              child: sources.isEmpty
                  ? const ListTile(
                      leading: Icon(Icons.health_and_safety_outlined),
                      title: Text('没有持续同步连接'),
                      subtitle: Text('你可以按需授权并单次导入一条运动记录。'),
                    )
                  : Column(
                      children: [
                        for (final (index, source) in sources.indexed) ...[
                          if (index > 0) const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.health_and_safety_outlined,
                            ),
                            title: Text(source.displayName),
                            subtitle: Text(source.isConnected ? '已连接' : '未连接'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  healthSourceAvailability.maybeWhen(
                        data: (available) => available,
                        orElse: () => false,
                      ) &&
                      !_importing
                  ? _importHealthActivity
                  : null,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              label: Text(
                _importing
                    ? '正在读取记录…'
                    : healthSourceAvailability.when(
                        data: (available) => available
                            ? '单次导入 $healthSourceLabel 的运动记录'
                            : '此设备暂不支持健康数据读取',
                        error: (_, _) => '无法检查健康数据来源',
                        loading: () => '正在检查健康数据来源…',
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('我的素材', style: theme.textTheme.titleLarge)),
              Text('${values.length} 份 · 仅自己可见'),
            ],
          ),
          const SizedBox(height: 12),
          if (values.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('还没有个人素材'),
                subtitle: Text('连接或导入来源后，素材会先保存在个人空间。'),
              ),
            )
          else
            for (final item in values) ...[
              DataStoryCard(
                title: item.title,
                body: item.summary,
                value: item.value,
                unit: item.unit,
                sourceLabel: item.sourceLabel,
                rangeStart: item.rangeStart,
                rangeEnd: item.rangeEnd,
                template: 'story',
                audienceLabel: '仅自己可见',
                trend: item.trend,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => widget.onShareItem(item.id),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('制作单次分享'),
              ),
              const SizedBox(height: 20),
            ],
        ],
      ),
    );
  }

  Future<void> _importHealthActivity() async {
    if (_importing) return;
    final userId = ref.read(currentUserProvider).asData?.value?.id;
    if (userId == null) {
      _showImportMessage('请先登录后再导入个人素材');
      return;
    }
    final repository = ref.read(socialRepositoryProvider);
    final generation = _accountGeneration;
    setState(() => _importing = true);
    try {
      final now = DateTime.now();
      final records = await ref
          .read(healthActivitySourceProvider)
          .listEligibleActivities(
            from: now.subtract(
              Duration(days: ref.read(healthActivityLookbackDaysProvider)),
            ),
            to: now,
          );
      if (!mounted) return;
      if (!_sameImportUser(userId, generation)) {
        _showImportMessage('账号已变化，请重新导入');
        return;
      }
      if (records.isEmpty) {
        _showImportMessage(
          '没有读到近 ${ref.read(healthActivityLookbackDaysProvider)} 天可用的跑步或徒步记录',
        );
        return;
      }
      final selected = await _chooseHealthRecord(records, userId, generation);
      if (selected == null || !mounted) return;
      if (!_sameImportUser(userId, generation)) {
        _showImportMessage('账号已变化，请重新导入');
        return;
      }
      final distanceKm = selected.distanceMeters / 1000;
      final minutes = selected.durationSeconds ~/ 60;
      final title =
          '${selected.kind == ActivityKind.run ? '跑步' : '徒步'} · '
          '${selected.startedAt.month}月${selected.startedAt.day}日';
      final item = ExternalDataItem(
        id: const Uuid().v4(),
        userId: userId,
        source: selected.source == ActivitySourceKind.healthConnect
            ? 'health_connect'
            : 'apple_health',
        sourceLabel: selected.sourceLabel,
        category: 'activity',
        title: title,
        summary: '完成 ${(distanceKm).toStringAsFixed(2)} 公里，用时 $minutes 分钟。',
        value: distanceKm.toStringAsFixed(2),
        unit: '公里',
        rangeStart: selected.startedAt,
        rangeEnd: selected.startedAt.add(
          Duration(seconds: selected.durationSeconds),
        ),
        importedAt: DateTime.now(),
      );
      final result = await repository.importDataItem(item: item);
      if (!mounted || !_sameImportUser(userId, generation)) return;
      result.match((_) => _showImportMessage('导入没有成功，请稍后重试'), (_) {
        ref.invalidate(myImportedSocialDataProvider);
        _showImportMessage('已导入个人素材；需要再次确认才会分享给小队');
      });
    } on ActivityPermissionDenied {
      if (_sameImportUser(userId, generation)) {
        _showImportMessage('未获得运动记录读取授权');
      }
    } on ActivitySourceUnavailable {
      if (_sameImportUser(userId, generation)) {
        _showImportMessage('此设备暂不支持健康数据读取，或 Health Connect 尚未安装');
      }
    } catch (_) {
      if (_sameImportUser(userId, generation)) {
        _showImportMessage('读取运动记录失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  bool _sameImportUser(String userId, int generation) =>
      mounted &&
      _accountGeneration == generation &&
      ref.read(currentUserProvider).asData?.value?.id == userId;

  Future<ActivityRecord?> _chooseHealthRecord(
    List<ActivityRecord> records,
    String userId,
    int generation,
  ) => showModalBottomSheet<ActivityRecord>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (_, sheetRef, _) {
        final activeUser = sheetRef
            .watch(currentUserProvider)
            .asData
            ?.value
            ?.id;
        if (activeUser != userId || _accountGeneration != generation) {
          return SafeArea(
            child: ListTile(
              title: const Text('账号已变化，请重新导入'),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ),
          );
        }
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('选择一条运动记录导入')),
                for (final record in records)
                  ListTile(
                    title: Text(
                      '${record.kind == ActivityKind.run ? '跑步' : '徒步'} · '
                      '${(record.distanceMeters / 1000).toStringAsFixed(2)} 公里',
                    ),
                    subtitle: Text(
                      '${record.startedAt.month}月${record.startedAt.day}日 · '
                      '${record.durationSeconds ~/ 60} 分钟 · ${record.sourceLabel}',
                    ),
                    onTap: () => Navigator.of(context).pop(record),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  void _showImportMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
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
