import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/plan_providers.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/data/memory_conversation_outbox.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_list_screen.dart';
import 'package:squadly/features/conversation/presentation/conversation_provider.dart';
import 'package:squadly/features/home/presentation/screens/remote_home_shell_screen.dart';
import 'package:squadly/features/plan/domain/entities/squad_plan.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';
import 'package:squadly/features/squad/presentation/providers/squad_provider.dart';

final class _SignedIn extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿青', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _Conversation implements ConversationRepository {
  _Conversation({
    this.recentBySquad = const {},
    this.recentByPlan = const {},
    this.failedSquadIds = const {},
  });

  final Map<String, List<TimelineEntry>> recentBySquad;
  final Map<String, List<TimelineEntry>> recentByPlan;
  final Set<String> failedSquadIds;
  final updates = StreamController<void>.broadcast();

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => failedSquadIds.contains(squadId)
      ? left(const Failure.network(message: 'offline'))
      : right(
          planId == null
              ? recentBySquad[squadId] ?? const []
              : recentByPlan[planId] ?? const [],
        );

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right(const []);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right(const []);

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async => left(const Failure.server(message: 'Not used'));

  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async => left(const Failure.server(message: 'Not used'));

  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right(const {});

  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      updates.stream;
}

void main() {
  testWidgets('conversation loading state explains the pending work', (
    tester,
  ) async {
    final squads = Completer<List<Squad>>();
    final repository = _Conversation();
    addTearDown(repository.updates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith((ref) => squads.future),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在加载会话'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .semanticsLabel,
      '正在加载会话',
    );

    squads.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('还没有会话'), findsOneWidget);
  });

  testWidgets('real conversation list orders squads by latest message', (
    tester,
  ) async {
    final olderSquad = Squad(
      id: 'squad-a',
      name: '晨跑小队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    final newerSquad = Squad(
      id: 'squad-b',
      name: '周末旅行',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 9),
    );
    final repository = _Conversation(
      recentBySquad: {
        'squad-a': [_message('squad-a', DateTime.utc(2026, 10, 10, 9))],
        'squad-b': [_message('squad-b', DateTime.utc(2026, 10, 11, 9))],
      },
    );
    addTearDown(repository.updates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith(
            (ref) async => [olderSquad, newerSquad],
          ),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final newerTile = tester.getTopLeft(
      find.byKey(const ValueKey('conversation-squad-b')),
    );
    final olderTile = tester.getTopLeft(
      find.byKey(const ValueKey('conversation-squad-a')),
    );
    expect(newerTile.dy, lessThan(olderTile.dy));
  });

  testWidgets('plan discussions appear in the shared conversation list', (
    tester,
  ) async {
    final squad = Squad(
      id: 'squad-a',
      name: '周末小队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    final plan = SquadPlan(
      id: 'plan-a',
      squadId: 'squad-a',
      title: '杭州两日游',
      category: PlanCategory.travel,
      visibility: PlanVisibility.squad,
      status: PlanStatus.active,
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
      updatedAt: DateTime.utc(2026, 10, 8),
    );
    final repository = _Conversation(
      recentByPlan: {
        'plan-a': [
          TimelineEntry(
            id: 'plan-message-1',
            squadId: 'squad-a',
            planId: 'plan-a',
            authorId: 'alice',
            authorName: '阿青',
            kind: TimelineEntryKind.text,
            text: '周六九点出发',
            clientNonce: 'plan-nonce-1',
            createdAt: DateTime.utc(2026, 10, 11, 9),
          ),
        ],
      },
    );
    addTearDown(repository.updates.close);
    ConversationListItem? openedPlan;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith((ref) async => [squad]),
          squadPlansProvider('squad-a').overrideWith((ref) async => [plan]),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenPlanConversation: (item) => openedPlan = item,
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('杭州两日游'), findsOneWidget);
    expect(find.text('周末小队 · 阿青：周六九点出发'), findsOneWidget);
    await tester.tap(find.text('杭州两日游'));
    expect(openedPlan?.plan?.id, 'plan-a');
    expect(openedPlan?.target.planId, 'plan-a');
  });

  testWidgets('real conversation list searches and filters actual activity', (
    tester,
  ) async {
    final activeSquad = Squad(
      id: 'active',
      name: '晨跑小队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    final quietSquad = Squad(
      id: 'quiet',
      name: '周末旅行',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 9),
    );
    final repository = _Conversation(
      recentBySquad: {
        'active': [_message('active', DateTime.utc(2026, 10, 10, 9))],
      },
    );
    addTearDown(repository.updates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith(
            (ref) async => [activeSquad, quietSquad],
          ),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会话'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-quiet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('conversation-search-field')),
      '一起出发吗',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-quiet')), findsNothing);

    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('conversation-search-field')),
      '旅行',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-quiet')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-active')), findsNothing);

    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选会话'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('conversation-filter-withMessages')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-quiet')), findsNothing);

    await tester.tap(find.byTooltip('筛选会话'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('conversation-filter-withoutMessages')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-quiet')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-active')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('conversation-search-field')),
      '不存在的小队',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的会话'), findsOneWidget);
    await tester.tap(find.text('清除搜索和筛选'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-quiet')), findsOneWidget);
  });

  testWidgets('real conversation list retries after a loading failure', (
    tester,
  ) async {
    final squad = Squad(
      id: 'squad-a',
      name: '晨跑小队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    final repository = _Conversation(failedSquadIds: {'squad-a'});
    addTearDown(repository.updates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith((ref) async => [squad]),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('会话加载失败'), findsOneWidget);
    repository.failedSquadIds.clear();
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conversation-squad-a')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation-search-field')),
      findsOneWidget,
    );
  });

  testWidgets('conversation controls fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final squad = Squad(
      id: 'squad-long',
      name: '周末一起徒步探索城市周边自然风景的小分队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    final repository = _Conversation();
    addTearDown(repository.updates.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySquadsProvider.overrideWith((ref) async => [squad]),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationListScreen(
              onOpenConversation: (_) {},
              onOpenSquads: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('conversation-search-field')),
      findsOneWidget,
    );
    expect(find.text('会话'), findsOneWidget);
    await tester.tap(find.byTooltip('筛选会话'));
    await tester.pumpAndSettle();
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('有消息'), findsOneWidget);
    expect(find.text('暂无消息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real shell reaches squad conversation and card composer', (
    tester,
  ) async {
    final repository = _Conversation();
    addTearDown(repository.updates.close);
    final squad = Squad(
      id: 'squad-a',
      name: '晨跑小队',
      inviteCode: '',
      createdBy: 'alice',
      createdAt: DateTime.utc(2026, 10, 8),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          currentSquadProvider.overrideWithValue(AsyncData(squad)),
          mySquadsProvider.overrideWith((ref) async => [squad]),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationOutboxProvider.overrideWithValue(
            MemoryConversationOutbox(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RemoteHomeShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('晨跑小队'), findsWidgets);
    expect(find.text('还没有消息，发起第一次交流'), findsOneWidget);
    expect(find.textContaining('本地演示'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('conversation-squad-a')));
    await tester.pumpAndSettle();
    expect(find.text('还没有消息，来打个招呼吧'), findsOneWidget);
    await tester.tap(find.byTooltip('生成卡片'));
    await tester.pumpAndSettle();
    expect(find.text('生成卡片'), findsOneWidget);
    expect(find.text('发布到 晨跑小队'), findsOneWidget);
  });

  testWidgets('without a squad real shell does not show fake conversation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedIn.new),
          currentSquadProvider.overrideWithValue(const AsyncData(null)),
          mySquadsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RemoteHomeShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('创建或加入小队'), findsOneWidget);
    expect(find.byTooltip('生成卡片'), findsNothing);

    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();
    expect(find.text('先创建或加入小队'), findsOneWidget);
    await tester.tap(find.text('前往小队'));
    await tester.pumpAndSettle();
    expect(find.text('还没有小队'), findsOneWidget);
    expect(find.text('输入邀请码加入'), findsOneWidget);
  });
}

TimelineEntry _message(String squadId, DateTime createdAt) => TimelineEntry(
  id: 'message-$squadId',
  squadId: squadId,
  authorId: 'alice',
  authorName: '阿青',
  kind: TimelineEntryKind.text,
  text: '一起出发吗？',
  clientNonce: 'nonce-$squadId',
  createdAt: createdAt,
);
