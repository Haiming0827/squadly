import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/demo/demo_store.dart';
import '../../../../shared/widgets/app_section.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          trailing: IconButton(
            tooltip: '创建基金',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showFundDialog(context, store, squad.id),
          ),
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
    final nameController = TextEditingController();
    final targetController = TextEditingController(text: '1000');
    var fundType = 'travel';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建公共基金'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '基金名称'),
                autofocus: true,
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
              TextField(
                controller: targetController,
                decoration: const InputDecoration(labelText: '目标金额'),
                keyboardType: TextInputType.number,
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
                store.createFund(
                  squadId: squadId,
                  name: nameController.text,
                  fundType: fundType,
                  targetAmount: double.tryParse(targetController.text) ?? 0,
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
    targetController.dispose();
  }

  Future<void> _showTransactionDialog(
    BuildContext context,
    DemoAppStore store,
    String fundId,
  ) async {
    final amountController = TextEditingController(text: '100');
    final descriptionController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('基金流水'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: '金额（支出填负数）'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: '说明'),
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
              store.addFundTransaction(
                fundId: fundId,
                amount: double.tryParse(amountController.text) ?? 0,
                description: descriptionController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    amountController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showAssetDialog(
    BuildContext context,
    DemoAppStore store,
  ) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '1000');
    var assetType = 'savings';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('新增私密资产'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '资产名称'),
                autofocus: true,
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
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: '金额'),
                keyboardType: TextInputType.number,
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
                store.createPrivateAsset(
                  assetType: assetType,
                  name: nameController.text,
                  amount: double.tryParse(amountController.text) ?? 0,
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
    amountController.dispose();
  }

  Future<void> _showExpenseDialog(
    BuildContext context,
    DemoAppStore store,
    String squadId,
  ) async {
    final amountController = TextEditingController(text: '80');
    final descriptionController = TextEditingController();
    var category = 'dining';
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('记录共享支出'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: '金额'),
                keyboardType: TextInputType.number,
                autofocus: true,
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
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: '说明'),
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
                store.recordSharedExpense(
                  squadId: squadId,
                  amount: double.tryParse(amountController.text) ?? 0,
                  category: category,
                  description: descriptionController.text,
                );
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    descriptionController.dispose();
  }
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
