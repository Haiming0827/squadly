import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_section.dart';

class SquadListScreen extends ConsumerWidget {
  const SquadListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;

    if (squad == null) {
      return const EmptyState(
        icon: Icons.group_add_outlined,
        title: '还没有小队',
        subtitle: '创建或加入一个小队后，其他模块会自动围绕该小队展开。',
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
