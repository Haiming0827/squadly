import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photos/domain/photo.dart';

import 'photo_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('VERIFY_PHOTO_WIDGET_SIMULATOR');
  const store = NativePhotoWidgetStore();
  const squad = '00000000-0000-4000-8000-000000000001';
  const message = '00000000-0000-4000-8000-000000000003';
  final scope = 'a' * 64;
  Future<PhotoWidgetSnapshot> bind({
    Duration lease = const Duration(hours: 1),
  }) async {
    final session = await store.synchronize(
      scope: scope,
      expiresAt: DateTime.now().toUtc().add(lease),
    );
    return store.bind(
      lease: session.lease!,
      squadId: squad,
      squadName: '组件验收小队',
    );
  }

  Future<PhotoWidgetSnapshot> photo(PhotoWidgetSnapshot state) async {
    final preview = await store.setPreview(expected: state, enabled: true);
    return store.setPhoto(
      expected: preview,
      messageId: message,
      createdAt: DateTime.now().toUtc(),
      image: syntheticPhotoImage(),
    );
  }

  testWidgets(
    'actual iOS App Group bridge preserves privacy and rejects stale receipts',
    (tester) async {
      expect(await store.isAvailable(), isTrue);
      // This asks WidgetCenter. Availability/binding never counts as installation.
      expect(await store.installedCount(), greaterThanOrEqualTo(0));
      await store.synchronize(scope: null, expiresAt: null);
      var state = await bind();
      expect(state.scheme, 'squadly-test');
      expect(state.binding!.previewEnabled, isFalse);
      expect(state.display, PhotoWidgetDisplay.hidden);
      final original = await photo(state);
      expect(original.display, PhotoWidgetDisplay.photo);
      expect(original.messageId, message);
      expect(
        original.photoExpiresAt!.difference(DateTime.now()).inSeconds,
        lessThanOrEqualTo(900),
      );
      expect((await store.read()).messageId, message);
      final entry = TimelineEntry(
        id: message,
        squadId: squad,
        authorId: 'fixture',
        authorName: '队友',
        kind: TimelineEntryKind.photo,
        clientNonce: 'fixture',
        createdAt: DateTime.now().toUtc(),
        photo: PhotoAttachment(
          mediaId: 'fixture',
          width: 4,
          height: 3,
          byteLength: syntheticPhotoImage().bytes.length,
          isRevoked: false,
        ),
      );
      final versioned = await store.applyHead(
        expected: original,
        head: PhotoHead(revision: '9007199254740993', photo: entry),
        image: syntheticPhotoImage(),
      );
      expect(versioned.messageId, message);
      final duplicate = await store.applyHead(
        expected: versioned,
        head: PhotoHead(revision: '9007199254740993', photo: entry),
        image: syntheticPhotoImage(),
      );
      expect(duplicate.photoExpiresAt, versioned.photoExpiresAt);
      final empty = await store.applyHead(
        expected: versioned,
        head: const PhotoHead(revision: '9007199254740994'),
      );
      expect(empty.display, PhotoWidgetDisplay.empty);
      expect(empty.messageId, isNull);
      await expectLater(
        store.applyHead(
          expected: versioned,
          head: PhotoHead(revision: '9007199254740993', photo: entry),
          image: syntheticPhotoImage(),
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'stale'),
        ),
      );
      final off = await store.setPreview(expected: original, enabled: false);
      final on = await store.setPreview(expected: off, enabled: true);
      expect(on.messageId, isNull);
      await expectLater(
        store.setPhoto(
          expected: original,
          messageId: message,
          createdAt: DateTime.now(),
          image: syntheticPhotoImage(),
        ),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'stale'),
        ),
      );
      state = await store.synchronize(
        scope: 'b' * 64,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(state.messageId, isNull);
      expect(state.display, PhotoWidgetDisplay.signedOut);
      await expectLater(
        store.setPreview(expected: on, enabled: false),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'stale'),
        ),
      );

      await store.synchronize(scope: null, expiresAt: null);
      state = await bind(lease: const Duration(seconds: 3));
      state = await photo(state);
      expect(state.photoExpiresAt!.isAfter(state.lease!.expiresAt), isFalse);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      state = await store.read();
      expect(state.messageId, isNull);
      expect(state.display, PhotoWidgetDisplay.signedOut);
      await store.synchronize(scope: null, expiresAt: null);
    },
    skip: !Platform.isIOS || !enabled,
  );
}
