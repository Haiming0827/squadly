import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/app/providers/squad_context_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/finance/domain/entities/public_fund.dart';
import 'package:squadly/features/finance/domain/repositories/finance_repository.dart';
import 'package:squadly/features/finance/presentation/providers/finance_provider.dart';
import 'package:squadly/features/finance/presentation/screens/finance_screen.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';

void main() {
  test('finance server failure messages hide backend details', () {
    expect(
      financeFailureMessage(
        const Failure.server(message: 'private_assets account_number=1234'),
      ),
      '理财服务暂时不可用，请稍后重试',
    );
  });

  testWidgets('demo finance shows only the signed-in member private assets', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoAppStoreProvider.overrideWith((ref) => store),
          useDemoBackendProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FinanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旅行备用金'), findsOneWidget);
    expect(find.text('指数基金'), findsNothing);

    store.signInWithEmail(email: 'lina@example.com', password: 'password1');
    await tester.pumpAndSettle();

    expect(find.text('指数基金'), findsOneWidget);
    expect(find.text('旅行备用金'), findsNothing);
  });

  testWidgets('CloudBase finance hides raw errors and retries loading', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          canManagePublicFundsProvider('squad-a').overrideWith((ref) => false),
          financeSnapshotProvider('squad-a').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('private_assets SELECT account_number=1234');
            }
            return const FinanceSnapshot(
              funds: [],
              privateAssets: [],
              expenses: [],
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FinanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('理财数据暂时无法加载'), findsOneWidget);
    expect(find.textContaining('account_number'), findsNothing);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('资金概览'), findsOneWidget);
    expect(find.text('理财数据暂时无法加载'), findsNothing);
  });

  testWidgets('CloudBase fund form validates before calling the repository', (
    tester,
  ) async {
    final repository = _FinanceRepository();
    var createCalls = 0;
    when(
      () => repository.createFund(
        squadId: any(named: 'squadId'),
        name: any(named: 'name'),
        fundType: any(named: 'fundType'),
        targetAmount: any(named: 'targetAmount'),
      ),
    ).thenAnswer((_) async {
      createCalls++;
      return right(_fund);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          financeRepositoryProvider.overrideWithValue(repository),
          canManagePublicFundsProvider('squad-a').overrideWith((ref) => true),
          financeSnapshotProvider('squad-a').overrideWith(
            (ref) async => const FinanceSnapshot(
              funds: [],
              privateAssets: [],
              expenses: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FinanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('创建基金'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Infinity');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请输入有效金额'), findsOneWidget);
    expect(createCalls, 0);

    await tester.enterText(find.byType(TextFormField).first, '周末旅行');
    await tester.enterText(find.byType(TextFormField).last, '2500');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(createCalls, 1);
    expect(find.text('创建公共基金'), findsNothing);
  });

  testWidgets('fund form rejects invalid amounts without saving zero', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    final initialFundCount = store.state.publicFunds.length;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoAppStoreProvider.overrideWith((ref) => store),
          useDemoBackendProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FinanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('创建基金'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'NaN');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请输入有效金额'), findsOneWidget);
    expect(store.state.publicFunds, hasLength(initialFundCount));

    await tester.enterText(find.byType(TextFormField).last, '-12');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('金额不能小于 0'), findsOneWidget);
    expect(store.state.publicFunds, hasLength(initialFundCount));
  });

  testWidgets('demo member can record transactions but cannot create funds', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'lina@example.com', password: 'password1');
    await _pumpDemoFinanceScreen(tester, store);
    expect(find.byTooltip('创建基金'), findsNothing);
    expect(find.text('记一笔'), findsWidgets);
    expect(
      () => store.createFund(
        squadId: store.state.currentSquad!.id,
        name: 'Rejected',
        fundType: 'custom',
      ),
      throwsStateError,
    );
    final fund = store.state.fundsFor(store.state.currentSquad!.id).first;
    final amount = fund.currentAmount;
    store.addFundTransaction(fundId: fund.id, amount: 10);
    expect(
      store.state
          .fundsFor(fund.squadId)
          .firstWhere((f) => f.id == fund.id)
          .currentAmount,
      amount + 10,
    );
  });

  testWidgets('remote member cannot see the fund creation entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useDemoBackendProvider.overrideWithValue(false),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          canManagePublicFundsProvider('squad-a').overrideWith((ref) => false),
          financeSnapshotProvider('squad-a').overrideWith(
            (ref) async => FinanceSnapshot(
              funds: [_fund],
              privateAssets: [],
              expenses: [],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: FinanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('创建基金'), findsNothing);
    expect(find.byTooltip('记一笔'), findsOneWidget);
  });

  testWidgets('private asset form rejects negative amounts', (tester) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    final initialAssetCount = store.state.myPrivateAssets.length;

    await _pumpDemoFinanceScreen(tester, store);
    await tester.tap(find.byTooltip('新增资产'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '-1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('金额不能小于 0'), findsOneWidget);
    expect(store.state.myPrivateAssets, hasLength(initialAssetCount));
  });

  testWidgets('shared expense form rejects zero amounts', (tester) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    final initialExpenseCount = store.state.sharedExpenses.length;

    await _pumpDemoFinanceScreen(tester, store);
    await tester.scrollUntilVisible(
      find.byTooltip('记录支出'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('记录支出'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('金额需大于 0'), findsOneWidget);
    expect(store.state.sharedExpenses, hasLength(initialExpenseCount));
  });

  testWidgets('fund transactions reject zero but accept signed expenses', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    final fund = store.state.fundsFor('squad-weekend').first;
    final initialBalance = fund.currentAmount;

    await _pumpDemoFinanceScreen(tester, store);
    await tester.tap(find.text('记一笔').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('金额不能为 0'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '-20');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('基金流水'), findsNothing);
    expect(
      store.state.publicFunds
          .firstWhere((item) => item.id == fund.id)
          .currentAmount,
      initialBalance - 20,
    );
  });
}

Future<void> _pumpDemoFinanceScreen(
  WidgetTester tester,
  DemoAppStore store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoAppStoreProvider.overrideWith((ref) => store),
        useDemoBackendProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: FinanceScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _squad = Squad(
  id: 'squad-a',
  name: '周末小队',
  inviteCode: '',
  createdBy: 'user-a',
  createdAt: DateTime.utc(2026, 10, 19),
);

final _fund = PublicFund(
  id: 'fund-created',
  squadId: 'squad-a',
  name: '周末旅行',
  fundType: 'travel',
  targetAmount: 2500,
  createdBy: 'user-a',
  createdAt: DateTime.utc(2026, 10, 19),
);

class _FinanceRepository extends Mock implements FinanceRepository {}
