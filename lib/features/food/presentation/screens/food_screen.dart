import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../domain/entities/food_snapshot.dart';
import '../providers/food_provider.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(useDemoBackendProvider)) {
      return const CloudBaseFoodScreen();
    }
    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;
    if (squad == null) {
      return const EmptyState(icon: Icons.restaurant_outlined, title: '先加入小队');
    }

    final food = state.foodFor(squad.id);
    final caloriesBurned = state.currentUser == null
        ? 0
        : state.caloriesBurnedBy(state.currentUser!.id, DateTime.now());
    final topChoice = store.decideFood(squad.id);
    final calorieBalance = topChoice == null
        ? caloriesBurned
        : caloriesBurned - topChoice.caloriesEstimate;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '今日决策',
          child: Row(
            children: [
              MetricTile(
                label: '推荐',
                value: topChoice?.name ?? '待添加',
                icon: Icons.restaurant_menu_rounded,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '热量差',
                value: '${calorieBalance >= 0 ? '+' : ''}$calorieBalance kcal',
                icon: Icons.local_fire_department_outlined,
              ),
            ],
          ),
        ),
        AppSection(
          title: '美食候选',
          trailing: IconButton(
            tooltip: '新增美食',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showFoodDialog(context, store, squad.id),
          ),
          child: food.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_outlined,
                  title: '暂无美食候选',
                )
              : Column(
                  children: [
                    for (final item in food)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(item.score.toString()),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.category} · ¥${item.averageCost.toStringAsFixed(0)} · ${item.caloriesEstimate} kcal',
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: '想吃',
                                icon: const Icon(Icons.thumb_up_outlined),
                                onPressed: () => store.voteFoodSpot(
                                  foodSpotId: item.id,
                                  delta: 1,
                                ),
                              ),
                              IconButton(
                                tooltip: '不想吃',
                                icon: const Icon(Icons.thumb_down_outlined),
                                onPressed: () => store.voteFoodSpot(
                                  foodSpotId: item.id,
                                  delta: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showFoodDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final nameController = TextEditingController();
    final costController = TextEditingController(text: '50');
    final caloriesController = TextEditingController(text: '500');
    final addressController = TextEditingController();
    var category = '简餐';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增美食'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: '简餐', child: Text('简餐')),
                  DropdownMenuItem(value: '正餐', child: Text('正餐')),
                  DropdownMenuItem(value: '轻食', child: Text('轻食')),
                  DropdownMenuItem(value: '咖啡', child: Text('咖啡')),
                ],
                onChanged: (value) =>
                    setState(() => category = value ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: const InputDecoration(labelText: '人均'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: '估算热量'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: '地址'),
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
                if (nameController.text.trim().isEmpty) return;
                store.addFoodSpot(
                  squadId: squadId,
                  name: nameController.text,
                  category: category,
                  averageCost: double.tryParse(costController.text) ?? 0,
                  caloriesEstimate: int.tryParse(caloriesController.text) ?? 0,
                  address: addressController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    costController.dispose();
    caloriesController.dispose();
    addressController.dispose();
  }
}

final class CloudBaseFoodScreen extends ConsumerWidget {
  const CloudBaseFoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(currentSquadProvider);
    return squadState.when(
      loading: () => const Center(child: AppLoadingState(label: '正在加载小队…')),
      error: (error, _) => _foodError(error),
      data: (squad) {
        if (squad == null) {
          return const EmptyState(
            icon: Icons.restaurant_outlined,
            title: '先加入小队',
          );
        }
        final state = ref.watch(foodSnapshotProvider(squad.id));
        return state.when(
          loading: () =>
              const Center(child: AppLoadingState(label: '正在加载美食数据…')),
          error: (error, _) => _foodError(error),
          data: (snapshot) => _content(context, ref, squad.id, snapshot),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    String squadId,
    FoodSnapshot snapshot,
  ) {
    final topChoice = snapshot.recommended;
    final calorieBalance = topChoice == null
        ? snapshot.caloriesBurned
        : snapshot.caloriesBurned - topChoice.caloriesEstimate;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '今日决策',
          child: Row(
            children: [
              MetricTile(
                label: '推荐',
                value: topChoice?.name ?? '待添加',
                icon: Icons.restaurant_menu_rounded,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '热量差',
                value: '${calorieBalance >= 0 ? '+' : ''}$calorieBalance kcal',
                icon: Icons.local_fire_department_outlined,
              ),
            ],
          ),
        ),
        AppSection(
          title: '美食候选',
          trailing: IconButton(
            tooltip: '新增美食',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _addSpot(context, ref, squadId),
          ),
          child: snapshot.spots.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_outlined,
                  title: '暂无美食候选',
                )
              : Column(
                  children: [
                    for (final spot in snapshot.spots)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${spot.score}')),
                          title: Text(spot.name),
                          subtitle: Text(
                            '${spot.category} · ¥${spot.averageCost.toStringAsFixed(0)} · ${spot.caloriesEstimate} kcal',
                          ),
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                tooltip: '想吃',
                                icon: const Icon(Icons.thumb_up_outlined),
                                onPressed: () =>
                                    _vote(context, ref, squadId, spot.id, 1),
                              ),
                              IconButton(
                                tooltip: '不想吃',
                                icon: const Icon(Icons.thumb_down_outlined),
                                onPressed: () =>
                                    _vote(context, ref, squadId, spot.id, -1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addSpot(
    BuildContext context,
    WidgetRef ref,
    String squadId,
  ) async {
    final name = TextEditingController();
    final cost = TextEditingController(text: '50');
    final calories = TextEditingController(text: '500');
    final address = TextEditingController();
    var category = '简餐';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增美食'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                TextField(
                  controller: cost,
                  decoration: const InputDecoration(labelText: '人均'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: calories,
                  decoration: const InputDecoration(labelText: '估算热量'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: '地址'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const [
                    DropdownMenuItem(value: '简餐', child: Text('简餐')),
                    DropdownMenuItem(value: '正餐', child: Text('正餐')),
                    DropdownMenuItem(value: '轻食', child: Text('轻食')),
                    DropdownMenuItem(value: '咖啡', child: Text('咖啡')),
                  ],
                  onChanged: (value) =>
                      setState(() => category = value ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      if (!context.mounted) return;
      final result = await ref
          .read(foodRepositoryProvider)
          .addFoodSpot(
            squadId: squadId,
            name: name.text,
            category: category,
            averageCost: double.tryParse(cost.text) ?? 0,
            caloriesEstimate: int.tryParse(calories.text) ?? 0,
            address: address.text,
          );
      if (!context.mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_foodFailureMessage(failure)))),
        (_) => ref.invalidate(foodSnapshotProvider(squadId)),
      );
    }
    name.dispose();
    cost.dispose();
    calories.dispose();
    address.dispose();
  }

  Future<void> _vote(
    BuildContext context,
    WidgetRef ref,
    String squadId,
    String spotId,
    int vote,
  ) async {
    final result = await ref
        .read(foodRepositoryProvider)
        .voteFoodSpot(foodSpotId: spotId, vote: vote);
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_foodFailureMessage(failure)))),
      (_) => ref.invalidate(foodSnapshotProvider(squadId)),
    );
  }
}

String _foodFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有操作权限',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '操作失败，请稍后重试',
};

Widget _foodError(Object error) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text('美食数据加载失败：$error', textAlign: TextAlign.center),
  ),
);
