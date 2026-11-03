import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/features/photo_widget/data/native_photo_widget_store.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

import 'photo_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('VERIFY_NATIVE_PHOTO_STAGING');
  const phase = String.fromEnvironment(
    'NATIVE_PHOTO_FETCH_PHASE',
    defaultValue: 'all',
  );
  const widget = NativePhotoWidgetStore();
  const bridge = NativePhotoBackgroundCredentialBridge();
  const channel = MethodChannel('squadly/photo-background');
  testWidgets(
    'actual native HTTPS photo fetch $phase with ordinary staging user',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      if (phase != 'verify') {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/native-photo-fetch-fixture.json');
        expect(
          await file.exists(),
          isTrue,
          reason: 'Private fixture must be provisioned separately, never in dart-defines.',
        );
        expect((await file.stat()).mode & 0x1ff, 0x180);
        late Map<String, dynamic> fixture;
        try {
          fixture =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        } finally {
          await file.delete();
        }
        expect(
          fixture['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c',
          isTrue,
        );
        final token = fixture['accessToken'] as String;
        final claims = jsonDecode(
          utf8.decode(
            base64Url.decode(base64Url.normalize(token.split('.')[1])),
          ),
        ) as Map;
        expect(
          claims['sub'] == fixture['userId'] &&
              {'user', 'authenticated'}.contains(claims['role']) &&
              claims['is_system_admin'] != true,
          isTrue,
        );
        final expiry = DateTime.fromMillisecondsSinceEpoch(
          (claims['exp'] as num).toInt() * 1000,
          isUtc: true,
        );
        expect(
          expiry.isAfter(DateTime.now().add(const Duration(minutes: 2))),
          isTrue,
        );
        final owner = PhotoWidgetContext(
          environmentId: fixture['environmentId'] as String,
          userId: fixture['userId'] as String,
          expiresAt: expiry,
        );
        await widget.synchronize(scope: null, expiresAt: null);
        await bridge.clear();
        final session = await widget.synchronize(
          scope: await photoWidgetScope(owner),
          expiresAt: owner.expiresAt,
        );
        final bound = await widget.bind(
          lease: session.lease!,
          squadId: fixture['squadId'] as String,
          squadName: '后台合成照片验收队',
        );
        final visible = await widget.setPreview(expected: bound, enabled: true);
        final expectDenied = fixture['expectMemberDenied'] == true;
        if (expectDenied) {
          await widget.setPhoto(
            expected: visible,
            messageId: fixture['messageId'] as String,
            createdAt: DateTime.now(),
            image: syntheticPhotoImage(),
          );
        }
        final ticket = await bridge.prepare(visible);
        await bridge.commit(
          ticket,
          PhotoBackgroundCredentialMaterial(
            environmentId: owner.environmentId,
            region: 'ap-shanghai',
            userId: owner.userId,
            gateway: Uri.parse(fixture['gateway'] as String),
            accessToken: token,
            expiresAt: expiry,
          ),
        );
        await preferences.setString(
          'native-photo-fetch-expected',
          fixture['messageId'] as String,
        );
        await preferences.setBool(
          'native-photo-fetch-expect-denied',
          expectDenied,
        );
        expect(await channel.invokeMethod<bool>('status'), isTrue);
        await File('${directory.path}/native-photo-fetch-ready.json')
            .writeAsString(
              jsonEncode({'fixtureId': fixture['fixtureId']}),
              flush: true,
            );
        if (phase == 'seed') return;
        final outcome = await channel.invokeMethod<String>('refresh');
        final diagnostics = await channel.invokeMethod<Map>('diagnostics');
        if (expectDenied) {
          try {
            expect(
              outcome == 'failed' &&
                  diagnostics?['stage'] == 'membership_initial' &&
                  diagnostics?['failure'] == 'authorization' &&
                  diagnostics?['httpStatus'] == 200,
              isTrue,
              reason: '$diagnostics',
            );
            expect((await widget.read()).messageId == null, isTrue);
            expect(await channel.invokeMethod<bool>('status'), isFalse);
          } finally {
            await widget.synchronize(scope: null, expiresAt: null);
            await bridge.clear();
            await preferences.remove('native-photo-fetch-expected');
            await preferences.remove('native-photo-fetch-expect-denied');
            final documents = await getApplicationDocumentsDirectory();
            final ready = File(
              '${documents.path}/native-photo-fetch-ready.json',
            );
            if (await ready.exists()) await ready.delete();
          }
          return;
        }
        expect(outcome == 'newData', isTrue, reason: '$diagnostics');
      }
      try {
        final state = await widget.read();
        if (preferences.getBool('native-photo-fetch-expect-denied') == true) {
          expect(
            state.messageId == null &&
                state.display == PhotoWidgetDisplay.unavailable,
            isTrue,
          );
          expect(await channel.invokeMethod<bool>('status'), isFalse);
          return;
        }
        expect(
          state.display == PhotoWidgetDisplay.photo &&
              state.messageId ==
                  preferences.getString('native-photo-fetch-expected'),
          isTrue,
        );
        expect(state.photoExpiresAt!.isAfter(DateTime.now()), isTrue);
        final expiry = state.photoExpiresAt;
        expect(await channel.invokeMethod<String>('refresh'), 'noData');
        expect((await widget.read()).photoExpiresAt == expiry, isTrue);
      } finally {
        await widget.synchronize(scope: null, expiresAt: null);
        await bridge.clear();
        await preferences.remove('native-photo-fetch-expected');
        await preferences.remove('native-photo-fetch-expect-denied');
        final directory = await getApplicationDocumentsDirectory();
        final ready = File('${directory.path}/native-photo-fetch-ready.json');
        if (await ready.exists()) await ready.delete();
      }
    },
    skip: !Platform.isIOS || !enabled,
  );
}
