import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:squadly/features/photos/domain/photo_safety_repository.dart';
import 'package:squadly/features/photos/presentation/photo_message_view.dart';

import '../../test/features/photos/presentation/photo_test_helpers.dart';
import 'photo_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('VERIFY_PHOTO_SAFETY_UI_SIMULATOR');
  testWidgets(
    'iOS receiver confirms hide and report without publishing or copying media',
    (tester) async {
      final h = PhotoHarness();
      h.repository.onLoad = () async => right(syntheticPhotoImage());
      Widget screen(String message) => Scaffold(
        appBar: AppBar(title: const Text('周末小队')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('队友 · 合成验收照片'),
              PhotoMessageView(
                key: ValueKey(message),
                squadId: target.squadId,
                messageId: message,
                authorId: 'bob',
                photo: attachment,
                canRead: true,
                onChanged: () {},
                onReplyPhoto: () {},
              ),
            ],
          ),
        ),
      );
      await h.mount(tester, screen('hide-fixture'));
      await tester.tap(find.byTooltip('照片选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('隐藏照片'));
      await tester.pumpAndSettle();
      expect(h.repository.hides, isEmpty);
      await binding.takeScreenshot('photo-ui-safety-hide-confirm');
      await tester.tap(find.text('隐藏'));
      await tester.pumpAndSettle();
      expect(h.repository.hides, ['hide-fixture']);
      expect(find.bySemanticsLabel('小队照片'), findsNothing);
      expect(find.text('照片已对你隐藏'), findsOneWidget);
      await binding.takeScreenshot('photo-ui-safety-hidden');
      await h.mount(tester, screen('report-fixture'));
      await tester.tap(find.byTooltip('照片选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('举报照片'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('photo-ui-safety-report-reason');
      await tester.tap(find.text('泄露隐私'));
      await tester.pumpAndSettle();
      expect(h.repository.reports, isEmpty);
      await tester.tap(find.text('举报并隐藏'));
      await tester.pumpAndSettle();
      expect(h.repository.reports, [PhotoReportReason.privacy]);
      expect(find.text('举报已提交'), findsOneWidget);
      expect(find.bySemanticsLabel('小队照片'), findsNothing);
      expect(h.repository.drafts, isEmpty);
      await binding.takeScreenshot('photo-ui-safety-reported');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: !Platform.isIOS || !verify,
  );
}
