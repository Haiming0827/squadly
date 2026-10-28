import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../app/providers/squad_context_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/cloudbase_client_provider.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_section.dart';
import '../providers/finance_provider.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(useDemoBackendProvider)) {
      return const CloudBaseFinanceScreen();
    }
    final state = ref.watch(demoAppStoreProvider);
    final store = ref.read(demoAppStoreProvider.notifier);
    final squad = state.currentSquad;
    if (squad == null) {
      return const EmptyState(icon: Icons.savings_outlined, title: '先加入小队');
    }

    final funds = state.fundsFor(squad.id);
    final expenses = state.expensesFor(squad.id);
    final privateTotal = state.myPrivateAssets.fold<double>(
      0,
      (sum, asset) => sum + asset.amount,
    );
    final publicTotal = funds.fold<double>(
      0,
      (sum, fund) => sum + fund.currentAmount,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '资金概览',
          child: Row(
            children: [
              MetricTile(
                label: '公共基金',
                value: _money(publicTotal),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '我的私密资产',
                value: _money(privateTotal),
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
        AppSection(
          title: '公共基金',
          trailing: state.isCaptain
              ? IconButton(
                  tooltip: '创建基金',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _showFundDialog(context, store, squad.id),
                )
              : null,
          child: funds.isEmpty
              ? const EmptyState(icon: Icons.savings_outlined, title: '暂无基金')
              : Column(
                  children: [
                    for (final fund in funds)
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
                                  Expanded(
                                    child: Text(
                                      fund.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(_fundTypeLabel(fund.fundType)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: fund.targetAmount <= 0
                                    ? 0
                                    : (fund.currentAmount / fund.targetAmount)
                                          .clamp(0, 1),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_money(fund.currentAmount)} / ${_money(fund.targetAmount)}',
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _showTransactionDialog(
                                      context,
                                      store,
                                      fund.id,
                                    ),
                                    icon: const Icon(Icons.swap_vert_rounded),
                                    label: const Text('记一笔'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        AppSection(
          title: '个人私密资产',
          trailing: IconButton(
            tooltip: '新增资产',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAssetDialog(context, store),
          ),
          child: state.myPrivateAssets.isEmpty
              ? const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: '暂无资产',
                )
              : Column(
                  children: [
                    for (final asset in state.myPrivateAssets)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: Text(asset.name),
                          subtitle: Text(_assetTypeLabel(asset.assetType)),
                          trailing: Text(_money(asset.amount)),
                        ),
                      ),
                  ],
                ),
        ),
        AppSection(
          title: '集体记账',
          trailing: IconButton(
            tooltip: '记录支出',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showExpenseDialog(context, store, squad.id),
          ),
          child: expenses.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '暂无共享支出',
                )
              : Column(
                  children: [
                    for (final expense in expenses.reversed)
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(expense.description ?? '共享支出'),
                          subtitle: Text(
                            '${_expenseCategoryLabel(expense.category)} · ${expense.paidByNickname ?? '成员'}',
                          ),
                          trailing: Text(_money(expense.amount)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _showFundDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    var target = '1000';
    var fundType = 'travel';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建公共基金'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '基金名称'),
                  autofocus: true,
                  onSaved: (value) => name = value ?? '',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入基金名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: fundType,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'travel', child: Text('旅行')),
                    DropdownMenuItem(value: 'dining', child: Text('聚餐')),
                    DropdownMenuItem(value: 'team_building', child: Text('团建')),
                    DropdownMenuItem(value: 'custom', child: Text('自定义')),
                  ],
                  onChanged: (value) =>
                      setState(() => fundType = value ?? fundType),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: '目标金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _validateNonNegativeAmount,
                  onSaved: (value) => target = value ?? '',
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                store.createFund(
                  squadId: squadId,
                  name: name,
                  fundType: fundType,
                  targetAmount: double.parse(target),
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransactionDialog(
    BuildContext context,
    DemoAppStore store,
    String fundId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var amount = '100';
    var description = '';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('基金流水'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: amount,
                decoration: const InputDecoration(labelText: '金额（支出填负数）'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                autofocus: true,
                validator: _validateNonZeroAmount,
                onSaved: (value) => amount = value ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: '说明'),
                onSaved: (value) => description = value ?? '',
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
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              store.addFundTransaction(
                fundId: fundId,
                amount: double.parse(amount),
                description: description,
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssetDialog(
    BuildContext context,
    DemoAppStore store,
  ) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    var amount = '1000';
    var assetType = 'savings';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增私密资产'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '资产名称'),
                  autofocus: true,
                  onSaved: (value) => name = value ?? '',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入资产名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: assetType,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const [
                    DropdownMenuItem(value: 'savings', child: Text('存款')),
                    DropdownMenuItem(value: 'stock', child: Text('股票')),
                    DropdownMenuItem(value: 'fund', child: Text('基金')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
                  ],
                  onChanged: (value) =>
                      setState(() => assetType = value ?? assetType),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: amount,
                  decoration: const InputDecoration(labelText: '金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _validateNonNegativeAmount,
                  onSaved: (value) => amount = value ?? '',
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                store.createPrivateAsset(
                  assetType: assetType,
                  name: name,
                  amount: double.parse(amount),
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var amount = '80';
    var description = '';
    var category = 'dining';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('记录共享支出'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: amount,
                  decoration: const InputDecoration(labelText: '金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  autofocus: true,
                  validator: _validatePositiveAmount,
                  onSaved: (value) => amount = value ?? '',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: const [
                    DropdownMenuItem(value: 'dining', child: Text('餐饮')),
                    DropdownMenuItem(value: 'transport', child: Text('交通')),
                    DropdownMenuItem(value: 'entertainment', child: Text('娱乐')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
                  ],
                  onChanged: (value) =>
                      setState(() => category = value ?? category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  decoration: const InputDecoration(labelText: '说明'),
                  onSaved: (value) => description = value ?? '',
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                store.recordSharedExpense(
                  squadId: squadId,
                  amount: double.parse(amount),
                  category: category,
                  description: description,
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Finance UI for the real CloudBase backend.
final class CloudBaseFinanceScreen extends ConsumerWidget {
  const CloudBaseFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadState = ref.watch(currentSquadProvider);
    return squadState.when(
      loading: () => const Center(child: AppLoadingState(label: '正在加载小队…')),
      error: (_, _) => _financeError(
        context,
        onRetry: () => ref.invalidate(mySquadsProvider),
      ),
      data: (squad) {
        if (squad == null) {
          return const EmptyState(icon: Icons.savings_outlined, title: '先加入小队');
        }
        final snapshot = ref.watch(financeSnapshotProvider(squad.id));
        return snapshot.when(
          loading: () =>
              const Center(child: AppLoadingState(label: '正在加载理财数据…')),
          error: (_, _) => _financeError(
            context,
            onRetry: () => ref.invalidate(financeSnapshotProvider(squad.id)),
          ),
          data: (data) => _content(context, ref, squad.id, data),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    String squadId,
    FinanceSnapshot data,
  ) {
    final publicTotal = data.funds.fold<double>(
      0,
      (sum, fund) => sum + fund.currentAmount,
    );
    final privateTotal = data.privateAssets.fold<double>(
      0,
      (sum, asset) => sum + asset.amount,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AppSection(
          title: '资金概览',
          child: Row(
            children: [
              MetricTile(
                label: '公共基金',
                value: _money(publicTotal),
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(width: 10),
              MetricTile(
                label: '我的私密资产',
                value: _money(privateTotal),
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
        AppSection(
          title: '公共基金',
          trailing: ref.watch(canManagePublicFundsProvider(squadId))
              ? IconButton(
                  tooltip: '创建基金',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _createFund(context, ref, squadId),
                )
              : null,
          child: data.funds.isEmpty
              ? const EmptyState(icon: Icons.savings_outlined, title: '暂无基金')
              : Column(
                  children: [
                    for (final fund in data.funds)
                      Card(
                        child: ListTile(
                          title: Text(fund.name),
                          subtitle: Text(
                            '${_fundTypeLabel(fund.fundType)} · 目标 ${_money(fund.targetAmount)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_money(fund.currentAmount)),
                              IconButton(
                                tooltip: '记一笔',
                                icon: const Icon(Icons.swap_vert_rounded),
                                onPressed: () =>
                                    _addTransaction(context, ref, fund.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        AppSection(
          title: '个人私密资产',
          trailing: IconButton(
            tooltip: '新增资产',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _createAsset(context, ref),
          ),
          child: data.privateAssets.isEmpty
              ? const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: '暂无资产',
                )
              : Column(
                  children: [
                    for (final asset in data.privateAssets)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: Text(asset.name),
                          subtitle: Text(_assetTypeLabel(asset.assetType)),
                          trailing: Text(_money(asset.amount)),
                        ),
                      ),
                  ],
                ),
        ),
        AppSection(
          title: '集体记账',
          trailing: IconButton(
            tooltip: '记录支出',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _createExpense(context, ref, squadId),
          ),
          child: data.expenses.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '暂无共享支出',
                )
              : Column(
                  children: [
                    for (final expense in data.expenses)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(expense.description ?? '共享支出'),
                          subtitle: Text(
                            _expenseCategoryLabel(expense.category),
                          ),
                          trailing: Text(_money(expense.amount)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _createFund(
    BuildContext context,
    WidgetRef ref,
    String squadId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    var target = '1000';
    var type = 'travel';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建公共基金'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '基金名称'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入基金名称' : null,
                  onSaved: (value) => name = value ?? '',
                ),
                TextFormField(
                  initialValue: target,
                  decoration: const InputDecoration(labelText: '目标金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateNonNegativeAmount,
                  onSaved: (value) => target = value ?? '',
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'travel', child: Text('旅行')),
                    DropdownMenuItem(value: 'dining', child: Text('聚餐')),
                    DropdownMenuItem(value: 'team_building', child: Text('团建')),
                    DropdownMenuItem(value: 'custom', child: Text('自定义')),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                Navigator.pop(context, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && name.trim().isNotEmpty) {
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        squadId,
        ref
            .read(financeRepositoryProvider)
            .createFund(
              squadId: squadId,
              name: name,
              fundType: type,
              targetAmount: double.parse(target),
            ),
      );
    }
  }

  Future<void> _addTransaction(
    BuildContext context,
    WidgetRef ref,
    String fundId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var amount = '100';
    var description = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('基金流水'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: amount,
                decoration: const InputDecoration(labelText: '金额（支出填负数）'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: _validateNonZeroAmount,
                onSaved: (value) => amount = value ?? '',
              ),
              TextFormField(
                initialValue: description,
                decoration: const InputDecoration(labelText: '说明'),
                onSaved: (value) => description = value ?? '',
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
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        null,
        ref
            .read(financeRepositoryProvider)
            .addFundTransaction(
              fundId: fundId,
              amount: double.parse(amount),
              description: description,
            ),
      );
    }
  }

  Future<void> _createAsset(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    var name = '';
    var amount = '1000';
    var type = 'savings';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增私密资产'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '资产名称'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入资产名称' : null,
                  onSaved: (value) => name = value ?? '',
                ),
                TextFormField(
                  initialValue: amount,
                  decoration: const InputDecoration(labelText: '金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateNonNegativeAmount,
                  onSaved: (value) => amount = value ?? '',
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'savings', child: Text('存款')),
                    DropdownMenuItem(value: 'stock', child: Text('股票')),
                    DropdownMenuItem(value: 'fund', child: Text('基金')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
                  ],
                  onChanged: (value) => setState(() => type = value ?? type),
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                Navigator.pop(context, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && name.trim().isNotEmpty) {
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        null,
        ref
            .read(financeRepositoryProvider)
            .createPrivateAsset(
              assetType: type,
              name: name,
              amount: double.parse(amount),
            ),
      );
    }
  }

  Future<void> _createExpense(
    BuildContext context,
    WidgetRef ref,
    String squadId,
  ) async {
    final formKey = GlobalKey<FormState>();
    var amount = '80';
    var description = '';
    var category = 'dining';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('记录共享支出'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: amount,
                  decoration: const InputDecoration(labelText: '金额'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validatePositiveAmount,
                  onSaved: (value) => amount = value ?? '',
                ),
                TextFormField(
                  initialValue: description,
                  decoration: const InputDecoration(labelText: '说明'),
                  onSaved: (value) => description = value ?? '',
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  items: const [
                    DropdownMenuItem(value: 'dining', child: Text('餐饮')),
                    DropdownMenuItem(value: 'transport', child: Text('交通')),
                    DropdownMenuItem(value: 'entertainment', child: Text('娱乐')),
                    DropdownMenuItem(value: 'other', child: Text('其他')),
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                formKey.currentState!.save();
                Navigator.pop(context, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      if (!context.mounted) return;
      await _save(
        context,
        ref,
        squadId,
        ref
            .read(financeRepositoryProvider)
            .recordSharedExpense(
              squadId: squadId,
              amount: double.parse(amount),
              category: category,
              description: description,
            ),
      );
    }
  }

  Future<void> _save<T>(
    BuildContext context,
    WidgetRef ref,
    String? squadId,
    Future<Either<Failure, T>> operation,
  ) async {
    final result = await operation;
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(financeFailureMessage(failure)))),
      (_) {
        if (squadId != null) {
          ref.invalidate(financeSnapshotProvider(squadId));
        } else {
          final squad = ref.read(currentSquadProvider).value;
          if (squad != null) ref.invalidate(financeSnapshotProvider(squad.id));
        }
      },
    );
  }
}

Widget _financeError(BuildContext context, {required VoidCallback onRetry}) =>
    Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('理财数据暂时无法加载'),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );

double? _parseFiniteAmount(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final amount = double.tryParse(value.trim());
  return amount != null && amount.isFinite ? amount : null;
}

String? _validateNonNegativeAmount(String? value) {
  final amount = _parseFiniteAmount(value);
  if (amount == null) return '请输入有效金额';
  if (amount < 0) return '金额不能小于 0';
  return null;
}

String? _validatePositiveAmount(String? value) {
  final amount = _parseFiniteAmount(value);
  if (amount == null) return '请输入有效金额';
  if (amount <= 0) return '金额需大于 0';
  return null;
}

String? _validateNonZeroAmount(String? value) {
  final amount = _parseFiniteAmount(value);
  if (amount == null) return '请输入有效金额';
  if (amount == 0) return '金额不能为 0';
  return null;
}

String _money(double value) => '¥${value.toStringAsFixed(0)}';

String _fundTypeLabel(String value) {
  return switch (value) {
    'travel' => '旅行',
    'dining' => '聚餐',
    'team_building' => '团建',
    _ => '自定义',
  };
}

String _assetTypeLabel(String value) {
  return switch (value) {
    'savings' => '存款',
    'stock' => '股票',
    'fund' => '基金',
    _ => '其他',
  };
}

String _expenseCategoryLabel(String value) {
  return switch (value) {
    'dining' => '餐饮',
    'transport' => '交通',
    'entertainment' => '娱乐',
    _ => '其他',
  };
}
