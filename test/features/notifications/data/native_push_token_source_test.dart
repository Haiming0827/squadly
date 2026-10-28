import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/notifications/data/native_push_token_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('squadly/notifications');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('iOS asks native APNs for a fresh token', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestApnsToken');
          return 'fresh-token';
        });
    final source = NativePushTokenSource(channel: channel, isIOS: true);
    expect(await source.requestToken(), 'fresh-token');
  });

  test(
    'queries existing notification authorization without prompting',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'areNotificationsAuthorized');
            return true;
          });
      final source = NativePushTokenSource(channel: channel, isIOS: true);
      expect(await source.isAuthorized(), isTrue);
    },
  );

  test(
    'checks provider availability before asking platform permission',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'isNotificationsAvailable');
            return false;
          });
      final source = NativePushTokenSource(
        channel: channel,
        isIOS: false,
        isAndroid: true,
      );
      expect(await source.isAvailable(), isFalse);
    },
  );

  test('denied permission is not a chat failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'permission_denied');
        });
    final source = NativePushTokenSource(channel: channel, isIOS: true);
    expect(await source.requestToken(), isNull);
  });

  test('Android requests Mi Push token and identifies its provider', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestMiPushToken');
          return 'mi-token';
        });
    final source = NativePushTokenSource(
      channel: channel,
      isIOS: false,
      isAndroid: true,
    );
    expect(source.provider, 'mipush');
    expect(await source.requestToken(), 'mi-token');
  });

  test('Android unregisters native Mi Push service', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'unregisterMiPush');
          return null;
        });
    await NativePushTokenSource(
      channel: channel,
      isIOS: false,
      isAndroid: true,
    ).unregister();
  });
}
