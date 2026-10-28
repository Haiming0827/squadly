import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/domain/entities/user.dart';
import 'package:squadly/features/cards/domain/card_composer.dart';
import 'package:squadly/features/conversation/domain/conversation_read_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_target.dart';
import 'package:squadly/features/conversation/domain/message_read_receipt.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/conversation/presentation/conversation_provider.dart';
import 'package:squadly/features/conversation/presentation/conversation_read_provider.dart';
import 'package:squadly/features/conversation/presentation/conversation_screen.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

TimelineEntry _message(int index, {String author = 'alice'}) => TimelineEntry(
  id: 'message-${index.toString().padLeft(3, '0')}',
  squadId: 'squad',
  authorId: author,
  authorName: author,
  kind: TimelineEntryKind.text,
  text: '消息 $index · 中文内容',
  clientNonce: 'nonce-$index',
  createdAt: DateTime.utc(2026, 10, 22, 10, index),
);

final class _Timeline implements ConversationRepository {
  final entries = <TimelineEntry>[_message(1), _message(2, author: 'bob')];
  final changes = StreamController<void>.broadcast();
  void add(int index) {
    entries.add(_message(index));
    changes.add(null);
  }

  @override
  Future<Either<Failure, List<TimelineEntry>>> loadRecent(
    String squadId, {
    String? planId,
  }) async => right(List.of(entries));
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadAfter(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right(
    entries
        .where((entry) => entry.createdAt.isAfter(cursor.createdAt))
        .toList(),
  );
  @override
  Future<Either<Failure, List<TimelineEntry>>> loadBefore(
    String squadId,
    TimelineCursor cursor, {
    String? planId,
  }) async => right([]);
  @override
  Stream<void> watchTimeline(String squadId, {String? planId}) =>
      changes.stream;
  @override
  Future<Either<Failure, TimelineEntry>> sendText({
    required String squadId,
    required String body,
    required String clientNonce,
    String? replyToEntryId,
    String? planId,
  }) async => left(const Failure.network());
  @override
  Future<Either<Failure, TimelineEntry>> publishCard({
    required String squadId,
    required String cardId,
    required CardSnapshot snapshot,
    required String clientNonce,
    EncryptedRouteBundle? encryptedRoute,
  }) async => left(const Failure.network());
  @override
  Future<Either<Failure, Map<String, String>>> loadMessageTexts({
    required String squadId,
    required List<String> messageIds,
  }) async => right({});
}

final class _Reads implements ConversationReadRepository {
  final ids = <String>[];
  final requested = <String>[];
  bool fail = false;
  Completer<Either<Failure, List<MessageReadReceipt>>>? gate;
  @override
  Future<Either<Failure, Unit>> advance({
    required ConversationTarget target,
    required String messageId,
  }) async {
    ids.add(messageId);
    return right(unit);
  }

