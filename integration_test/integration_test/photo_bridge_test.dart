import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const verify = bool.fromEnvironment('VERIFY_PHOTO_BRIDGE_SIMULATOR');
  const channel = MethodChannel('squadly/photos');

  testWidgets('iOS photo bridge is registered and rejects unknown sources', (
    tester,
  ) async {
    await expectLater(
      channel.invokeMethod<Object?>('pickPhoto', {'source': 'unknown'}),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_image',
        ),
      ),
    );
  }, skip: !Platform.isIOS || !verify);

  testWidgets(
    'simulator camera absence is an actual native failure without a permission prompt',
    (tester) async {
      await expectLater(
        channel.invokeMethod<Object?>('pickPhoto', {'source': 'camera'}),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'unavailable',
          ),
        ),
      );
    },
    skip: !Platform.isIOS || !verify,
  );
}
