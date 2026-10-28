import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:squadly/app/providers/plan_providers.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/plan/domain/entities/plan_progress.dart';
import 'package:squadly/features/plan/domain/entities/squad_plan.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';
import 'package:squadly/features/squad/domain/entities/squad_member.dart';
import 'package:squadly/features/squad/domain/entities/squad_recent_share.dart';
import 'package:squadly/features/squad/domain/repositories/squad_repository.dart';
import 'package:squadly/features/squad/presentation/providers/squad_provider.dart';
import 'package:squadly/features/squad/presentation/screens/squad_list_screen.dart';

class _SquadBoundary extends Mock implements SquadRepository {}

List<Override> _emptyPlanOverrides() => [
  squadPlansProvider('squad-a').overrideWith((ref) async => []),
  squadPlanProgressProvider('squad-a').overrideWith((ref) async => {}),
];

final _squad = Squad(
  id: 'squad-a',
  name: '周末跑步',
  inviteCode: '',
  createdBy: 'user-a',
  createdAt: DateTime.utc(2026, 10, 8),
);

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'user-a', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 18)),
  );
}

void main() {
  testWidgets('labels the CloudBase squad loading state for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSquadProvider.overrideWith((ref) => const AsyncLoading()),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('正在加载小队…'), findsOneWidget);
  });

  testWidgets('shows the shared Squad onboarding in CloudBase mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith((ref) async => []),
          currentSquadProvider.overrideWith((ref) => const AsyncData(null)),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有小队'), findsOneWidget);
    expect(find.text('创建小队'), findsOneWidget);
    expect(find.text('输入邀请码加入'), findsOneWidget);
    expect(find.text('保留个人隐私'), findsOneWidget);
    expect(find.text('周末城市漫步'), findsNothing);
  });

  testWidgets('shows recent squad shares and opens their conversation', (
    tester,
  ) async {
    Squad? openedSquad;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          ..._emptyPlanOverrides(),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadRecentSharesProvider('squad-a').overrideWith(
            (ref) async => [
              SquadRecentShare(
                messageId: 'share-a',
                authorName: '阿青',
                title: '晨跑 5 公里',
                createdAt: DateTime.now(),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RemoteSquadListScreen(
              onOpenConversation: (squad) => openedSquad = squad,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('近期分享'), findsOneWidget);
    expect(find.text('晨跑 5 公里'), findsOneWidget);
    await tester.tap(find.text('晨跑 5 公里'));

    expect(openedSquad?.id, 'squad-a');
  });

  testWidgets('shows shared plan progress but hides private plans', (
    tester,
  ) async {
    var openedPlans = false;
    final date = DateTime.utc(2026, 10, 18);
    SquadPlan plan({
      required String id,
      required String title,
      required PlanVisibility visibility,
    }) => SquadPlan(
      id: id,
      squadId: 'squad-a',
      title: title,
      category: PlanCategory.travel,
      visibility: visibility,
      status: PlanStatus.active,
      createdBy: 'user-a',
      createdAt: date,
      updatedAt: date,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadPlansProvider('squad-a').overrideWith(
            (ref) async => [
              plan(
                id: 'shared-plan',
                title: '周末徒步',
                visibility: PlanVisibility.squad,
              ),
              plan(
                id: 'private-plan',
                title: '私密储蓄计划',
                visibility: PlanVisibility.private,
              ),
            ],
          ),
          squadPlanProgressProvider('squad-a').overrideWith(
            (ref) async => {
              'shared-plan': const PlanProgress(
                completedCount: 2,
                totalCount: 4,
              ),
            },
          ),
          squadRecentSharesProvider('squad-a').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RemoteSquadListScreen(onOpenPlans: () => openedPlans = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('共同计划'), findsOneWidget);
    expect(find.text('周末徒步'), findsOneWidget);
    expect(find.text('2/4 项任务已完成'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('私密储蓄计划'), findsNothing);
    await tester.tap(find.text('查看计划'));
    expect(openedPlans, isTrue);
  });

  testWidgets('retries shared plan progress after a loading failure', (
    tester,
  ) async {
    var attempts = 0;
    final plan = SquadPlan(
      id: 'shared-plan',
      squadId: 'squad-a',
      title: '周末徒步',
      category: PlanCategory.travel,
      visibility: PlanVisibility.squad,
      status: PlanStatus.active,
      createdBy: 'user-a',
      createdAt: DateTime.utc(2026, 10, 18),
      updatedAt: DateTime.utc(2026, 10, 18),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadPlansProvider('squad-a').overrideWith((ref) async => [plan]),
          squadPlanProgressProvider('squad-a').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('network');
            return {
              'shared-plan': const PlanProgress(
                completedCount: 1,
                totalCount: 2,
              ),
            };
          }),
          squadRecentSharesProvider('squad-a').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('进度加载失败，重试'), findsOneWidget);
    await tester.tap(find.text('进度加载失败，重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('1/2 项任务已完成'), findsOneWidget);
    expect(find.text('进度加载失败，重试'), findsNothing);
  });

  testWidgets('retries when recent squad shares fail to load', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          ..._emptyPlanOverrides(),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadRecentSharesProvider('squad-a').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('network');
            return [
              SquadRecentShare(
                messageId: 'share-a',
                authorName: '阿青',
                title: '晨跑 5 公里',
                createdAt: DateTime.utc(2026, 10, 18),
              ),
            ];
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分享加载失败，点击重试'), findsOneWidget);
    await tester.tap(find.text('分享加载失败，点击重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('晨跑 5 公里'), findsOneWidget);
    expect(find.text('分享加载失败，点击重试'), findsNothing);
  });

  testWidgets('shows a network error and retries the squad load', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('network');
            return [_squad];
          }),
          ..._emptyPlanOverrides(),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadRecentSharesProvider('squad-a').overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小队加载失败'), findsOneWidget);
    expect(find.text('请检查网络连接后重试。'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('周末跑步'), findsWidgets);
    expect(find.text('小队加载失败'), findsNothing);
  });

  testWidgets('handles long share titles on a narrow dark screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const longTitle = '这是一个很长的运动分享标题，用于检查小屏幕和大字体下的小队动态是否会溢出';
    const longPlanTitle = '这是一个很长的共同计划标题，用于检查窄屏和大字体下的计划摘要布局';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          squadPlansProvider('squad-a').overrideWith(
            (ref) async => [
              SquadPlan(
                id: 'long-plan',
                squadId: 'squad-a',
                title: longPlanTitle,
                category: PlanCategory.custom,
                visibility: PlanVisibility.squad,
                status: PlanStatus.active,
                createdBy: 'user-a',
                createdAt: DateTime.utc(2026, 10, 18),
                updatedAt: DateTime.utc(2026, 10, 18),
              ),
            ],
          ),
          squadPlanProgressProvider('squad-a').overrideWith(
            (ref) async => {
              'long-plan': const PlanProgress(completedCount: 2, totalCount: 3),
            },
          ),
          squadMembersProvider('squad-a').overrideWith((ref) async => []),
          squadRecentSharesProvider('squad-a').overrideWith(
            (ref) async => [
              SquadRecentShare(
                messageId: 'share-a',
                authorName: '阿青',
                title: longTitle,
                createdAt: DateTime.utc(2026, 10, 18),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: RemoteSquadListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('近期分享'), findsOneWidget);
    expect(find.text('共同计划'), findsOneWidget);
  });

  testWidgets('creating a squad selects the server-created squad', (
    tester,
  ) async {
    final repository = _SquadBoundary();
    when(() => repository.createSquad(name: '周末跑步', description: null))
        .thenAnswer((_) async => Right(_squad));
    final container = ProviderContainer(
      overrides: [
        squadRepositoryProvider.overrideWithValue(repository),
        mySquadsProvider.overrideWith((ref) async => []),
        currentSquadProvider.overrideWith((ref) => const AsyncData(null)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const Scaffold(body: RemoteSquadListScreen()),
        ),
      ),
    );

    await tester.tap(find.text('创建小队'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '周末跑步');
    await tester.tap(find.text('创建').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedSquadIdProvider), 'squad-a');
  });

  testWidgets('shows member loading error and retries the real provider', (
    tester,
  ) async {
    var attempts = 0;
    final member = SquadMember(
      id: 'membership-a',
      squadId: 'squad-a',
      userId: 'user-a',
      role: 'captain',
      joinedAt: DateTime.utc(2026, 10, 8),
      nickname: '阿青',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          mySquadsProvider.overrideWith((ref) async => [_squad]),
          currentSquadProvider.overrideWith((ref) => AsyncData(_squad)),
          ..._emptyPlanOverrides(),
          squadMembersProvider('squad-a').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('network');
            return [member];
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: RemoteSquadListScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('成员加载失败，点击重试'), findsOneWidget);
    await tester.tap(find.text('成员加载失败，点击重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('阿青（我）'), findsOneWidget);
    expect(find.text('成员加载失败，点击重试'), findsNothing);
  });
}
