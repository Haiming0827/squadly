import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/issued_invitation.dart';
import '../../domain/entities/squad.dart';
import '../../domain/invitation_credential.dart';
import '../providers/squad_provider.dart';

class SquadListScreen extends ConsumerWidget {
  const SquadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const useDemoBackend = bool.fromEnvironment(
      'USE_DEMO_BACKEND',
      defaultValue: true,
    );
    if (!useDemoBackend) return const RemoteSquadListScreen();

    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;

    if (squad == null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                icon: Icons.group_add_outlined,
                title: '还没有小队',
                subtitle: '创建或加入一个小队，邀请熟悉的伙伴一起分享。',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: () => _showCreateDialog(context, store),
                        child: const Text('创建小队'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => _showJoinDialog(context, store),
                        child: const Text('输入邀请码加入'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final members = state.membersFor(squad.id);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '当前小队',
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '加入小队',
                onPressed: () => _showJoinDialog(context, store),
                icon: const Icon(Icons.login_rounded),
              ),
              IconButton(
                tooltip: '创建小队',
                onPressed: () => _showCreateDialog(context, store),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Text(squad.name.characters.first)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              squad.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (squad.description != null)
                              Text(
                                squad.description!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      MetricTile(
                        label: '成员',
                        value: '${members.length}/${squad.maxMembers}',
                        icon: Icons.people_alt_outlined,
                      ),
                      const SizedBox(width: 10),
                      MetricTile(
                        label: '邀请码',
                        value: squad.inviteCode,
                        icon: Icons.key_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSection(
          title: '成员',
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (final member in members)
                  _MemberTile(
                    name: member.nickname ?? '成员',
                    role: member.role,
                    isMe: member.userId == state.currentUser?.id,
                    canManage:
                        state.isCaptain &&
                        member.userId != state.currentUser?.id &&
                        members.length > AppConstants.squadMinMembers,
                    onRemove: () {
                      _guardAction(
                        context,
                        () => store.removeMember(
                          squadId: squad.id,
                          userId: member.userId,
                        ),
                      );
                    },
                    onTransfer:
                        state.isCaptain &&
                            member.role != AppConstants.roleCaptain
                        ? () {
                            _guardAction(
                              context,
                              () => store.transferCaptain(
                                squadId: squad.id,
                                newCaptainId: member.userId,
                              ),
                            );
                          }
                        : null,
                  ),
              ],
            ),
          ),
        ),
        AppSection(
          title: '我的小队',
          child: Column(
            children: [
              for (final item in state.mySquads)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.id == squad.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                    title: Text(item.name),
                    subtitle: Text('邀请码 ${item.inviteCode}'),
                    onTap: () => store.selectSquad(item.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    DemoAppStore store,
  ) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建小队'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '小队名称'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '描述'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (!Validators.isValidSquadName(name)) {
                _showSnack(context, '小队名称需要 1-20 个字符');
                return;
              }
              _guardAction(
                context,
                () => store.createSquad(
                  name: name,
                  description: descriptionController.text,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showJoinDialog(BuildContext context, DemoAppStore store) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入小队'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '邀请码'),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              _guardAction(
                context,
                () => store.joinSquad(inviteCode: controller.text),
              );
              Navigator.pop(context);
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.role,
    required this.isMe,
    required this.canManage,
    required this.onRemove,
    this.onTransfer,
  });

  final String name;
  final String role;
  final bool isMe;
  final bool canManage;
  final VoidCallback onRemove;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(name.characters.first)),
      title: Text(isMe ? '$name（我）' : name),
      subtitle: Text(role == AppConstants.roleCaptain ? '队长' : '成员'),
      trailing: canManage || onTransfer != null
          ? PopupMenuButton<String>(
              tooltip: '成员操作',
              onSelected: (value) {
                if (value == 'remove') onRemove();
                if (value == 'transfer') onTransfer?.call();
              },
              itemBuilder: (context) => [
                if (onTransfer != null)
                  const PopupMenuItem(value: 'transfer', child: Text('转让队长')),
                if (canManage)
                  const PopupMenuItem(value: 'remove', child: Text('移除成员')),
              ],
            )
          : null,
    );
  }
}

