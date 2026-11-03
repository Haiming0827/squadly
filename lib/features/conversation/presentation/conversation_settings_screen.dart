import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/conversation_customization_providers.dart';
import '../../../app/providers/squad_context_providers.dart';
import '../../../core/error/failures.dart';
import '../../../shared/widgets/squad_avatar.dart';
import '../../squad/domain/squad_avatar_format.dart';
import '../domain/conversation_preference.dart';

final class ConversationSettingsScreen extends ConsumerStatefulWidget {
  const ConversationSettingsScreen({
    required this.squadId,
    required this.onManageMembers,
    super.key,
  });
  final String squadId;
  final VoidCallback onManageMembers;
  @override
  ConsumerState<ConversationSettingsScreen> createState() =>
      _ConversationSettingsState();
}

final class _ConversationSettingsState
    extends ConsumerState<ConversationSettingsScreen> {
  final _remark = TextEditingController(),
      _name = TextEditingController(),
      _description = TextEditingController();
  bool _pinned = false, _saving = false;
  String? _avatar, _initializedFor, _error;
  @override
  void dispose() {
    _remark.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _current(String? owner) =>
      mounted && ref.read(customizationUserIdProvider) == owner;
  void _result(Failure? failure, String success) {
    setState(
      () => _error = failure == null ? null : squadFailureMessage(failure),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure == null ? success : squadFailureMessage(failure)),
      ),
    );
  }

  Future<void> _savePersonal() async {
    final owner = ref.read(customizationUserIdProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(conversationCustomizationRepositoryProvider)
        .save(squadId: widget.squadId, remark: _remark.text, pinned: _pinned);
    if (!_current(owner)) return;
    setState(() => _saving = false);
    result.fold((failure) => _result(failure, ''), (_) {
      ref.invalidate(conversationPreferencesProvider);
      _result(null, '个人会话设置已保存');
    });
  }

  Future<void> _saveProfile() async {
    final owner = ref.read(customizationUserIdProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(squadProfileRepositoryProvider)
        .save(
          squadId: widget.squadId,
          name: _name.text,
          description: _description.text,
          avatar: _avatar,
        );
    if (!_current(owner)) return;
    setState(() => _saving = false);
    result.fold((failure) => _result(failure, ''), (_) {
      ref.invalidate(mySquadsProvider);
      ref.invalidate(settingsSquadProvider(widget.squadId));
      _result(null, '小队资料已保存');
    });
  }

  Future<void> _pickAvatar() async {
    final owner = ref.read(customizationUserIdProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(squadAvatarPickerProvider).pick();
    if (!_current(owner)) return;
    setState(() => _saving = false);
    result.fold((failure) => _result(failure, ''), (avatar) {
      if (avatar != null) setState(() => _avatar = avatar);
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(customizationUserIdProvider);
    final squadState = ref.watch(settingsSquadProvider(widget.squadId));
    final members = ref.watch(settingsMembersProvider(widget.squadId));
    final prefs = ref.watch(conversationPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('会话设置')),
      body: squadState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _retry('小队资料加载失败', () {
          ref.invalidate(mySquadsProvider);
          ref.invalidate(settingsSquadProvider(widget.squadId));
        }),
        data: (squad) {
          if (squad == null || owner == null) {
            return const Center(child: Text('你已不在该小队中'));
          }
          if (prefs.isLoading && !prefs.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prefs.hasError) {
            return _retry(
              '会话设置加载失败',
              () => ref.invalidate(conversationPreferencesProvider),
            );
          }
          final preference =
              (prefs.asData?.value ?? <ConversationPreference>[])
                  .where((p) => p.squadId == squad.id)
                  .firstOrNull ??
              ConversationPreference(squadId: squad.id);
          final identity = '$owner/${squad.id}';
          if (_initializedFor != identity) {
            _initializedFor = identity;
            _remark.text = preference.remark;
            _pinned = preference.isPinned;
            _name.text = squad.name;
            _description.text = squad.description ?? '';
            _avatar = decodeSquadAvatar(squad.avatarUrl) != null
                ? squad.avatarUrl
                : null;
            _saving = false;
            _error = null;
          }
          final captain =
              members.asData?.value.any(
                (m) => m.userId == owner && m.role == 'captain',
              ) ??
              false;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('个人设置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('conversation-remark'),
                controller: _remark,
                enabled: !_saving,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: '会话备注',
                  helperText: '仅自己可见，留空使用小队名称',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('置顶会话'),
                subtitle: const Text('优先显示在会话列表和常用栏'),
                value: _pinned,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _pinned = value),
              ),
              OutlinedButton(
                onPressed: _saving ? null : _savePersonal,
                child: const Text('保存个人设置'),
              ),
              const Divider(height: 32),
              Text('小队资料', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Center(
                child: SquadAvatar(
                  name: squad.name,
                  avatar: captain ? _avatar : squad.avatarUrl,
                  radius: 40,
                ),
              ),
              if (captain)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _saving ? null : _pickAvatar,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('选择头像'),
                    ),
                    TextButton(
                      onPressed: _saving || _avatar == null
                          ? null
                          : () => setState(() => _avatar = null),
                      child: const Text('恢复默认'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (captain) ...[
                TextField(
                  key: const ValueKey('squad-shared-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: '小队名称（全员可见）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  enabled: !_saving,
                  maxLength: 200,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '小队简介'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: const Text('保存小队资料'),
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(squad.name),
                  subtitle: Text(
                    squad.description?.isNotEmpty == true
                        ? squad.description!
                        : '暂无简介',
                  ),
                ),
                Text(
                  members.hasError ? '成员权限加载失败，暂不能编辑' : '共享名称和头像由队长修改',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_saving) const LinearProgressIndicator(),
              const Divider(height: 32),
              members.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => _retry('成员加载失败', () {
                  ref.invalidate(squadMembersProvider(squad.id));
                  ref.invalidate(settingsMembersProvider(squad.id));
                }),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '小队成员（${list.length}/${squad.maxMembers}）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final member in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            (member.nickname ?? '队友').characters.firstOrNull ??
                                '队',
                          ),
                        ),
                        title: Text(member.nickname ?? '队友'),
                        trailing: Text(member.role == 'captain' ? '队长' : '成员'),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : widget.onManageMembers,
                icon: const Icon(Icons.group_outlined),
                label: const Text('管理小队成员'),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _retry(String text, VoidCallback retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        TextButton(onPressed: retry, child: const Text('重试')),
      ],
    ),
  );
}