  @override
  Future<Either<Failure, List<MessageReadReceipt>>> loadForMessages({
    required ConversationTarget target,
    required List<String> messageIds,
  }) async {
    requested.addAll(messageIds);
    if (gate != null) return gate!.future;
    if (fail) return left(const Failure.network());
    return right([
      MessageReadReceipt(
        messageId: messageIds.single,
        members: const [
          MemberReadReceipt(
            membershipId: 'b',
            userId: 'bob',
            nickname: '阿博',
            status: ConversationReadStatus.read,
          ),
          MemberReadReceipt(
            membershipId: 'c',
            userId: 'c',
            nickname: '小陈',
            status: ConversationReadStatus.unread,
          ),
          MemberReadReceipt(
            membershipId: 'd',
            userId: 'd',
            nickname: '新成员',
            status: ConversationReadStatus.notApplicable,
          ),
        ],
      ),
    ]);
  }
}

void main() {
  Future<GlobalKey<NavigatorState>> mount(
    WidgetTester tester,
    _Timeline timeline,
    _Reads reads, {
    String user = 'alice',
    Widget Function(BuildContext, TimelineEntry, bool, ValueChanged<bool>)?
    photoBuilder,
  }) async {
    final key = GlobalKey<NavigatorState>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await timeline.changes.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            AsyncData(
              User(id: user, nickname: user, createdAt: DateTime.utc(2026)),
            ),
          ),
          conversationRepositoryProvider.overrideWithValue(timeline),
          conversationReadRepositoryProvider.overrideWithValue(reads),
        ],
        child: MaterialApp(
          navigatorKey: key,
          home: Scaffold(
            body: ConversationScreen(
              squadId: 'squad',
              squadName: '测试小队',
              onCreateCard: () {},
              photoBuilder: photoBuilder,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets(
    'photo loading or failed pixels never advance; decoded paint is required',
    (tester) async {
      final timeline = _Timeline();
      timeline.entries
        ..clear()
        ..add(
          TimelineEntry(
            id: 'photo',
            squadId: 'squad',
            authorId: 'bob',
            authorName: '队友',
            kind: TimelineEntryKind.photo,
            clientNonce: 'photo-nonce',
            createdAt: DateTime.utc(2026),
            photo: const PhotoAttachment(
              mediaId: 'media',
              width: 4,
              height: 3,
              byteLength: 600,
              isRevoked: false,
            ),
          ),
        );
      final reads = _Reads();
      late ValueChanged<bool> displayChanged;
      await mount(
        tester,
        timeline,
        reads,
        photoBuilder: (_, entry, canRead, callback) {
          displayChanged = callback;
          return const Text('照片正在加载');
        },
      );
      expect(reads.ids, isEmpty);
      displayChanged(false);
      await tester.pumpAndSettle();
      expect(reads.ids, isEmpty);
      displayChanged(true);
      await tester.pumpAndSettle();
      expect(reads.ids, ['photo']);
    },
  );

  testWidgets('visible foreground newest message advances once', (
    tester,
  ) async {
    final timeline = _Timeline();
    final reads = _Reads();
    await mount(tester, timeline, reads);
    expect(reads.ids, ['message-002']);
    await tester.pump();
    expect(reads.ids, ['message-002']);
  });

  testWidgets('background and unfocused views do not advance unseen arrivals', (
    tester,
  ) async {
    final timeline = _Timeline();
    final reads = _Reads();
    await mount(tester, timeline, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    timeline.add(3);
    await tester.pumpAndSettle();
    expect(reads.ids, ['message-002']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads.ids.last, 'message-003');
    tester.binding.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.unfocused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    timeline.add(4);
    await tester.pumpAndSettle();
    expect(reads.ids.last, 'message-003');
    tester.binding.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.focused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    await tester.pumpAndSettle();
    expect(reads.ids.last, 'message-004');
  });

  testWidgets(
    'a covering route blocks advances until the conversation is current',
    (tester) async {
      final timeline = _Timeline();
      final reads = _Reads();
      final navigator = await mount(tester, timeline, reads);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('遮挡页面')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      timeline.add(3);
      await tester.pumpAndSettle();
      expect(reads.ids, ['message-002']);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(reads.ids.last, 'message-003');
    },
  );

  testWidgets('scrolling history does not read new offscreen messages', (
    tester,
  ) async {
    final timeline = _Timeline()
      ..entries.addAll(List.generate(25, (i) => _message(i + 3)));
    final reads = _Reads();
    await mount(tester, timeline, reads);
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, 600));
    await tester.pumpAndSettle();
    final before = List.of(reads.ids);
    timeline.add(28);
    await tester.pumpAndSettle();
    expect(reads.ids, before);
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)).first,
    );
    // Scroll through the same real ScrollPosition instead of changing message data.
    scroll.position.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(reads.ids.last, 'message-028');
  });

  testWidgets(
    'only authors can open per-member details and joins are explicit',
    (tester) async {
      final timeline = _Timeline();
      final reads = _Reads();
      await mount(tester, timeline, reads);
      expect(find.text('已读明细'), findsOneWidget);
      await tester.tap(find.text('已读明细'));
      await tester.pumpAndSettle();
      expect(reads.requested, ['message-001']);
      expect(find.text('1/2 人已读'), findsOneWidget);
      expect(find.text('阿博'), findsOneWidget);
      expect(find.text('已读'), findsOneWidget);
      expect(find.text('未读'), findsOneWidget);
      expect(find.text('加入前消息 · 不计入统计'), findsOneWidget);
      timeline.add(3);
      await tester.pumpAndSettle();
      expect(reads.ids, ['message-002']);
      await tester.tap(find.byTooltip('关闭已读明细'));
      await tester.pumpAndSettle();
      expect(reads.ids.last, 'message-003');
    },
  );

  testWidgets('switching accounts hides an in-flight author receipt', (
    tester,
  ) async {
    final timeline = _Timeline();
    final reads = _Reads()..gate = Completer();
    await mount(tester, timeline, reads);
    await tester.tap(find.text('已读明细'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConversationScreen)),
    );
    container.updateOverrides([
      currentUserProvider.overrideWithValue(
        AsyncData(
          User(id: 'other', nickname: '另一个账号', createdAt: DateTime.utc(2026)),
        ),
      ),
      conversationRepositoryProvider.overrideWithValue(timeline),
      conversationReadRepositoryProvider.overrideWithValue(reads),
    ]);
    await tester.pump();
    reads.gate!.complete(
      right([
        const MessageReadReceipt(
          messageId: 'message-001',
          members: [
            MemberReadReceipt(
              membershipId: 'old',
              userId: 'old',
              nickname: '旧账号成员',
              status: ConversationReadStatus.read,
            ),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧账号成员'), findsNothing);
    expect(find.text('已读状态暂不可用'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭已读明细'));
    await tester.pumpAndSettle();
  });

  testWidgets('member details fit a narrow screen with large Chinese text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final timeline = _Timeline();
    final reads = _Reads();
    await mount(tester, timeline, reads);
    final button = find.text('已读明细');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('1/2 人已读'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭已读明细'));
    await tester.pumpAndSettle();
  });

  testWidgets('all members joined later has no misleading zero denominator', (
    tester,
  ) async {
    final timeline = _Timeline();
    final reads = _Reads()..gate = Completer();
    await mount(tester, timeline, reads);
    await tester.tap(find.text('已读明细'));
    await tester.pump();
    reads.gate!.complete(
      right([
        const MessageReadReceipt(
          messageId: 'message-001',
          members: [
            MemberReadReceipt(
              membershipId: 'new',
              userId: 'new',
              nickname: '后来加入',
              status: ConversationReadStatus.notApplicable,
            ),
          ],
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无计入统计的成员'), findsOneWidget);
    expect(find.text('0/0 人已读'), findsNothing);
    expect(find.text('加入前消息 · 不计入统计'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭已读明细'));
    await tester.pumpAndSettle();
  });

  testWidgets('receipt failures are unavailable and can be retried', (
    tester,
  ) async {
    final timeline = _Timeline();
    final reads = _Reads()..fail = true;
    await mount(tester, timeline, reads);
    await tester.tap(find.text('已读明细'));
    await tester.pumpAndSettle();
    expect(find.text('已读状态暂不可用'), findsOneWidget);
    expect(find.text('未读'), findsNothing);
    reads.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('1/2 人已读'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭已读明细'));
    await tester.pumpAndSettle();
  });
}
