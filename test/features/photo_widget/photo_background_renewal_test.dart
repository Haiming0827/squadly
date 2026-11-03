import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/photo_widget/data/photo_background_credentials.dart';
import 'package:squadly/features/photo_widget/data/photo_background_renewal.dart';

const channel = MethodChannel('squadly/photo-renewal');
const ticket = '00000000-0000-4000-8000-000000000001';
Map<String, Object?> request({int milliseconds = 8000}) => {
  'ticket': ticket,
  'scope': 'a' * 64,
  'remainingMs': milliseconds,
};
PhotoBackgroundCredentialMaterial material() =>
    PhotoBackgroundCredentialMaterial(
      environmentId: 'fixture-env',
      region: 'ap-shanghai',
      userId: 'fixture-user',
      gateway: Uri.parse(
        'https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos',
      ),
      accessToken: 'synthetic-only',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
Future<Object?> nativeCall(Object? args, {String method = 'renew'}) async {
  final reply = Completer<Object?>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (bytes) {
          reply.complete(
            bytes == null
                ? null
                : const StandardMethodCodec().decodeEnvelope(bytes),
          );
        },
      );
  return reply.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhotoBackgroundRenewalController controller;
  late List<MethodCall> calls;
  late Future<PhotoBackgroundCredentialMaterial?> Function(
    PhotoBackgroundRenewalRequest,
    bool Function(),
  )
  read;
  var holds = 0, releases = 0, reads = 0;
  setUp(() async {
    calls = [];
    holds = 0;
    releases = 0;
    reads = 0;
    read = (_, _) async => material();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    controller = PhotoBackgroundRenewalController(
      hold: (_) => holds++,
      release: () async => releases++,
      read: (request, current) {
        reads++;
        return read(request, current);
      },
    );
    await controller.start();
  });
  tearDown(() async {
    await controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('strict native request rejects URLs, extra fields, booleans and oversized budgets', () async {
    for (final value in [
      null,
      {},
      {...request(), 'url': 'https://example.test'},
      {...request(), 'remainingMs': true},
      request(milliseconds: 8001),
      request(milliseconds: 0),
      {...request(), 'scope': 'other'},
      {...request(), 'ticket': 'other'},
    ]) {
      expect(await nativeCall(value), false);
    }
    expect(await nativeCall(request(), method: 'other'), false);
    expect(reads, 0);
    expect(holds, 0);
  });
  test(
    'fresh material commits once and releases lifecycle coordination',
    () async {
      expect(await nativeCall(request()), true);
      expect(reads, 1);
      expect(holds, 1);
      expect(releases, 1);
      final commit = calls.singleWhere((c) => c.method == 'commit');
      final args = commit.arguments as Map;
      expect(
        args.keys,
        unorderedEquals([
          'ticket',
          'environmentId',
          'region',
          'userId',
          'gateway',
          'accessToken',
          'expiresAt',
        ]),
      );
      expect(args.containsKey('refreshToken'), false);
    },
  );
  test('logout invalidates in-flight SDK result and rejects a second concurrent request', () async {
    final waiting = Completer<PhotoBackgroundCredentialMaterial?>();
    read = (_, _) => waiting.future;
    final first = nativeCall(request());
    await Future<void>.delayed(Duration.zero);
    expect(await nativeCall(request()), false);
    controller.invalidate();
    waiting.complete(material());
    expect(await first, false);
    expect(calls.where((c) => c.method == 'commit'), isEmpty);
    expect(releases, 1);
  });
  test('budget expiration returns without waiting for SDK and ignores its late token', () async {
    final waiting = Completer<PhotoBackgroundCredentialMaterial?>();
    bool Function()? current;
    read = (_, guard) {
      current = guard;
      return waiting.future;
    };
    expect(
      await nativeCall(request(milliseconds: 10))
          .timeout(const Duration(seconds: 1)),
      false,
    );
    expect(current!(), false);
    expect(releases, 1);
    waiting.complete(material());
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'commit'), isEmpty);
  });
  test(
    'SDK or native failure releases lifecycle without a successful handoff',
    () async {
      read = (_, _) async => throw StateError('controlled');
      expect(await nativeCall(request()), false);
      expect(releases, 1);
      read = (_, _) async => material();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'commit') throw PlatformException(code: 'stale');
            return true;
          });
      expect(await nativeCall(request()), false);
      expect(releases, 2);
    },
  );
}
