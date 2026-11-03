import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/photo_safety_repository.dart';

import 'photo_message_view_test.dart' show view;
import 'photo_test_helpers.dart';

Future<void> menu(WidgetTester tester, String text) async {
  await tester.tap(find.byTooltip('照片选项'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'receiver hiding is confirmed, clears pixels and survives resume',
    (tester) async {
      final h = PhotoHarness();
      var changed = 0;
      await h.mount(tester, view(authorId: 'bob', onChanged: () => changed++));
      await menu(tester, '隐藏照片');
      expect(h.repository.hides, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(h.repository.hides, isEmpty);
      await menu(tester, '隐藏照片');
      await tester.tap(find.text('隐藏'));
      await tester.pumpAndSettle();
      expect(h.repository.hides, ['message']);
      expect(changed, 1);
      expect(find.text('照片已对你隐藏'), findsOneWidget);
      expect(find.bySemanticsLabel('小队照片'), findsNothing);
      expect(find.byTooltip('照片选项'), findsNothing);
      final count = h.repository.loads.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.repository.loads.length, count);
    },
  );

  testWidgets('report requires a reason and confirmation and also hides', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(tester, view(authorId: 'bob'));
    await menu(tester, '举报照片');
    expect(h.repository.reports, isEmpty);
    await tester.tap(find.text('泄露隐私'));
    await tester.pumpAndSettle();
    expect(h.repository.reports, isEmpty);
    await tester.tap(find.text('举报并隐藏'));
    await tester.pumpAndSettle();
    expect(h.repository.reports, [PhotoReportReason.privacy]);
    expect(find.text('举报已提交'), findsOneWidget);
    expect(find.text('照片已对你隐藏'), findsOneWidget);
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
  });

  testWidgets('server failure is not shown as a successful report', (
    tester,
  ) async {
    final h = PhotoHarness();
    h.repository.onSafety = () async =>
        left(const Failure.permissionDenied(message: '当前无法操作'));
    await h.mount(tester, view(authorId: 'bob'));
    await menu(tester, '举报照片');
    await tester.tap(find.text('其他问题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('举报并隐藏'));
    await tester.pumpAndSettle();
    expect(find.text('举报已提交'), findsNothing);
    expect(find.text('照片已对你隐藏'), findsNothing);
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
    expect(find.text('当前无法操作'), findsOneWidget);
  });

  testWidgets('old account hide completion cannot confirm in the new account', (
    tester,
  ) async {
    final h = PhotoHarness();
    var changes = 0;
    final result = Completer<Either<Failure, void>>();
    h.repository.onSafety = () => result.future;
    await h.mount(tester, view(authorId: 'bob', onChanged: () => changes++));
    await menu(tester, '隐藏照片');
    await tester.tap(find.text('隐藏'));
    await tester.pump();
    h.container.read(testUser.notifier).state = 'charlie';
    await tester.pump();
    result.complete(right(null));
    await tester.pumpAndSettle();
    expect(changes, 0);
    expect(find.text('照片已对你隐藏'), findsNothing);
    expect(find.bySemanticsLabel('小队照片'), findsNothing);
  });

  testWidgets(
    'report controls fit a narrow screen with enlarged Chinese text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = PhotoHarness();
      h.repository.onLoad = () async => left(const Failure.network());
      await h.mount(
        tester,
        SingleChildScrollView(child: view(authorId: 'bob')),
      );
      await menu(tester, '举报照片');
      expect(find.text('举报原因'), findsOneWidget);
      await tester.ensureVisible(find.text('泄露隐私'));
      await tester.tap(find.text('泄露隐私'));
      await tester.pumpAndSettle();
      expect(find.text('举报并隐藏这张照片？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(h.repository.reports, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('persisted hidden tombstone never downloads or offers a reply', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(
      tester,
      view(
        authorId: 'bob',
        photo: attachment.copyWith(isHidden: true),
        onReply: () => fail('hidden reply'),
      ),
    );
    expect(h.repository.loads, isEmpty);
    expect(find.text('照片已对你隐藏'), findsOneWidget);
    expect(find.text('回拍一张'), findsNothing);
    expect(find.byTooltip('照片选项'), findsNothing);
  });
}