void _guardAction(BuildContext context, VoidCallback action) {
  try {
    action();
  } on StateError catch (error) {
    _showSnack(context, error.message);
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class RemoteSquadListScreen extends ConsumerStatefulWidget {
  const RemoteSquadListScreen({super.key});

  @override
  ConsumerState<RemoteSquadListScreen> createState() => _RemoteSquadListState();
}

class _RemoteSquadListState extends ConsumerState<RemoteSquadListScreen> {
  bool _busy = false;
  IssuedInvitation? _invitation;
  String? _invitationSquadId;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentSquadProvider);
    final all = ref.watch(mySquadsProvider);

    return current.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('小队加载失败'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(mySquadsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (squad) => squad == null
          ? _emptyState(context)
          : _squadDetails(context, squad, all.valueOrNull ?? [squad]),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EmptyState(
            icon: Icons.group_add_outlined,
            title: '还没有小队',
            subtitle: '创建一个小队，或通过朋友的邀请加入。',
          ),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: const Text('创建小队'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: const Text('输入邀请码或邀请链接'),
          ),
        ],
      ),
    ),
  );

  Widget _squadDetails(
    BuildContext context,
    Squad squad,
    List<Squad> allSquads,
  ) {
    final members = ref.watch(squadMembersProvider(squad.id));
    final currentUserId = ref.watch(authNotifierProvider).valueOrNull?.id;
    final myRole = members.valueOrNull
        ?.where((member) => member.userId == currentUserId)
        .firstOrNull
        ?.role;
    final isCaptain = myRole == AppConstants.roleCaptain;
    final issued = _invitationSquadId == squad.id ? _invitation : null;
    final invitationLink = issued == null ? null : _linkFor(issued.linkToken);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: squad.name,
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: '加入小队',
                onPressed: _busy ? null : _join,
                icon: const Icon(Icons.login_rounded),
              ),
              IconButton(
                tooltip: '创建小队',
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (squad.description?.isNotEmpty == true)
                    Text(squad.description!),
                  const SizedBox(height: 8),
                  Text(
                    members.when(
                      loading: () => '成员加载中',
                      error: (_, _) => '成员加载失败',
                      data: (list) =>
                          '${list.length}/${squad.maxMembers} 人 · ${list.length == 1 ? '待邀请' : '小队中'}',
                    ),
                  ),
                  if (isCaptain) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _issue(squad.id),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('生成邀请码和邀请链接'),
                    ),
                  ],
                  if (issued != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '本次邀请',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText('邀请码：${issued.code}'),
                    TextButton.icon(
                      onPressed: () => _copy(issued.code),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('复制邀请码'),
                    ),
                    if (invitationLink != null) ...[
                      SelectableText('邀请链接：$invitationLink'),
                      TextButton.icon(
                        onPressed: () => _copy(invitationLink),
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('复制邀请链接'),
                      ),
                    ] else
                      const Text('邀请链接域名未配置，暂时只能复制邀请码。'),
                  ],
                ],
              ),
            ),
          ),
        ),
        AppSection(
          title: '成员',
          child: members.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => OutlinedButton(
              onPressed: () => ref.invalidate(squadMembersProvider(squad.id)),
              child: const Text('成员加载失败，点击重试'),
            ),
            data: (list) => Card(
              child: Column(
                children: [
                  for (final member in list)
                    _MemberTile(
                      name: member.nickname ?? '队员',
                      role: member.role,
                      isMe: member.userId == currentUserId,
                      canManage:
                          isCaptain &&
                          member.userId != currentUserId &&
                          list.length > AppConstants.squadMinMembers,
                      onRemove: () => _remove(squad.id, member.userId),
                      onTransfer: isCaptain && member.userId != currentUserId
                          ? () => _transfer(squad.id, member.userId)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
        AppSection(
          title: '我的小队',
          child: Column(
            children: [
              for (final item in allSquads)
                Card(
                  child: ListTile(
                    title: Text(item.name),
                    trailing: Icon(
                      item.id == squad.id
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                    ),
                    onTap: () =>
                        ref.read(selectedSquadIdProvider.notifier).state =
                            item.id,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _linkFor(String token) {
    const base = String.fromEnvironment('INVITE_LINK_BASE_URL');
    if (base.isEmpty) return null;
    try {
      return InvitationCredential.linkFor(
        baseUrl: base,
        token: token,
      ).toString();
    } on FormatException {
      return null;
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showSnack(context, '已复制');
  }

  Future<void> _create() async {
    var name = '';
    var description = '';
    final values = await showDialog<(String, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建小队'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => name = value,
              decoration: const InputDecoration(labelText: '小队名称'),
              autofocus: true,
            ),
            TextField(
              onChanged: (value) => description = value,
              decoration: const InputDecoration(labelText: '描述（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final trimmedName = name.trim();
              if (!Validators.isValidSquadName(trimmedName)) {
                _showSnack(context, '小队名称需要 1-20 个字符');
                return;
              }
              Navigator.pop(dialogContext, (trimmedName, description.trim()));
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (!mounted || values == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(squadRepositoryProvider)
          .createSquad(
            name: values.$1,
            description: values.$2?.isEmpty == true ? null : values.$2,
          );
      if (!mounted) return;
      result.fold(
        (failure) => _showSnack(context, squadFailureMessage(failure)),
        (created) {
          ref.read(selectedSquadIdProvider.notifier).state = created.id;
          ref.invalidate(mySquadsProvider);
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    var credential = '';
    final input = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('加入小队'),
        content: TextField(
          onChanged: (value) => credential = value,
          decoration: const InputDecoration(labelText: '邀请码或邀请链接'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, credential.trim()),
            child: const Text('加入'),
          ),
        ],
      ),
    );
    if (!mounted || input == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(squadRepositoryProvider)
          .redeemInvitation(credential: input);
      if (!mounted) return;
      result.fold(
        (failure) => _showSnack(context, squadFailureMessage(failure)),
        (joined) {
          ref.read(selectedSquadIdProvider.notifier).state = joined.id;
          ref.invalidate(mySquadsProvider);
          ref.invalidate(squadMembersProvider(joined.id));
          _showSnack(context, '已加入小队');
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _issue(String squadId) async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(squadRepositoryProvider)
          .issueInvitation(squadId: squadId);
      if (!mounted) return;
      result.fold(
        (failure) => _showSnack(context, squadFailureMessage(failure)),
        (issued) => setState(() {
          _invitation = issued;
          _invitationSquadId = squadId;
        }),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String squadId, String userId) async {
    final result = await ref
        .read(squadRepositoryProvider)
        .removeMember(squadId: squadId, userId: userId);
    if (!mounted) return;
    result.fold(
      (failure) => _showSnack(context, squadFailureMessage(failure)),
      (_) => ref.invalidate(squadMembersProvider(squadId)),
    );
  }

  Future<void> _transfer(String squadId, String userId) async {
    final result = await ref
        .read(squadRepositoryProvider)
        .transferCaptain(squadId: squadId, newCaptainId: userId);
    if (!mounted) return;
    result.fold(
      (failure) => _showSnack(context, squadFailureMessage(failure)),
      (_) => ref.invalidate(squadMembersProvider(squadId)),
    );
  }
}
