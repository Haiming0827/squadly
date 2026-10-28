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
import 'package:squadly/features/conversation/presentation/conversation_screen.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  testWidgets(
    'photo slot uses the same message identity and text reply parent',
    (tester) async {
      final repository = _CardConversationRepository();
      addTearDown(repository.dispose);
      repository._entries
        ..clear()
        ..add(
          TimelineEntry(
            id: 'photo-entry',
            squadId: 'squad-a',
            authorId: 'bob',
            authorName: '阿博',
            kind: TimelineEntryKind.photo,
            clientNonce: 'nonce-photo',
            createdAt: DateTime.utc(2026, 10, 8),
            photo: const PhotoAttachment(
              mediaId: 'media',
              width: 4,
              height: 3,
              byteLength: 600,
              isRevoked: false,
            ),
          ),
        );
      var captures = 0;
      TimelineEntry? rendered;
      bool? readable;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
            conversationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ConversationScreen(
                squadId: 'squad-a',
                squadName: '晨跑小队',
                onCreateCard: () {},
                onCreatePhoto: () => captures++,
                photoBuilder: (_, entry, canRead, onDisplayChanged) {
                  rendered = entry;
                  readable = canRead;
                  return const Text('安全照片视图');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered?.id, 'photo-entry');
      expect(readable, isTrue);
      await tester.tap(find.byTooltip('发照片'));
      await tester.pump();
      expect(captures, 1);
      await tester.tap(find.text('回复'));
      await tester.pumpAndSettle();
      expect(find.text('回复：这张照片'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '回到同一张照片');
      await tester.tap(find.byTooltip('发送消息'));
      await tester.pumpAndSettle();
      expect(repository.lastReplyToId, 'photo-entry');
    },
  );

  testWidgets(
    'private plan discussion never exposes the ordinary photo entry',
    (tester) async {
      final repository = _CardConversationRepository().._entries.clear();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
            conversationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ConversationScreen(
                squadId: 'squad-a',
                squadName: '晨跑小队',
                planId: 'private-plan',
                onCreateCard: () {},
                onCreatePhoto: () => fail('No ordinary photo in plan'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('发照片'), findsNothing);
      expect(find.byTooltip('生成卡片'), findsNothing);
    },
  );
  testWidgets(
    'conversation detail fits narrow screens with large Chinese text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = _CardConversationRepository();
      addTearDown(repository.dispose);
      const longBody = '这是一条较长的中文消息，用来确认窄屏和大字号下仍能阅读、换行并正常发送。';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
            conversationRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ConversationScreen(
                squadId: 'squad-a',
                squadName: '周末一起徒步探索城市周边自然风景的小分队',
                onCreateCard: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), longBody);
      await tester.tap(find.byTooltip('发送消息'));
      await tester.pumpAndSettle();

      expect(find.text(longBody), findsOneWidget);
      expect(find.byTooltip('刷新消息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed initial load does not look like an empty conversation', (
    tester,
  ) async {
    final repository = _CardConversationRepository()..failLoad = true;
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ConversationScreen(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              onCreateCard: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时无法显示消息'), findsOneWidget);
    expect(find.text('还没有消息，来打个招呼吧'), findsNothing);

    repository.failLoad = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('晨跑'), findsOneWidget);
    expect(find.text('暂时无法显示消息'), findsNothing);
  });

  testWidgets('a text reply explicitly references the visible card', (
    tester,
  ) async {
    final repository = _CardConversationRepository();
    addTearDown(repository.dispose);
    TimelineEntry? openedCard;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: ConversationScreen(
              squadId: 'squad-a',
              squadName: '晨跑小队',
              onCreateCard: () {},
              onOpenCard: (entry) => openedCard = entry,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('晨跑'));
    expect(openedCard?.id, 'card-entry-1');

    await tester.tap(find.text('回复卡片'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '下次一起跑');
    await tester.tap(find.byTooltip('发送消息'));
    await tester.pumpAndSettle();

    expect(repository.lastReplyToId, 'card-entry-1');
    expect(find.text('下次一起跑'), findsOneWidget);
  });
}

final class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<User?> build() => AsyncData(
    User(id: 'alice', nickname: '阿晴', createdAt: DateTime.utc(2026, 10, 8)),
  );
}

final class _CardConversationRepository implements ConversationRepository {
  bool failLoad = false;
  final _updates = StreamController<void>.broadcast();
  String? lastReplyToId;
  late final List<TimelineEntry> _entries = [
    TimelineEntry(
      id: 'card-entry-1',
      squadId: 'squad-a',
      authorId: 'bob',
      authorName: '阿博',
      kind: TimelineEntryKind.card,
      cardId: 'card-1',
      cardSnapshot: CardSnapshot(
        kind: CardKind.activity,
        payload: {
          'activity_type': 'run',
          'date': '2026-10-08',
          'distance_m': 5000,
          'duration_s': 1800,
          'pace_s_per_km': 360,
          'title': '晨跑',
        },
      ),
      clientNonce: 'nonce-card',
      createdAt: DateTime.utc(2026, 10, 8, 8),
    ),
  ];

  void dispose() => _updates.close();

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => failLoad
      ? left(const Failure.network(message: 'offline'))
      : right(List.unmodifiable(_entries));

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
  }) async {
    lastReplyToId = replyToEntryId;
    final entry = TimelineEntry(
      id: 'reply-1',
      squadId: squadId,
      authorId: 'alice',
      authorName: '阿晴',
      kind: TimelineEntryKind.text,
      text: body,
      replyToEntryId: replyToEntryId,
      clientNonce: clientNonce,
      createdAt: DateTime.utc(2026, 10, 8, 9),
    );
    _entries.add(entry);
    return right(entry);
  }

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
      _updates.stream;
}
