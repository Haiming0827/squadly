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
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  testWidgets('a text reply explicitly references the visible card', (
    tester,
  ) async {
    final repository = _CardConversationRepository();
    addTearDown(repository.dispose);
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
    String squadId,
  ) async => right(List.unmodifiable(_entries));

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
  Stream<void> watchTimeline(String squadId) => _updates.stream;
}
