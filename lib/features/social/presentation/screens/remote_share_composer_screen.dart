import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/domain_repository_providers.dart';
import '../../../../app/providers/social_providers.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../squad/domain/entities/squad.dart';
import '../../../squad/domain/entities/squad_member.dart';
import '../../domain/entities/external_data_item.dart';
import '../../domain/entities/social_post.dart';
import '../widgets/data_story_card.dart';

/// CloudBase one-time snapshot composer. Publication always revalidates through
/// the RPC; the composer never writes Social rows directly.
class RemoteShareComposerScreen extends ConsumerStatefulWidget {
  const RemoteShareComposerScreen({super.key, this.initialItemId});

  final String? initialItemId;

  @override
  ConsumerState<RemoteShareComposerScreen> createState() =>
      _RemoteShareComposerScreenState();
}

class _RemoteShareComposerScreenState
    extends ConsumerState<RemoteShareComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  String? _selectedItemId;
  String? _editedItemId;
  String? _visibility;
  String _template = 'story';
  final Set<String> _recipients = {};
  bool _publishing = false;
  bool _confirming = false;
  (String, String?)? _draftContext;
  int _contextRevision = 0;

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.initialItemId;
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(myImportedSocialDataProvider);
    final user = ref.watch(currentUserProvider);
    final squad = ref.watch(currentSquadProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('制作分享')),
      body: user.when(
        loading: () => const Center(child: AppLoadingState(label: '正在加载账号状态…')),
        error: (_, _) => _LoadFailure(
          message: '账号状态读取失败',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (currentUser) {
          if (currentUser == null) {
            return const Center(child: Text('请先登录后再准备分享'));
          }
          return squad.when(
            loading: () =>
                const Center(child: AppLoadingState(label: '正在加载当前小队…')),
            error: (_, _) => _LoadFailure(
              message: '当前小队加载失败',
              onRetry: () => ref.invalidate(mySquadsProvider),
            ),
            data: (currentSquad) {
              _resetDraftContext(currentUser.id, currentSquad?.id);
              return items.when(
                loading: () =>
                    const Center(child: AppLoadingState(label: '正在加载个人素材…')),
                error: (_, _) => _LoadFailure(
                  message: '个人素材加载失败',
                  onRetry: () => ref.invalidate(myImportedSocialDataProvider),
                ),
                data: (loadedValues) {
                  final values = loadedValues
                      .where((item) => item.userId == currentUser.id)
                      .toList(growable: false);
                  if (values.isEmpty) {
                    return const _NoItems();
                  }
                  final item =
                      values
                          .where((value) => value.id == _selectedItemId)
                          .firstOrNull ??
                      values.first;
                  if (_editedItemId != item.id) {
                    _selectedItemId = item.id;
                    _editedItemId = item.id;
                    _titleController.text = item.title;
                    _bodyController.text = item.summary;
                  }
                  final members = currentSquad == null
                      ? const AsyncData(<SquadMember>[])
                      : ref.watch(squadMembersProvider(currentSquad.id));
                  final allowedRecipients = (members.value ?? const [])
                      .where((member) => member.userId != currentUser.id)
                      .toList(growable: false);
                  return _composerContent(
                    item: item,
                    values: values,
                    squad: currentSquad,
                    currentUserName: currentUser.nickname,
                    memberState: members,
                    recipients: allowedRecipients,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _resetDraftContext(String userId, String? squadId) {
    final nextContext = (userId, squadId);
    if (_draftContext == nextContext) return;
    final initial = _draftContext == null;
    _draftContext = nextContext;
    _contextRevision++;
    _selectedItemId = initial ? widget.initialItemId : null;
    _editedItemId = null;
    _visibility = null;
    _template = 'story';
    _recipients.clear();
    _titleController.clear();
    _bodyController.clear();
  }

  Widget _composerContent({
    required ExternalDataItem item,
    required List<ExternalDataItem> values,
    required Squad? squad,
    required String currentUserName,
    required AsyncValue<List<SquadMember>> memberState,
    required List<SquadMember> recipients,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (squad == null)
            const Card(
              child: ListTile(
                leading: Icon(Icons.groups_outlined),
                title: Text('请先创建或加入小队'),
                subtitle: Text('分享始终发布到当前小队上下文。'),
              ),
            )
          else ...[
            Text('分享至 ${squad.name}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: item.id,
              decoration: const InputDecoration(labelText: '选择个人素材'),
              items: [
                for (final value in values)
                  DropdownMenuItem(value: value.id, child: Text(value.title)),
              ],
              onChanged: (id) => setState(() {
                _selectedItemId = id;
                final selected = values.where((value) => value.id == id).first;
                _editedItemId = selected.id;
                _titleController.text = selected.title;
                _bodyController.text = selected.summary;
              }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              maxLength: 160,
              decoration: const InputDecoration(labelText: '标题'),
              onChanged: (_) => setState(() {}),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入标题' : null,
            ),
            TextFormField(
              controller: _bodyController,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '补充一句'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'story', label: Text('故事卡')),
                ButtonSegment(value: 'stat', label: Text('数据卡')),
              ],
              selected: {_template},
              onSelectionChanged: (value) =>
                  setState(() => _template = value.first),
            ),
            const SizedBox(height: 16),
            DataStoryCard(
              title: _titleController.text,
              body: _bodyController.text,
              value: item.value,
              unit: item.unit,
              sourceLabel: item.sourceLabel,
              rangeStart: item.rangeStart,
              rangeEnd: item.rangeEnd,
              template: _template,
              audienceLabel: _visibility == 'selected' ? '指定成员可见' : '待选择范围',
              authorName: currentUserName,
              trend: item.trend,
            ),
            const SizedBox(height: 18),
            Text('谁可以看到', style: theme.textTheme.titleMedium),
            RadioGroup<String>(
              groupValue: _visibility,
              onChanged: (value) => setState(() {
                _visibility = value;
                _recipients.clear();
              }),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'squad',
                    title: Text('小队所有成员'),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'selected',
                    title: Text('指定成员'),
                  ),
                ],
              ),
            ),
            if (_visibility == 'selected') ...[
              if (memberState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('成员加载中'),
                    ],
                  ),
                )
              else if (memberState.hasError)
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(squadMembersProvider(squad.id)),
                  child: const Text('成员加载失败，点击重试'),
                )
              else if (recipients.isEmpty)
                Text('目前没有可选择的其他成员', style: theme.textTheme.bodySmall)
              else
                for (final member in recipients)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _recipients.contains(member.userId),
                    title: Text(member.nickname ?? '小队成员'),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _recipients.add(member.userId);
                      } else {
                        _recipients.remove(member.userId);
                      }
                    }),
                  ),
            ],
            if (_visibility == null)
              Text('请选择分享范围', style: TextStyle(color: colors.error)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _publishing || _confirming
                    ? null
                    : () => _confirmPublish(
                        item,
                        squad.id,
                        squad.name,
                        recipients,
                      ),
                child: Text(_publishing ? '正在发布…' : '预览并确认发布'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPublish(
    ExternalDataItem item,
    String squadId,
    String squadName,
    List<SquadMember> recipients,
  ) async {
    if (_publishing || _confirming || !_formKey.currentState!.validate()) {
      return;
    }
    if (_visibility == null ||
        (_visibility == 'selected' && _recipients.isEmpty)) {
      setState(() {});
      return;
    }
    final authorId = item.userId;
    final revision = _contextRevision;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final template = _template;
    final visibility = _visibility!;
    final recipientIds = visibility == 'selected'
        ? List<String>.unmodifiable(_recipients)
        : const <String>[];
    if (!_canPublish(authorId, squadId, item.id, recipientIds, revision)) {
      _showContextChanged();
      return;
    }
    final repository = ref.read(socialRepositoryProvider);
    final recipientNames = recipients
        .where((member) => recipientIds.contains(member.userId))
        .map((member) => member.nickname ?? '小队成员')
        .join('、');
    final audience = visibility == 'squad'
        ? '「$squadName」的所有成员'
        : recipientNames;
    setState(() => _confirming = true);
    bool? approved;
    try {
      approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Consumer(
          builder: (_, dialogRef, _) {
            dialogRef.watch(currentUserProvider);
            dialogRef.watch(currentSquadProvider);
            dialogRef.watch(myImportedSocialDataProvider);
            if (recipientIds.isNotEmpty) {
              dialogRef.watch(squadMembersProvider(squadId));
            }
            if (!_canPublish(
              authorId,
              squadId,
              item.id,
              recipientIds,
              revision,
            )) {
              return AlertDialog(
                title: const Text('分享上下文已变化'),
                content: const Text('请返回后重新选择素材和接收成员。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('返回修改'),
                  ),
                ],
              );
            }
            return AlertDialog(
              scrollable: true,
              title: const Text('确认发布这条分享？'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('接收者：$audience'),
                  const SizedBox(height: 8),
                  Text('内容：$title'),
                  const SizedBox(height: 8),
                  Text('来源：${item.sourceLabel} · ${item.value} ${item.unit}'),
                  const SizedBox(height: 12),
                  const Text('本次只发布当前预览的快照，来源数据变化不会更新这条分享。'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('返回修改'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('确认发布'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    if (approved != true || !mounted) return;
    if (!_canPublish(authorId, squadId, item.id, recipientIds, revision)) {
      _showContextChanged();
      return;
    }
    setState(() => _publishing = true);
    final result = await repository.publishDataPost(
      squadId: squadId,
      dataItemId: item.id,
      title: title,
      body: body,
      template: template,
      visibility: visibility,
      visibleToUserIds: recipientIds,
    );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (_contextRevision != revision) return;
    result.match(
      (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('分享没有发布成功，请重试'))),
      (SocialPost _) {
        ref.invalidate(squadSocialPostsProvider(squadId));
        Navigator.of(context).pop(true);
      },
    );
  }

  bool _canPublish(
    String authorId,
    String squadId,
    String itemId,
    List<String> recipients,
    int revision,
  ) {
    if (!mounted ||
        _contextRevision != revision ||
        ref.read(currentUserProvider).asData?.value?.id != authorId ||
        ref.read(currentSquadProvider).asData?.value?.id != squadId ||
        _selectedItemId != itemId) {
      return false;
    }
    final items = ref.read(myImportedSocialDataProvider).asData?.value;
    if (items == null ||
        !items.any((item) => item.id == itemId && item.userId == authorId)) {
      return false;
    }
    if (recipients.isEmpty) return true;
    final members = ref.read(squadMembersProvider(squadId)).asData?.value;
    return members != null &&
        recipients.every(
          (id) =>
              id != authorId && members.any((member) => member.userId == id),
        );
  }

  void _showContextChanged() => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('账号、小队或接收成员已变化，请重新预览后发布')));
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry, this.message = '个人素材加载失败'});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _NoItems extends StatelessWidget {
  const _NoItems();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('还没有个人素材，请先到数据工坊导入。'),
    ),
  );
}
