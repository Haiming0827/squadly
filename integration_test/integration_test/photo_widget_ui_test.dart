import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/core/theme/app_theme.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_service.dart';
import 'package:squadly/features/photo_widget/presentation/photo_widget_entry_screen.dart';
import 'package:squadly/features/photo_widget/presentation/photo_widget_settings_screen.dart';
import 'package:squadly/features/photos/data/method_channel_photo_source.dart';
import 'package:squadly/features/photos/presentation/photo_composer_screen.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';

import '../../test/features/photos/presentation/photo_test_helpers.dart';
import 'photo_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('VERIFY_PHOTO_WIDGET_UI_SIMULATOR');
  testWidgets(
    'native widget settings and fixed entry to actual camera bridge',
    (tester) async {
      const store = NativePhotoWidgetStore();
      final now = DateTime.now().toUtc();
      final owner = PhotoWidgetContext(
        environmentId: 'isolated-widget-ui-fixture',
        userId: 'alice',
        expiresAt: now.add(const Duration(hours: 1)),
      );
      const message = '00000000-0000-4000-8000-000000000003';
      final photo = TimelineEntry(
        id: message,
        squadId: target.squadId,
        authorId: 'fixture-friend',
        authorName: '队友',
        kind: TimelineEntryKind.photo,
        clientNonce: 'fixture',
        createdAt: now,
        photo: attachment,
      );
      final service = PhotoWidgetService(
        store: store,
        context: () => owner,
        squad: (_, squadId) async => right(
          Squad(
            id: squadId,
            name: target.squadName,
            inviteCode: 'fixture',
            createdBy: 'alice',
            createdAt: now,
          ),
        ),
        latest: (_, _) async => right(PhotoHead(revision: '1', photo: photo)),
        find: (_, _, _) async => right(photo),
        load: (_, _, _) async => right(syntheticPhotoImage()),
      );
      await store.synchronize(scope: null, expiresAt: null);
      final prior = (await service.read()).getRight().toNullable();
      if (prior?.binding != null &&
          prior?.binding?.scope == prior?.lease?.scope) {
        await service.unbind(prior!);
      }
      expect((await service.bind(target.squadId)).isRight(), isTrue);
      final overrides = [
        photoWidgetServiceProvider.overrideWithValue(service),
        photoWidgetContextProvider.overrideWithValue(owner),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: PhotoWidgetSettingsScreen(
              squadId: target.squadId,
              squadName: target.squadName,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await binding.takeScreenshot('photo-ui-widget-hidden');
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final state = await store.read();
      expect(state.display, PhotoWidgetDisplay.photo);
      expect(find.text('照片已交给系统更新，桌面显示时间由 iOS 决定'), findsOneWidget);
      await binding.takeScreenshot('photo-ui-widget-updated');

      final entry = PhotoWidgetEntry(
        squadId: target.squadId,
        bindingId: state.binding!.id,
        scope: state.binding!.scope,
        messageId: message,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final h = PhotoHarness();
      h.source.handler = (source) =>
          const MethodChannelPhotoSource().pick(source);
      await h.mount(
        tester,
        ProviderScope(
          overrides: overrides,
          child: PhotoWidgetEntryScreen(
            entry: entry,
            cameraBuilder: (target) =>
                PhotoComposerScreen(target: target, autoOpenCamera: true),
          ),
        ),
        route: true,
      );
      expect(find.text('回拍照片'), findsOneWidget);
      expect(find.text('仅「周末小队」成员可见'), findsOneWidget);
      expect(h.source.calls, hasLength(1));
      expect(h.repository.drafts, isEmpty);
      await binding.takeScreenshot('photo-ui-widget-camera-entry');
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      await store.synchronize(scope: null, expiresAt: null);
    },
    skip: !Platform.isIOS || !verify,
  );
}
