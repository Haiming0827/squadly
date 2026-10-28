import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

// Synthetic local JWT, deliberately no server authentication or network access.
String _token(DateTime expiry) {
  String encode(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'RS256'})}.${encode({'sub': 'background-fixture', 'role': 'authenticated', 'exp': expiry.millisecondsSinceEpoch ~/ 1000, 'is_system_admin': false})}.${base64UrlEncode(List.filled(32, 42)).replaceAll('=', '')}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment(
    'VERIFY_PHOTO_BACKGROUND_CREDENTIALS_SIMULATOR',
  );
  const phase = String.fromEnvironment(
    'PHOTO_BACKGROUND_CREDENTIAL_PHASE',
    defaultValue: 'all',
  );
  const widget = NativePhotoWidgetStore();
  const bridge = NativePhotoBackgroundCredentialBridge();
  const channel = MethodChannel('squadly/photo-background');
  testWidgets(
    'actual private Keychain credential $phase, isolated from widget group',
    (tester) async {
      expect(await widget.isAvailable(), isTrue);
      if (phase != 'verify') {
        await widget.synchronize(scope: null, expiresAt: null);
        await bridge.clear();
        expect(await channel.invokeMethod<bool>('status'), isFalse);
        final owner = PhotoWidgetContext(
          environmentId: 'fixture-env',
          userId: 'background-fixture',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 20)),
        );
        final session = await widget.synchronize(
          scope: await photoWidgetScope(owner),
          expiresAt: owner.expiresAt,
        );
        final bound = await widget.bind(
          lease: session.lease!,
          squadId: '00000000-0000-4000-8000-000000000001',
          squadName: '凭据隔离验收队',
        );
        await expectLater(
          bridge.prepare(bound),
          throwsA(isA<PlatformException>()),
        );
        final visible = await widget.setPreview(expected: bound, enabled: true);
        final ticket = await bridge.prepare(visible);
        final token = _token(owner.expiresAt);
        await bridge.commit(
          ticket,
          PhotoBackgroundCredentialMaterial(
            environmentId: owner.environmentId,
            region: 'ap-shanghai',
            userId: owner.userId,
            gateway: Uri.parse(
              'https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos',
            ),
            accessToken: token,
            expiresAt: owner.expiresAt,
          ),
        );
        expect(await channel.invokeMethod<bool>('status'), isTrue);
        await expectLater(
          channel.invokeMethod<bool>('commit', {
            'ticket': ticket,
            'refreshToken': 'forbidden-fixture',
          }),
          throwsA(isA<PlatformException>()),
        );
        expect(await channel.invokeMethod<bool>('status'), isTrue);
        if (phase == 'seed') return;
      }
      // A separate Flutter process with --no-uninstall must observe the same
      // private Keychain item and current binding, not a Dart in-memory fixture.
      expect(await channel.invokeMethod<bool>('status'), isTrue);
      final current = await widget.read();
      expect(current.binding?.previewEnabled, isTrue);
      final pending = await bridge.prepare(current);
      await widget.setPreview(expected: current, enabled: false);
      expect(await channel.invokeMethod<bool>('status'), isFalse);
      await bridge.cancel(pending);
      await widget.synchronize(scope: null, expiresAt: null);
      await bridge.clear();
      expect(await channel.invokeMethod<bool>('status'), isFalse);
    },
    skip: !Platform.isIOS || !verify,
  );
}
