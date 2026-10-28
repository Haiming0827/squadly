import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/demo/demo_store.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/plan/domain/entities/plan_progress.dart';
import 'package:squadly/features/plan/domain/entities/squad_plan.dart';
import 'package:squadly/features/plan/presentation/providers/plan_provider.dart';
import 'package:squadly/features/plan/presentation/screens/plan_home_screen.dart';

void main() {
  testWidgets('shows current squad plans and opens task details', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.text('周末行动组'), findsOneWidget);
    expect(find.text('把周末安排好'), findsOneWidget);
    expect(find.text('我的训练节奏'), findsOneWidget);
    expect(find.text('仅自己可见'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.text('把周末安排好'));
    await tester.pumpAndSettle();

    expect(find.text('计划详情'), findsOneWidget);
    expect(find.text('确定徒步路线'), findsOneWidget);
    expect(find.text('准备饮用水'), findsOneWidget);
    expect(find.text('当前小队成员可以查看此计划和其中的任务。'), findsOneWidget);
    expect(find.text('1/2 已完成'), findsOneWidget);

    await tester.tap(find.byTooltip('更新计划状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();
    expect(
      store.state.squadPlans
          .firstWhere((plan) => plan.id == 'squad-plan-weekend')
          .status,
      PlanStatus.completed,
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(
      store.state.planTasks
          .firstWhere((task) => task.id == 'squad-task-route')
          .isComplete,
      isTrue,
    );
    Navigator.of(tester.element(find.text('计划详情'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('creates a private plan with explicit Squad context', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '只自己可见的计划');
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前小队可见'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅自己可见').last);
    await tester.pumpAndSettle();
    expect(find.text('计划仍关联当前小队，仅你可以查看。'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '创建计划'));
    await tester.pumpAndSettle();

    expect(find.text('只自己可见的计划'), findsOneWidget);
    expect(find.text('仅自己可见'), findsWidgets);
    expect(
      store.state.squadPlans.any(
        (plan) =>
            plan.title == '只自己可见的计划' &&
            plan.squadId == 'squad-weekend' &&
            plan.visibility.name == 'private',
      ),
      isTrue,
    );

    await tester.tap(find.text('只自己可见的计划'));
    await tester.pumpAndSettle();
    expect(find.text('暂无任务，添加任务后会显示进度'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('uses a plan template to prefill category and suggested title', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
    expect(find.text('整理行程安排与分工'), findsOneWidget);
    await tester.tap(find.text('旅行计划').first);
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(titleField.controller?.text, '旅行计划');
    expect(find.text('计划类型'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '创建计划'));
    await tester.pumpAndSettle();

    final created = store.state.squadPlans.firstWhere(
      (plan) => plan.title == '旅行计划',
    );
    expect(created.category, PlanCategory.travel);
    expect(created.squadId, 'squad-weekend');
  });

  testWidgets('assigns a new task to a member of the current Squad', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('把周末安排好'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加任务'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '带上急救包');
    await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('李娜').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置截止日期（选填）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    final task = store.state.planTasks.firstWhere(
      (task) => task.title == '带上急救包',
    );
    expect(task.assignedTo, 'user-lina');
    expect(task.dueDate?.year, DateTime.now().year);
    expect(task.dueDate?.month, DateTime.now().month);
    expect(task.dueDate?.day, DateTime.now().day);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('带上急救包'), findsOneWidget);
    expect(find.textContaining('负责人：李娜'), findsOneWidget);
    expect(find.textContaining('截止 '), findsOneWidget);
  });

  testWidgets('edits plan details and keeps its Squad association', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('把周末安排好'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '调整后的周末计划');
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存修改'));
    await tester.pumpAndSettle();

    final plan = store.state.squadPlans.firstWhere(
      (item) => item.id == 'squad-plan-weekend',
    );
    expect(plan.title, '调整后的周末计划');
    expect(plan.squadId, 'squad-weekend');
    expect(find.text('调整后的周末计划'), findsOneWidget);
    expect(find.text('计划已更新'), findsOneWidget);
  });

  testWidgets(
    'requires plan title and preserves it when moving between steps',
    (tester) async {
      final store = DemoAppStore()
        ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '创建'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '下一步'));
      await tester.pumpAndSettle();
      expect(find.text('请输入计划名称'), findsOneWidget);
      expect(find.text('第 1 步 · 基本信息'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '周末散步');
      await tester.tap(find.widgetWithText(FilledButton, '下一步'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 步 · 协作设置'), findsOneWidget);
      await tester.tap(find.text('上一步'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        '周末散步',
      );
    },
  );

  testWidgets('fits a narrow screen with increased text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    store.createPlan(
      squadId: 'squad-weekend',
      title: '这是一个很长的中文计划名称用于检查小屏幕布局是否会挤压操作按钮',
      description: '这段说明文字也比较长，用来检查页面在系统字体放大时仍然可以阅读和滚动。',
      category: PlanCategory.custom,
      visibility: PlanVisibility.squad,
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('这是一个很长的中文计划名称用于检查小屏幕布局是否会挤压操作按钮'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.text('计划详情'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('模板'));
    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
    expect(find.text('整理行程安排与分工'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('旅行计划').first);
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(find.text('第 1 步 · 基本信息'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '下一步'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 步 · 协作设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows plan load error and retries successfully', (tester) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoAppStoreProvider.overrideWith((ref) => store),
          squadPlansProvider('squad-weekend').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('network');
            return store.getVisiblePlans('squad-weekend');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PlanHomeScreen(isDemo: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('计划加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('把周末安排好'), findsOneWidget);
    expect(find.text('计划加载失败'), findsNothing);
  });

  testWidgets('shows permission-specific plan loading feedback', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoAppStoreProvider.overrideWith((ref) => store),
          squadPlansProvider('squad-weekend').overrideWith((ref) async {
            throw StateError('没有查看该计划的权限');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PlanHomeScreen(isDemo: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有查看该计划的权限'), findsOneWidget);
    expect(find.text('计划加载失败'), findsNothing);
  });

  testWidgets('keeps pull-to-refresh active until data requests finish', (
    tester,
  ) async {
    final store = DemoAppStore()
      ..signInWithEmail(email: 'haiming@example.com', password: 'password1');
    final plansRefresh = Completer<List<SquadPlan>>();
    final progressRefresh = Completer<Map<String, PlanProgress>>();
    var planLoads = 0;
    var progressLoads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoAppStoreProvider.overrideWith((ref) => store),
          squadPlansProvider('squad-weekend').overrideWith((ref) {
            planLoads++;
            return planLoads == 1
                ? Future.value(store.getVisiblePlans('squad-weekend'))
                : plansRefresh.future;
          }),
          squadPlanProgressProvider('squad-weekend').overrideWith((ref) {
            progressLoads++;
            return progressLoads == 1
                ? Future.value(const <String, PlanProgress>{})
                : progressRefresh.future;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PlanHomeScreen(isDemo: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final refresh = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(planLoads, 2);
    expect(progressLoads, 2);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    plansRefresh.complete(store.getVisiblePlans('squad-weekend'));
    progressRefresh.complete(const <String, PlanProgress>{});
    await refresh;
    await tester.pumpAndSettle();

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(DemoAppStore store) => ProviderScope(
  overrides: [demoAppStoreProvider.overrideWith((ref) => store)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const Scaffold(body: PlanHomeScreen(isDemo: true)),
  ),
);
