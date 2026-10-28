import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/presentation/photo_message_view.dart';

import 'photo_test_helpers.dart';

PhotoMessageView view({
  bool canRead = true,
  PhotoAttachment photo = attachment,
  VoidCallback? onReply,
  VoidCallback? onChanged,
  ValueChanged<bool>? onDisplayChanged,
  String authorId = 'alice',
}) => PhotoMessageView(
  squadId: target.squadId,
  messageId: 'message',
  authorId: authorId,
  photo: photo,
  canRead: canRead,
  onChanged: onChanged ?? () {},
  onReplyPhoto: onReply,
  onDisplayChanged: onDisplayChanged,
);

void main() {
  testWidgets(
    'current online member loads exactly the original squad and message',
    (tester) async {
      final h = PhotoHarness();
      var replies = 0;
      final prepared = testImage();
      h.repository.onLoad = () async => right(prepared);
      final displayed = <bool>[];
      await h.mount(
        tester,
        view(onReply: () => replies++, onDisplayChanged: displayed.add),
      );
      expect(h.repository.loads.single, (
        squadId: target.squadId,
        messageId: 'message',
      ));
      expect(find.bySemanticsLabel('小队照片'), findsOneWidget);
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(prepared.bytes),
          tester.element(find.byType(PhotoMessageView)),
        ),
      );
      await tester.pumpAndSettle();
      expect(displayed, [true]);
      await tester.tap(find.text('回拍一张'));
      await tester.pump();
      expect(replies, 1);
    },
  );

  for (final revoked in [false, true]) {
    testWidgets(
      '${revoked ? 'revoked' : 'cached'} photo never fetches bytes or offers reply',
      (tester) async {
        final h = PhotoHarness();
        await h.mount(
          tester,
          view(
            canRead: revoked,
            photo: attachment.copyWith(isRevoked: revoked),
            onReply: () => fail('No reply'),
          ),
        );
        expect(h.repository.loads, isEmpty);
        expect(find.text('回拍一张'), findsNothing);
        expect(find.bySemanticsLabel('小队照片'), findsNothing);
        expect(find.text(revoked ? '照片已撤回' : '照片需联网登录后查看'), findsOneWidget);
      },
    );
  }

  testWidgets('account change rejects an old in-flight image', (tester) async {
    final h = PhotoHarness();
    final response = Completer<Either<Failure, PhotoImage>>();
    h.repository.onLoad = () => response.future;
    // An indeterminate progress bar cannot pumpAndSettle while loading.
    await h.mount(tester, view(), settle: false);
    h.container.read(testUser.notifier).state = 'bob';
    await tester.pump();
    response.complete(right(testImage()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
    expect(h.repository.loads, hasLength(1));
  });

  testWidgets('session expiry clears pixels and blocks further requests', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(tester, view());
    h.container.read(testReady.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
    expect(find.text('照片需联网登录后查看'), findsOneWidget);
    expect(h.repository.loads, hasLength(1));
  });

  testWidgets('background clears pixels and resume obtains new authorization', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(tester, view());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.repository.loads, hasLength(2));
    expect(find.bySemanticsLabel('小队照片'), findsOneWidget);
  });

  testWidgets('one-minute view lease clears image without background polling', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(tester, view());
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
    expect(h.repository.loads, hasLength(1));
    await tester.tap(find.text('照片预览已到期，点按重新加载'));
    await tester.pumpAndSettle();
    expect(h.repository.loads, hasLength(2));
    expect(find.bySemanticsLabel('小队照片'), findsOneWidget);
  });

  testWidgets(
    'author withdrawal requires confirmation and becomes a tombstone',
    (tester) async {
      final h = PhotoHarness();
      var changed = 0;
      await h.mount(tester, view(onChanged: () => changed++));
      await tester.tap(find.text('撤回照片'));
      await tester.pumpAndSettle();
      expect(h.repository.revokes, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(h.repository.revokes, isEmpty);
      await tester.tap(find.text('撤回照片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤回'));
      await tester.pumpAndSettle();
      expect(h.repository.revokes.single, (
        squadId: target.squadId,
        messageId: 'message',
      ));
      expect(find.text('照片已撤回'), findsOneWidget);
      expect(find.bySemanticsLabel('小队照片'), findsNothing);
      expect(changed, 1);
    },
  );

  testWidgets(
    'non-author cannot withdraw; permission failure exposes no pixels',
    (tester) async {
      final h = PhotoHarness();
      h.repository.onLoad = () async =>
          left(const Failure.permissionDenied(message: '当前无法查看照片'));
      await h.mount(tester, view(authorId: 'bob'));
      expect(find.text('撤回照片'), findsNothing);
      expect(find.text('当前无法查看照片'), findsOneWidget);
      expect(find.bySemanticsLabel('小队照片'), findsNothing);
    },
  );
}
