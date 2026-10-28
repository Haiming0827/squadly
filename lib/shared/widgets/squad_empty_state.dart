import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_section.dart';

/// The onboarding state shared by demo and CloudBase Squad entry points.
/// Preview rows describe real product capabilities; they are not sample data.
class SquadEmptyState extends StatelessWidget {
  const SquadEmptyState({
    required this.onCreate,
    required this.onJoin,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onCreate;
  final VoidCallback? onJoin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EmptyState(
                  icon: Icons.group_add_outlined,
                  title: '还没有小队',
                  subtitle: '创建一个小队，或通过朋友的邀请加入。',
                ),
                FilledButton(
                  onPressed: busy ? null : onCreate,
                  child: const Text('创建小队'),
                ),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  onPressed: busy ? null : onJoin,
                  child: const Text('输入邀请码加入'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('加入后可以', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                _SquadCapabilityRow(
                  icon: Icons.checklist_rounded,
                  title: '一起制定计划',
                  subtitle: '安排健身、旅行和聚餐等共同目标',
                  color: colors.primary,
                ),
                _SquadCapabilityRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '在小队内沟通和分享',
                  subtitle: '发布到小队的内容仅对当前成员开放',
                  color: colors.primary,
                ),
                _SquadCapabilityRow(
                  icon: Icons.lock_outline_rounded,
                  title: '保留个人隐私',
                  subtitle: '个人健康记录和资产由你掌控',
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquadCapabilityRow extends StatelessWidget {
  const _SquadCapabilityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: false,
    ),
  );
}
