import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../finance/presentation/screens/finance_screen.dart';
import '../../../fitness/presentation/screens/fitness_screen.dart';
import '../../../food/presentation/screens/food_screen.dart';
import '../../../squad/presentation/screens/squad_list_screen.dart';
import '../../../travel/presentation/screens/travel_screen.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoAppStoreProvider);
    final squad = state.currentSquad;
    final tabs = [
      const SquadListScreen(),
      const FitnessScreen(),
      const FinanceScreen(),
      const TravelScreen(),
      const FoodScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(squad?.name ?? AppConstants.appName),
        leading: const Icon(Icons.groups_rounded),
        actions: [
          if (state.mySquads.length > 1)
            PopupMenuButton<String>(
              tooltip: '切换小队',
              icon: const Icon(Icons.swap_horiz_rounded),
              onSelected: (id) {
                ref.read(demoAppStoreProvider.notifier).selectSquad(id);
              },
              itemBuilder: (context) => [
                for (final item in state.mySquads)
                  PopupMenuItem(
                    value: item.id,
                    child: Row(
                      children: [
                        if (item.id == squad?.id)
                          const Icon(Icons.check_rounded, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.name)),
                      ],
                    ),
                  ),
              ],
            ),
          PopupMenuButton<String>(
            tooltip: '账号',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'signOut') {
                ref.read(authNotifierProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(state.currentUser?.nickname ?? '未登录'),
              ),
              const PopupMenuItem(
                value: 'signOut',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('退出登录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: KeyedSubtree(key: ValueKey(_index), child: tabs[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: '小队',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: '健身',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: '理财',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: '旅行',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: '美食',
          ),
        ],
      ),
    );
  }
}
