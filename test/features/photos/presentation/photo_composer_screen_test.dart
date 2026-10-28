import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/domain/photo_submission.dart';
import 'package:squadly/features/photos/presentation/photo_composer_screen.dart';

import 'photo_test_helpers.dart';

void main() {
  testWidgets(
    'widget entry opens camera once and still requires explicit send',
    (tester) async {
      final h = PhotoHarness();
      await h.mount(
        tester,
        const PhotoComposerScreen(target: target, autoOpenCamera: true),
      );
      expect(h.source.calls, [PhotoSource.camera]);
      expect(h.repository.drafts, isEmpty);
      await tester.pump();
      expect(h.source.calls, [PhotoSource.camera]);
      expect(find.text('发到「周末小队」'), findsOneWidget);
    },
  );
  testWidgets(
    'uncertain local save never claims durable queuing and locks the confirmed image',
    (tester) async {
      final h = PhotoHarness();
      h.submit = (_) async => const PhotoSubmissionResult.unconfirmed(
        Failure.server(message: '存储暂不可用'),
      );
      await h.mount(tester, const PhotoComposerScreen(target: target));
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(find.text('本机保存尚未确认，请使用原照片重试'), findsOneWidget);
      expect(find.text('已保存待发，联网后会继续重试'), findsNothing);
      await tester.tap(find.text('从相册选择'));
      await tester.pump();
      expect(h.source.calls, [PhotoSource.camera]);
      expect(
        await h.outbox.listFor(userId: 'alice', squadId: target.squadId),
        isEmpty,
      );
    },
  );

  testWidgets(
    'definite rejection before confirmation persistence allows choosing a fresh image',
    (tester) async {
      final h = PhotoHarness();
      h.submit = (_) async => const PhotoSubmissionResult.rejected(
        Failure.validation(message: '当前无法确认照片'),
      );
      await h.mount(tester, const PhotoComposerScreen(target: target));
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(h.source.calls, [PhotoSource.camera, PhotoSource.library]);
      expect(
        await h.outbox.listFor(userId: 'alice', squadId: target.squadId),
        isEmpty,
      );
    },
  );
  testWidgets(
    'selection previews a fixed target; only explicit send publishes',
    (tester) async {
      final h = PhotoHarness();
      const parent = '00000000-0000-4000-8000-000000000003';
      final reply = target.copyWith(replyToMessageId: parent);
      await h.mount(tester, PhotoComposerScreen(target: reply), route: true);
      expect(h.source.calls, isEmpty);
      expect(h.repository.drafts, isEmpty);
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('待发送照片'), findsOneWidget);
      expect(h.repository.drafts, isEmpty);
      expect(h.accesses, everyElement(reply));
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(h.repository.drafts.single.target, reply);
      expect(h.routeResult, isTrue);
    },
  );

  testWidgets(
    'failed delivery retains exactly the same draft and nonce for retry',
    (tester) async {
      final h = PhotoHarness();
      h.repository.onPublish = (_) async =>
          left(const Failure.network(message: '发送未确认'));
      await h.mount(
        tester,
        const PhotoComposerScreen(target: target),
        route: true,
      );
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(find.text('发送未确认'), findsOneWidget);
      h.repository.onPublish = null;
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(h.repository.drafts, hasLength(2));
      expect(
        sameConfirmedPhoto(h.repository.drafts.first, h.repository.drafts.last),
        isTrue,
      );
      expect(h.routeResult, isTrue);
    },
  );

  testWidgets(
    'cancel preserves preview; replacement before confirmation gets a fresh nonce',
    (tester) async {
      final h = PhotoHarness();
      await h.mount(tester, const PhotoComposerScreen(target: target));
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      final original = tester.widget<Image>(find.byType(Image)).key;
      h.source.handler = (_) async => right(null);
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).key, original);
      h.source.handler = null;
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).key, isNot(original));
      expect(h.repository.drafts, isEmpty);
      expect(
        await h.outbox.listFor(userId: 'alice', squadId: target.squadId),
        isEmpty,
      );
    },
  );

  testWidgets(
    'confirmed pending photo is durable and cannot be silently replaced',
    (tester) async {
      final h = PhotoHarness();
      h.repository.onPublish = (_) async => left(const Failure.network());
      await h.mount(tester, const PhotoComposerScreen(target: target));
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(find.text('已保存待发，联网后会继续重试'), findsOneWidget);
      final pending = await h.outbox.listFor(
        userId: 'alice',
        squadId: target.squadId,
      );
      expect(pending, hasLength(1));
      await tester.tap(find.text('从相册选择'));
      await tester.pump();
      expect(h.source.calls, [PhotoSource.camera]);
      expect(h.repository.drafts, hasLength(1));
    },
  );

  testWidgets('camera denial leaves library available and never publishes', (
    tester,
  ) async {
    final h = PhotoHarness();
    h.source.handler = (source) async => source == PhotoSource.camera
        ? left(const Failure.permissionDenied(message: '请允许使用相机'))
        : right(testImage());
    await h.mount(tester, const PhotoComposerScreen(target: target));
    await tester.tap(find.text('拍一张'));
    await tester.pumpAndSettle();
    expect(find.text('请允许使用相机'), findsOneWidget);
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('待发送照片'), findsOneWidget);
    expect(h.repository.drafts, isEmpty);
  });

  testWidgets('a second send tap cannot start another in-flight upload', (
    tester,
  ) async {
    final h = PhotoHarness();
    final pending = Completer<Either<Failure, PublishedPhoto>>();
    h.repository.onPublish = (_) => pending.future;
    await h.mount(tester, const PhotoComposerScreen(target: target));
    await tester.tap(find.text('拍一张'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发到「周末小队」'));
    await tester.pump();
    await tester.tap(find.text('正在处理…'));
    await tester.pump();
    expect(h.repository.drafts, hasLength(1));
    pending.complete(left(const Failure.network()));
    await tester.pumpAndSettle();
  });

  testWidgets('lost membership after preview rejects send without uploading', (
    tester,
  ) async {
    final h = PhotoHarness();
    await h.mount(tester, const PhotoComposerScreen(target: target));
    await tester.tap(find.text('拍一张'));
    await tester.pumpAndSettle();
    h.allowed = false;
    await tester.tap(find.text('发到「周末小队」'));
    await tester.pumpAndSettle();
    expect(h.repository.drafts, isEmpty);
    expect(find.text('当前无法确认原小队权限，照片仍在待发'), findsOneWidget);
  });

  for (final phase in ['picker', 'upload']) {
    testWidgets(
      'account switch during $phase discards late response and preview',
      (tester) async {
        final h = PhotoHarness();
        final pick = Completer<Either<Failure, PhotoImage?>>();
        final upload = Completer<Either<Failure, PublishedPhoto>>();
        if (phase == 'picker') h.source.handler = (_) => pick.future;
        h.repository.onPublish = (_) => upload.future;
        await h.mount(
          tester,
          const PhotoComposerScreen(target: target),
          route: true,
        );
        await tester.tap(find.text('拍一张'));
        await tester.pump();
        if (phase == 'upload') {
          await tester.pumpAndSettle();
          await tester.tap(find.text('发到「周末小队」'));
          await tester.pump();
        }
        h.container.read(testUser.notifier).state = 'bob';
        await tester.pump();
        if (phase == 'picker') {
          pick.complete(right(testImage()));
        } else {
          final draft = h.repository.drafts.single;
          upload.complete(
            right(
              PublishedPhoto(
                messageId: 'message',
                mediaId: 'media',
                squadId: draft.target.squadId,
                authorId: 'alice',
                clientNonce: draft.clientNonce,
                publishedAt: DateTime.utc(2026),
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('待发送照片'), findsNothing);
        expect(h.routeResult, isNull);
        expect(find.text('请返回原账号并联网登录后继续'), findsOneWidget);
        h.container.read(testUser.notifier).state = 'alice';
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('待发送照片'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      },
    );
  }

  testWidgets(
    'preview hides in background and returns for the original account',
    (tester) async {
      final h = PhotoHarness();
      await h.mount(tester, const PhotoComposerScreen(target: target));
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.bySemanticsLabel('待发送照片'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('待发送照片'), findsOneWidget);
      expect(h.repository.drafts, isEmpty);
    },
  );

  testWidgets('unavailable service disables capture and send', (tester) async {
    final h = PhotoHarness();
    await h.mount(tester, const PhotoComposerScreen(target: target));
    h.container.read(testAvailable.notifier).state = false;
    await tester.pump();
    await tester.tap(find.text('拍一张'));
    await tester.pump();
    expect(h.source.calls, isEmpty);
    expect(find.text('当前版本的照片服务暂不可用'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'small screen and long Chinese target remain usable at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = PhotoHarness();
      await h.mount(
        tester,
        PhotoComposerScreen(
          target: target.copyWith(squadName: '这是一个名称很长的周末跑步徒步亲友小队'),
        ),
      );
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('待发送照片'), findsOneWidget);
    },
  );
}
