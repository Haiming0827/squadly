import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_section.dart';
import '../../../finance/domain/entities/public_fund.dart';
import '../providers/travel_provider.dart';

class TravelScreen extends ConsumerWidget {
  const TravelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(useDemoBackendProvider)) {
      return const CloudBaseTravelScreen();
    }
    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;
    if (squad == null) {
      return const EmptyState(icon: Icons.map_outlined, title: '先加入小队');
    }

    final plans = state.plansFor(squad.id);
    final travelFunds = state
        .fundsFor(squad.id)
        .where((fund) => fund.fundType == 'travel')
        .toList();
    final totalBudget = plans.fold<double>(0, (sum, plan) => sum + plan.budget);
    final totalFund = travelFunds.fold<double>(
      0,
      (sum, fund) => sum + fund.currentAmount,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '旅行预算',
          child: Row(
            children: [
              MetricTile(
                label: '旅行基金',
                value: _money(totalFund),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '计划预算',
                value: _money(totalBudget),
                icon: Icons.flight_takeoff_rounded,
              ),
            ],
          ),
        ),
        AppSection(
          title: '心愿行程',
          trailing: IconButton(
            tooltip: '新增行程',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showTravelDialog(context, store, squad.id),
          ),
          child: plans.isEmpty
              ? const EmptyState(icon: Icons.map_outlined, title: '暂无行程')
              : Column(
                  children: [
                    for (final plan in plans)
                      Card(
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
                                  const Icon(Icons.place_outlined),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      plan.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(_money(plan.budget)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${plan.destination} · ${_date(plan.startDate)} - ${_date(plan.endDate)}',
                              ),
                              if (plan.notes != null) ...[
                                const SizedBox(height: 6),
                                Text(plan.notes!),
                              ],
                              const SizedBox(height: 12),
                              _BudgetLink(
                                fundName: state.publicFunds
                                    .where(
                                      (fund) => fund.id == plan.linkedFundId,
                                    )
                                    .map((fund) => fund.name)
                                    .firstOrNull,
                                fundBalance: plan.linkedFundId == null
                                    ? 0
                                    : state.fundBalance(plan.linkedFundId!),
                                budget: plan.budget,
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

  Future<void> _showTravelDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final titleController = TextEditingController();
    final destinationController = TextEditingController();
    final budgetController = TextEditingController(text: '3000');
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增行程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(labelText: '目的地'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              decoration: const InputDecoration(labelText: '预算'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: '备注'),
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
              if (titleController.text.trim().isEmpty ||
                  destinationController.text.trim().isEmpty) {
                return;
              }
              store.createTravelPlan(
                squadId: squadId,
                title: titleController.text,
                destination: destinationController.text,
                budget: double.tryParse(budgetController.text) ?? 0,
                notes: noteController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    titleController.dispose();
    destinationController.dispose();
    budgetController.dispose();
    noteController.dispose();
  }
}

final class CloudBaseTravelScreen extends ConsumerWidget {
  const CloudBaseTravelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(currentSquadProvider);
    return squadState.when(
      loading: () => const Center(child: AppLoadingState(label: '正在加载小队…')),
      error: (error, _) => _travelError(error),
      data: (squad) {
        if (squad == null) {
          return const EmptyState(icon: Icons.map_outlined, title: '先加入小队');
        }
        final state = ref.watch(travelSnapshotProvider(squad.id));
        return state.when(
          loading: () =>
              const Center(child: AppLoadingState(label: '正在加载旅行数据…')),
          error: (error, _) => _travelError(error),
          data: (snapshot) {
            final plans = snapshot.plans;
            final funds = snapshot.funds
                .where((fund) => fund.fundType == 'travel')
                .toList();
            final totalBudget = plans.fold<double>(
              0,
              (sum, plan) => sum + plan.budget,
            );
            final totalFund = funds.fold<double>(
              0,
              (sum, fund) => sum + fund.currentAmount,
            );
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                AppSection(
                  title: '旅行预算',
                  child: Row(
                    children: [
                      MetricTile(
                        label: '旅行基金',
                        value: _money(totalFund),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(width: 10),
                      MetricTile(
                        label: '计划预算',
                        value: _money(totalBudget),
                        icon: Icons.flight_takeoff_rounded,
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: '心愿行程',
                  trailing: IconButton(
                    tooltip: '新增行程',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _createPlan(context, ref, squad.id, funds),
                  ),
                  child: plans.isEmpty
                      ? const EmptyState(
                          icon: Icons.map_outlined,
                          title: '暂无行程',
                        )
                      : Column(
                          children: [
                            for (final plan in plans)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.place_outlined),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              plan.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(_money(plan.budget)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${plan.destination} · ${_date(plan.startDate)} - ${_date(plan.endDate)}',
                                      ),
                                      if (plan.notes != null) ...[
                                        const SizedBox(height: 6),
                                        Text(plan.notes!),
                                      ],
                                      const SizedBox(height: 12),
                                      _BudgetLink(
                                        fundName: snapshot.funds
                                            .where(
                                              (fund) =>
                                                  fund.id == plan.linkedFundId,
                                            )
                                            .map((fund) => fund.name)
                                            .firstOrNull,
                                        fundBalance:
                                            snapshot.funds
                                                .where(
                                                  (fund) =>
                                                      fund.id ==
                                                      plan.linkedFundId,
                                                )
                                                .map(
                                                  (fund) => fund.currentAmount,
                                                )
                                                .firstOrNull ??
                                            0,
                                        budget: plan.budget,
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
          },
        );
      },
    );
  }

  Future<void> _createPlan(
    BuildContext context,
    WidgetRef ref,
    String squadId,
    List<PublicFund> funds,
  ) async {
    final title = TextEditingController();
    final destination = TextEditingController();
    final budget = TextEditingController(text: '3000');
    final notes = TextEditingController();
    String? linkedFundId;
    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 30));
    final endDate = startDate.add(const Duration(days: 4));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增行程'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: destination,
                  decoration: const InputDecoration(labelText: '目的地'),
                ),
                TextField(
                  controller: budget,
                  decoration: const InputDecoration(labelText: '预算'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: null,
                  decoration: const InputDecoration(labelText: '关联旅行基金'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('不关联'),
                    ),
                    for (final fund in funds)
                      DropdownMenuItem<String?>(
                        value: fund.id,
                        child: Text(fund.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => linkedFundId = value),
                ),
                const SizedBox(height: 8),
                Text('日期：${_date(startDate)} - ${_date(endDate)}'),
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
    if (accepted == true &&
        title.text.trim().isNotEmpty &&
        destination.text.trim().isNotEmpty) {
      if (!context.mounted) return;
      final result = await ref
          .read(travelRepositoryProvider)
          .createTravelPlan(
            squadId: squadId,
            title: title.text,
            destination: destination.text,
            startDate: startDate,
            endDate: endDate,
            budget: double.tryParse(budget.text) ?? 0,
            linkedFundId: linkedFundId,
            notes: notes.text,
          );
      if (!context.mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_travelFailureMessage(failure)))),
        (_) => ref.invalidate(travelSnapshotProvider(squadId)),
      );
    }
    title.dispose();
    destination.dispose();
    budget.dispose();
    notes.dispose();
  }
}

String _travelFailureMessage(Failure failure) => switch (failure) {
  ServerFailure(:final message) => message,
  ValidationFailure(:final message) => message,
  UnauthorizedFailure() => '请先登录',
  PermissionDeniedFailure() => '没有操作权限',
  NetworkFailure() => '网络连接失败，请稍后重试',
  _ => '行程保存失败，请稍后重试',
};

Widget _travelError(Object error) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text('旅行数据加载失败：$error', textAlign: TextAlign.center),
  ),
);

class _BudgetLink extends StatelessWidget {
  const _BudgetLink({
    required this.fundName,
    required this.fundBalance,
    required this.budget,
  });

  final String? fundName;
  final double fundBalance;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = budget <= 0 ? 0.0 : (fundBalance / budget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fundName == null ? '未关联旅行基金' : '关联基金：$fundName'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: ratio),
          const SizedBox(height: 6),
          Text('${_money(fundBalance)} / ${_money(budget)}'),
        ],
      ),
    );
  }
}

String _date(DateTime value) => DateFormat('MM/dd').format(value);

String _money(double value) => '¥${value.toStringAsFixed(0)}';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
