import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../fitness/presentation/screens/fitness_screen.dart';
import '../../../food/presentation/screens/food_screen.dart';
import '../../../squad/presentation/screens/squad_list_screen.dart';
import '../../../travel/presentation/screens/travel_screen.dart';

/// Keeps the existing squad activities within reach from the new social shell.
class PlanHubScreen extends ConsumerWidget {
  const PlanHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoAppStoreProvider);
    final squad = state.currentSquad;
    final memberCount = squad == null ? 0 : state.membersFor(squad.id).length;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '一起做点什么',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  squad == null ? '先创建或加入小队，再把喜欢的事安排起来。' : '每个好点子，都有伙伴一起完成。',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () =>
                        _open(context, '我的小队', const SquadListScreen()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: colors.surfaceContainerHigh,
                            foregroundColor: colors.onSurface,
                            child: const Icon(Icons.groups_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  squad?.name ?? '还没有小队',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  squad == null
                                      ? '创建或加入一个小队'
                                      : '$memberCount 位成员 · 查看成员与小队',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('你们的计划', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                _PlanEntry(
                  icon: Icons.directions_run_rounded,
                  title: '健身',
                  subtitle: '打卡、训练计划，看看大家动起来了没',
                  onTap: () => _open(context, '健身', const FitnessScreen()),
                ),
                const Divider(height: 1),
                _PlanEntry(
                  icon: Icons.savings_outlined,
                  title: '理财',
                  subtitle: '管理小队公共基金和自己的私密资产',
                  onTap: () => _open(context, '理财', const FinanceScreen()),
                ),
                const Divider(height: 1),
                _PlanEntry(
                  icon: Icons.map_outlined,
                  title: '旅行',
                  subtitle: '一起准备下一段旅程',
                  onTap: () => _open(context, '旅行', const TravelScreen()),
                ),
                const Divider(height: 1),
                _PlanEntry(
                  icon: Icons.restaurant_outlined,
                  title: '美食',
                  subtitle: '收藏想吃的地方，投票决定下一餐',
                  onTap: () => _open(context, '美食', const FoodScreen()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, String title, Widget content) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: content,
        ),
      ),
    );
  }
}

class _PlanEntry extends StatelessWidget {
  const _PlanEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: colors.onSurface),
      ),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
