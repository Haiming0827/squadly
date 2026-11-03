import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/current_user_provider.dart';
import '../../../../app/providers/plan_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../../shared/widgets/squad_avatar.dart';
import '../../../../shared/widgets/squad_empty_state.dart';
import '../../../plan/domain/entities/squad_plan.dart';
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
      return SquadEmptyState(
        onCreate: () => _showCreateDialog(context, store),
        onJoin: () => _showJoinDialog(context, store),
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquadAvatar(name: squad.name, avatar: squad.avatarUrl),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
  const RemoteSquadListScreen({
    this.onOpenConversation,
    this.onOpenPlans,
    this.socialFeedBuilder,
    this.onOpenPhotoWidget,
    super.key,
  });

  final ValueChanged<Squad>? onOpenConversation;
  final VoidCallback? onOpenPlans;
  final Widget Function(String squadId)? socialFeedBuilder;
  final ValueChanged<Squad>? onOpenPhotoWidget;

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
      loading: () => const Center(child: AppLoadingState(label: '正在加载小队…')),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: '小队加载失败',
              subtitle: '请检查网络连接后重试。',
            ),
            OutlinedButton(
              onPressed: () => ref.invalidate(mySquadsProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (squad) => squad == null
          ? _emptyState(context)
          : _squadDetails(context, squad, all.value ?? [squad]),
    );
  }

  Widget _emptyState(BuildContext context) =>
      SquadEmptyState(busy: _busy, onCreate: _create, onJoin: _join);

  Widget _squadDetails(
    BuildContext context,
    Squad squad,
    List<Squad> allSquads,
  ) {
    final members = ref.watch(squadMembersProvider(squad.id));
    final currentUserId = ref.watch(currentUserProvider).value?.id;
    final myRole = members.value
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
                  SquadAvatar(
                    name: squad.name,
                    avatar: squad.avatarUrl,
                    radius: 28,
                  ),
                  const SizedBox(height: 12),
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
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: AppLoadingState(label: '正在加载成员…'),
            ),
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
          title: '共同计划',
          trailing: TextButton(
            onPressed: widget.onOpenPlans,
            child: const Text('查看计划'),
          ),
          child: _sharedPlans(context, squad),
        ),
        if (widget.onOpenPhotoWidget != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('小队桌面组件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => widget.onOpenPhotoWidget!(squad),
            ),
          ),
        if (widget.socialFeedBuilder != null)
          widget.socialFeedBuilder!(squad.id),
        AppSection(
          title: '近期分享',
          trailing: TextButton(
            onPressed: widget.onOpenConversation == null
                ? null
                : () => widget.onOpenConversation!(squad),
            child: const Text('去会话'),
          ),
          child: _recentShares(context, squad),
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

  Widget _sharedPlans(BuildContext context, Squad squad) {
    final plans = ref.watch(squadPlansProvider(squad.id));
    final progress = ref.watch(squadPlanProgressProvider(squad.id));
    return plans.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoadingState(label: '正在加载计划…'),
      ),
      error: (_, _) => OutlinedButton(
        onPressed: () {
          ref.invalidate(squadPlansProvider(squad.id));
          ref.invalidate(squadPlanProgressProvider(squad.id));
        },
        child: const Text('计划加载失败，点击重试'),
      ),
      data: (allPlans) {
        final activePlans = allPlans
            .where(
              (plan) =>
                  plan.visibility == PlanVisibility.squad &&
                  plan.status == PlanStatus.active,
            )
            .take(3)
            .toList();
        if (activePlans.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Text('还没有进行中的共同计划'),
          );
        }
        return Card(
          child: Column(
            children: [
              for (final (index, plan) in activePlans.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 68),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.flag_outlined)),
                  title: Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: progress.when(
                    data: (counts) {
                      final item = counts[plan.id];
                      if (item == null || item.totalCount == 0) {
                        return const Text('暂无任务');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.completedCount}/${item.totalCount} 项任务已完成',
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: item.fraction,
                            minHeight: 4,
                          ),
                        ],
                      );
                    },
                    loading: () => const Text('进度加载中'),
                    error: (_, _) => TextButton(
                      onPressed: () =>
                          ref.invalidate(squadPlanProgressProvider(squad.id)),
                      child: const Text('进度加载失败，重试'),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onOpenPlans,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _recentShares(BuildContext context, Squad squad) {
    final shares = ref.watch(squadRecentSharesProvider(squad.id));
    return shares.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoadingState(label: '正在加载近期分享…'),
      ),
      error: (_, _) => OutlinedButton(
        onPressed: () => ref.invalidate(squadRecentSharesProvider(squad.id)),
        child: const Text('分享加载失败，点击重试'),
      ),
      data: (items) => items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Text('还没有小队分享'),
            )
          : Card(
              child: Column(
                children: [
                  for (final (index, share) in items.indexed) ...[
                    if (index > 0) const Divider(height: 1, indent: 68),
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.auto_awesome_outlined),
                      ),
                      title: Text(
                        share.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        share.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _recentShareTime(share.createdAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      onTap: widget.onOpenConversation == null
                          ? null
                          : () => widget.onOpenConversation!(squad),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _recentShareTime(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.month}/${local.day}';
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
