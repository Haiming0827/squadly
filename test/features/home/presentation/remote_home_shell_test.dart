import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_provider.dart';
import 'package:squadly/features/home/presentation/screens/remote_home_shell_screen.dart';
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
  final updates = StreamController<void>.broadcast();

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId,
  ) async => right(const []);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor,
  ) async => right(const []);

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor,
  ) async => right(const []);

  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
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
  Stream<void> watchTimeline(String squadId) => updates.stream;
}

void main() {
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
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RemoteHomeShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('晨跑小队'), findsWidgets);
    expect(find.text('还没有消息，来打个招呼吧'), findsOneWidget);
    expect(find.textContaining('本地演示'), findsNothing);
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
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const RemoteHomeShellScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('先创建或加入小队'), findsOneWidget);
    expect(find.byTooltip('生成卡片'), findsNothing);
  });
}
