import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../squad/domain/entities/squad_member.dart';
import '../../domain/entities/external_data_item.dart';
import '../widgets/data_story_card.dart';

/// Select, reshape, preview and explicitly publish one owned data item.
class ShareComposerScreen extends ConsumerStatefulWidget {
  const ShareComposerScreen({super.key, this.initialItemId});

  final String? initialItemId;

  @override
  ConsumerState<ShareComposerScreen> createState() =>
      _ShareComposerScreenState();
}

class _ShareComposerScreenState extends ConsumerState<ShareComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  String? _selectedItemId;
  String _template = 'story';
  String? _visibility;
  final Set<String> _recipientIds = {};
  String? _audienceError;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    final items = ref.read(demoAppStoreProvider).myImportedData;
    _selectedItemId =
        widget.initialItemId ?? (items.isEmpty ? null : items.first.id);
    final selected = _findItem(items, _selectedItemId);
    _titleController = TextEditingController(text: selected?.title ?? '');
    _bodyController = TextEditingController(text: selected?.summary ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _chooseItem(String? id, List<ExternalDataItem> items) {
    if (id == null) return;
    final item = _findItem(items, id);
    if (item == null) return;
    setState(() {
      _selectedItemId = item.id;
      _titleController.text = item.title;
      _bodyController.text = item.summary;
    });
  }

  void _chooseAudience(String visibility) {
    setState(() {
      _visibility = visibility;
      _recipientIds.clear();
      _audienceError = null;
    });
  }

  Future<void> _confirmAndPublish(
    ExternalDataItem item,
    String squadId,
    String squadName,
    List<SquadMember> recipients,
  ) async {
    if (_publishing) return;
    if (!_formKey.currentState!.validate()) return;
    if (_visibility == null) {
      setState(() => _audienceError = '请选择谁能看到这条分享');
      return;
    }
    if (_visibility == 'selected' && _recipientIds.isEmpty) {
      setState(() => _audienceError = '请选择至少一位小队成员');
      return;
    }

    final recipientNames = recipients
        .where((member) => _recipientIds.contains(member.userId))
        .map((member) => member.nickname ?? '成员')
        .toList();
    final audience = _visibility == 'squad'
        ? '「$squadName」的所有成员'
        : recipientNames.join('、');
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('确认发布这条分享？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('接收者：$audience'),
            const SizedBox(height: 8),
            Text('内容：${_titleController.text.trim()}'),
            const SizedBox(height: 8),
            Text('来源：${item.sourceLabel}'),
            const SizedBox(height: 12),
            Text(
              '只发布当前预览的内容，之后的数据变化不会自动同步到这条分享。',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('再检查一下'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认发布'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    setState(() => _publishing = true);
    try {
      // The store checks ownership and current Squad membership again.
      ref
          .read(demoAppStoreProvider.notifier)
          .publishDataPost(
            squadId: squadId,
            dataItemId: item.id,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            template: _template,
            visibility: _visibility!,
            visibleToUserIds: _visibility == 'selected'
                ? _recipientIds.toList(growable: false)
                : const [],
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('发布没有成功，请稍后再试')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoAppStoreProvider);
    final items = state.myImportedData;
    final item = _findItem(items, _selectedItemId);
    final squad = state.currentSquad;
    final ownId = state.currentUser?.id;
    final recipients = squad == null
        ? <SquadMember>[]
        : state
              .membersFor(squad.id)
              .where((member) => member.userId != ownId)
              .toList();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = context.squadlyPalette;

    return Scaffold(
      appBar: AppBar(title: const Text('制作分享')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Text('分享一段生活记录', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  '从自己的记录里挑一段，补上你的感受。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                _DemoNotice(color: colors.onSurfaceVariant),
                const SizedBox(height: 28),
                const _StepTitle(number: '01', title: '选择个人素材'),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const _InfoPanel(
                    icon: Icons.inventory_2_outlined,
                    title: '还没有可分享的素材',
                    body: '数据导入开放后，记录会先进入你的个人空间。',
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: item?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '要分享的记录'),
                    items: [
                      for (final candidate in items)
                        DropdownMenuItem(
                          value: candidate.id,
                          child: Text(
                            '${candidate.title} · ${candidate.sourceLabel}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => _chooseItem(id, items),
                  ),
                  if (item == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '这份素材不可用或不属于你，请重新选择。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                  if (item != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${item.value} ${item.unit} · ${item.sourceLabel} · 原始素材仅自己可见',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 30),
                const _StepTitle(number: '02', title: '写下你的故事'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  enabled: item != null,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '例如：周六终于跑满五公里',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '写一个标题，朋友们会更容易读懂'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bodyController,
                  enabled: item != null,
                  maxLength: 280,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '这段记录背后的事',
                    hintText: '今天有什么值得和小队说的？',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '补充一点你的感受，让分享更有温度'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text('卡片样式', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('故事卡'),
                      avatar: const Icon(Icons.auto_stories_outlined, size: 18),
                      selected: _template == 'story',
                      onSelected: (_) => setState(() => _template = 'story'),
                    ),
                    ChoiceChip(
                      label: const Text('极简卡'),
                      avatar: const Icon(Icons.crop_16_9_rounded, size: 18),
                      selected: _template == 'minimal',
                      onSelected: (_) => setState(() => _template = 'minimal'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const _StepTitle(number: '03', title: '谁可以看到'),
                const SizedBox(height: 10),
                if (squad == null)
                  const _InfoPanel(
                    icon: Icons.groups_outlined,
                    title: '先加入一个小队',
                    body: '分享会只发到你选择的小队。',
                  )
                else ...[
                  Text(
                    '当前小队：${squad.name}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('小队所有成员'),
                        avatar: const Icon(Icons.groups_outlined, size: 18),
                        selected: _visibility == 'squad',
                        onSelected: (_) => _chooseAudience('squad'),
                      ),
                      ChoiceChip(
                        label: const Text('指定成员'),
                        avatar: const Icon(
                          Icons.people_outline_rounded,
                          size: 18,
                        ),
                        selected: _visibility == 'selected',
                        onSelected: (_) => _chooseAudience('selected'),
                      ),
                    ],
                  ),
                  if (_visibility == 'selected') ...[
                    const SizedBox(height: 14),
                    Text('选择接收者', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (recipients.isEmpty)
                      Text(
                        '小队中还没有其他成员。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final member in recipients)
                            FilterChip(
                              label: Text(member.nickname ?? '成员'),
                              selected: _recipientIds.contains(member.userId),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _recipientIds.add(member.userId);
                                  } else {
                                    _recipientIds.remove(member.userId);
                                  }
                                  _audienceError = null;
                                });
                              },
                            ),
                        ],
                      ),
                  ],
                  if (_audienceError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _audienceError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: palette.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('发布前预览', style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (item != null)
                  DataStoryCard(
                    title: _titleController.text,
                    body: _bodyController.text,
                    value: item.value,
                    unit: item.unit,
                    sourceLabel: item.sourceLabel,
                    rangeStart: item.rangeStart,
                    rangeEnd: item.rangeEnd,
                    template: _template,
                    audienceLabel: _audienceLabel(squad?.name, recipients),
                    authorName: state.currentUser?.nickname,
                    trend: item.trend,
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FilledButton.icon(
              onPressed: item == null || squad == null || _publishing
                  ? null
                  : () => _confirmAndPublish(
                      item,
                      squad.id,
                      squad.name,
                      recipients,
                    ),
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_publishing ? '发布中…' : '预览并确认发布'),
            ),
          ),
        ),
      ),
    );
  }

  String _audienceLabel(String? squadName, List<SquadMember> recipients) {
    if (_visibility == 'squad') return squadName ?? '当前小队';
    if (_visibility == 'selected') {
      final selected = recipients
          .where((member) => _recipientIds.contains(member.userId))
          .toList();
      return selected.isEmpty ? '指定成员：尚未选择' : '指定 ${selected.length} 位成员';
    }
    return '尚未选择接收者';
  }
}

ExternalDataItem? _findItem(List<ExternalDataItem> items, String? id) {
  if (id == null) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          number,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
      ],
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '当前素材是演示样本，未连接真实健康账户。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
