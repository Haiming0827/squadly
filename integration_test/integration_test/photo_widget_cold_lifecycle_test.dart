import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/features/conversation/domain/photo_head.dart';
import 'package:squadly/features/photos/domain/photo.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_lifecycle.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget_service.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/squad/domain/entities/squad.dart';

import 'photo_fixture.dart';

String token(DateTime expiry) {
  String encode(Object v) =>
      base64UrlEncode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${encode({'alg': 'RS256'})}.${encode({'sub': 'cold-session-fixture', 'role': 'authenticated', 'is_system_admin': false, 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.${base64UrlEncode(List.filled(32, 42)).replaceAll('=', '')}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('VERIFY_WIDGET_COLD_LIFECYCLE');
  const phase = String.fromEnvironment(
    'WIDGET_COLD_PHASE',
    defaultValue: 'all',
  );
  const store = NativePhotoWidgetStore();
  const bridge = NativePhotoBackgroundCredentialBridge();
  const channel = MethodChannel('squadly/photo-background');
  testWidgets(
    'actual persisted widget and Keychain survive cold restoration $phase',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      if (phase != 'verify') {
        await bridge.clear();
        await store.synchronize(scope: null, expiresAt: null);
        final expiry = DateTime.now().toUtc().add(const Duration(minutes: 20));
        await prefs.setInt(
          'widget_cold_synthetic_expiry',
          expiry.millisecondsSinceEpoch,
        );
        final owner = PhotoWidgetContext(
          environmentId: 'fixture-env',
          userId: 'cold-session-fixture',
          expiresAt: expiry,
        );
        final synced = await store.synchronize(
          scope: await photoWidgetScope(owner),
          expiresAt: expiry,
        );
        final bound = await store.bind(
          lease: synced.lease!,
          squadId: '00000000-0000-4000-8000-000000000001',
          squadName: '冷启动验收队',
        );
        final visible = await store.setPreview(expected: bound, enabled: true);
        final image = syntheticPhotoImage();
        final photo = TimelineEntry(
          id: '00000000-0000-4000-8000-000000000002',
          squadId: bound.binding!.squadId,
          authorId: 'synthetic-friend',
          authorName: '合成队友',
          kind: TimelineEntryKind.photo,
          clientNonce: 'synthetic-nonce',
          createdAt: DateTime.now(),
          photo: PhotoAttachment(
            mediaId: 'synthetic-media',
            width: image.width,
            height: image.height,
            byteLength: image.bytes.length,
            isRevoked: false,
          ),
        );
        final withPhoto = await store.applyHead(
          expected: visible,
          head: PhotoHead(revision: '1', photo: photo),
          image: image,
        );
        final ticket = await bridge.prepare(withPhoto);
        await bridge.commit(
          ticket,
          PhotoBackgroundCredentialMaterial(
            environmentId: owner.environmentId,
            region: 'ap-shanghai',
            userId: owner.userId,
            gateway: Uri.parse(
              'https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos',
            ),
            accessToken: token(expiry),
            expiresAt: expiry,
          ),
        );
        expect(await channel.invokeMethod<bool>('status'), isTrue);
        if (phase == 'seed') return;
      }
      final owner = PhotoWidgetContext(
        environmentId: 'fixture-env',
        userId: 'cold-session-fixture',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt('widget_cold_synthetic_expiry')!,
          isUtc: true,
        ),
      );
      final before = await store.read();
      expect(before.display, PhotoWidgetDisplay.photo);
      expect(await channel.invokeMethod<bool>('status'), isTrue);
      final started = Completer<void>();
      final head = Completer<Either<Failure, PhotoHead>>();
      var loads = 0;
      var lookups = 0;
      final service = PhotoWidgetService(
        store: store,
        context: () => owner,
        squad: (_, id) async {
          lookups++;
          return right(
            Squad(
              id: id,
              name: '合成冷启动小队',
              inviteCode: 'synthetic',
              createdBy: owner.userId,
              createdAt: DateTime.utc(2026),
            ),
          );
        },
        latest: (_, _) {
          if (!started.isCompleted) started.complete();
          return head.future;
        },
        find: (_, _, _) async => right(null),
        load: (_, _, _) async {
          loads++;
          return right(syntheticPhotoImage());
        },
      );
      // Membership is separately covered against real A/B/C HTTP. For this cold
      // cache test, omit fetching a Squad by using the restoration path first.
      final lifecycle = PhotoWidgetLifecycle(
        store: store,
        service: service,
        clearCredentials: bridge.clear,
      );
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.restoring,
        context: null,
      ), foreground: false);
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.restoring,
        context: owner,
      ), foreground: false);
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.ready,
        context: owner,
      ), foreground: false);
      final restored = await store.read();
      expect(restored.messageId, before.messageId);
      expect(restored.lease!.generation, before.lease!.generation);
      expect(restored.photoExpiresAt, before.photoExpiresAt);
      expect(await channel.invokeMethod<bool>('status'), isTrue);
      expect(loads, 0);
      expect(lookups, 0);
      expect(started.isCompleted, isFalse);
      final fetching = lifecycle.accept((
        mode: PhotoWidgetAccessMode.ready,
        context: owner,
      ), foreground: true);
      await started.future.timeout(const Duration(seconds: 5));
      expect((await store.read()).messageId, before.messageId);
      expect((await store.read()).lease!.generation, before.lease!.generation);
      expect(await channel.invokeMethod<bool>('status'), isTrue);
      await lifecycle.accept((
        mode: PhotoWidgetAccessMode.blocked,
        context: null,
      ), foreground: true);
      expect((await store.read()).messageId, isNull);
      expect((await store.read()).lease, isNull);
      expect(await channel.invokeMethod<bool>('status'), isFalse);
      head.complete(right(const PhotoHead(revision: '2')));
      await fetching;
      expect((await store.read()).messageId, isNull);
      expect((await store.read()).lease, isNull);
      lifecycle.dispose();
      service.dispose();
      await prefs.remove('widget_cold_synthetic_expiry');
    },
    skip: !Platform.isIOS || !verify,
  );
}
