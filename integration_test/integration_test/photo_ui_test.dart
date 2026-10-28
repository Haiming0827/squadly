import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/data/method_channel_photo_source.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/photos/presentation/photo_composer_screen.dart';
import 'package:squadly/features/photos/presentation/photo_message_view.dart';

import '../../test/features/photos/presentation/photo_test_helpers.dart';
import 'photo_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('VERIFY_PHOTO_UI_SIMULATOR');
  testWidgets(
    'iOS native camera failure, preview confirmation, retry and withdrawal UI',
    (tester) async {
      final h = PhotoHarness();
      h.source.handler = (source) => source == PhotoSource.camera
          ? const MethodChannelPhotoSource().pick(source)
          : Future.value(right(syntheticPhotoImage()));
      h.repository.onPublish = (_) async =>
          left(const Failure.network(message: '发送未确认，请重试'));
      await h.mount(
        tester,
        const PhotoComposerScreen(target: target),
        route: true,
      );
      await tester.tap(find.text('拍一张'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('待发送照片'), findsNothing);
      expect(h.repository.drafts, isEmpty);
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('待发送照片'), findsOneWidget);
      expect(h.repository.drafts, isEmpty);
      await binding.takeScreenshot('photo-ui-preview');
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(find.text('发送未确认，请重试'), findsOneWidget);
      await binding.takeScreenshot('photo-ui-retry');
      h.repository.onPublish = null;
      await tester.tap(find.text('发到「周末小队」'));
      await tester.pumpAndSettle();
      expect(h.routeResult, isTrue);
      expect(
        h.repository.drafts.first.clientNonce,
        h.repository.drafts.last.clientNonce,
      );

      h.repository.onLoad = () async => right(syntheticPhotoImage());
      var changed = false;
      await h.mount(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('周末小队')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PhotoMessageView(
                  squadId: target.squadId,
                  messageId: 'synthetic-message',
                  authorId: 'alice',
                  photo: attachment,
                  canRead: true,
                  onChanged: () => changed = true,
                  onReplyPhoto: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('小队照片'), findsOneWidget);
      await binding.takeScreenshot('photo-ui-message');
      await tester.tap(find.text('撤回照片'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤回'));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(find.text('照片已撤回'), findsOneWidget);
      await binding.takeScreenshot('photo-ui-withdrawn');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !Platform.isIOS || !verify,
  );
}
