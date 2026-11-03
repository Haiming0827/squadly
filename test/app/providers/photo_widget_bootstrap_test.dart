import 'dart:async';
import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as sdk;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/app/providers/conversation_cache_lifecycle_provider.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/current_user_provider.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/app/providers/photo_providers.dart';
import 'package:squadly/app/providers/photo_widget_providers.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/network/cloudbase_postgres_client.dart';
import 'package:squadly/features/auth/data/datasources/cloudbase_offline_session_source.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

import '../../core/network/cloudbase_auth_ordering_test.dart'
    show RacingSdkTransport;
import '../../core/network/cloudbase_session_reader_test.dart' show jwt;

const _renewal = MethodChannel('squadly/photo-renewal');
const _background = MethodChannel('squadly/photo-background');
const _widget = MethodChannel('squadly/photo-widget');
const _generation = '00000000-0000-4000-8000-000000000001';
const _binding = '00000000-0000-4000-8000-000000000002';
const _squad = '00000000-0000-4000-8000-000000000003';
const _ticket = '00000000-0000-4000-8000-000000000004';

/// Native is an external boundary here. Its generation precondition makes an
/// early Dart synchronization fail the handoff, just like the real Swift CAS.
final class _Native {
  late String scope;
  late DateTime expiry;
  String? sessionScope;
  String generation = _generation;
  String? ticketGeneration;
  bool credential = false;
  int commits = 0, clears = 0, rotations = 0;
  final ready = Completer<void>();
  Map<String, Object?> snapshot() => {
    'state': sessionScope == null ? 'signedOut' : 'empty',
    'scheme': 'squadly',
    if (sessionScope != null) 'scope': sessionScope,
    if (sessionScope != null) 'generation': generation,
    if (sessionScope != null) 'expiresAt': expiry.millisecondsSinceEpoch,
    'bindingId': _binding,
    'bindingScope': scope,
    'squadId': _squad,
    'squadName': '合成验收小队',
    'previewEnabled': true,
  };
  Future<Object?> widget(MethodCall call) async {
    final args = call.arguments as Map? ?? {};
    switch (call.method) {
      case 'read':
        return snapshot();
      case 'synchronize':
        final incoming = args['scope'] as String?;
        if (incoming != sessionScope ||
            args['expiresAt'] != expiry.millisecondsSinceEpoch) {
          rotations++;
          generation =
              '00000000-0000-4000-8000-${(1000 + rotations).toString().padLeft(12, '0')}';
          credential = false;
        }
        sessionScope = incoming;
        if (incoming != null) {
          expiry = DateTime.fromMillisecondsSinceEpoch(
            args['expiresAt'] as int,
          );
        }
        return snapshot();
      case 'retainExpired':
        if (args['scope'] != sessionScope) {
          throw PlatformException(code: 'stale');
        }
        return snapshot();
      case 'isAvailable':
        return true;
      default:
        throw StateError('Unexpected widget call ${call.method}');
    }
  }

  Future<Object?> background(MethodCall call) async {
    switch (call.method) {
      case 'status':
        return credential;
      case 'clear':
        credential = false;
        ticketGeneration = null;
        clears++;
        return true;
      default:
        throw StateError('Unexpected credential call ${call.method}');
    }
  }

  Future<Object?> renewal(MethodCall call) async {
    if (call.method == 'ready') {
      if (!ready.isCompleted) ready.complete();
      return true;
    }
    if (call.method == 'close') return true;
    if (call.method != 'commit') throw StateError('Unexpected renewal call');
    if (ticketGeneration == null ||
        ticketGeneration != generation ||
        sessionScope != scope) {
      return false;
    }
    final args = call.arguments as Map;
    expiry = DateTime.fromMillisecondsSinceEpoch(args['expiresAt'] as int);
    generation = '00000000-0000-4000-8000-000000000099';
    credential = true;
    commits++;
    ticketGeneration = null;
    return true;
  }

  Future<Object?> request() async {
    await ready.future;
    ticketGeneration = generation;
    final result = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _renewal.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('renew', {
              'scope': scope,
              'ticket': _ticket,
              'remainingMs': 8000,
            }),
          ),
          (data) => result.complete(
            data == null
                ? null
                : const StandardMethodCodec().decodeEnvelope(data),
          ),
        );
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late sdk.CloudBase app;
  late RacingSdkTransport transport;
  late _Native native;
  String? delayedProfile;
  var delayedCalls = 0;
  late Completer<void> profileStarted, releaseProfile;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    delayedProfile = null;
    delayedCalls = 0;
    profileStarted = Completer<void>();
    releaseProfile = Completer<void>();
    SharedPreferences.setMockInitialValues({});
    app = await sdk.CloudBase.init(
      env: 'fixture-env',
      region: 'ap-shanghai',
      accessKey: 'fixture-publishable-key-00000',
    );
    final past = DateTime.now().subtract(const Duration(hours: 1));
    app.httpClient.currentSession = sdk.Session(
      accessToken: jwt(past),
      refreshToken: 'synthetic-refresh',
      expiresAt: past.millisecondsSinceEpoch,
      user: sdk.User(id: 'fixture-a', createdAt: '2026-01-01T00:00:00Z'),
    );
    transport = RacingSdkTransport();
    app.httpClient.dio.httpClientAdapter = transport;
    native = _Native()..expiry = past;
    native.scope = await photoWidgetScope(
      PhotoWidgetContext(
        environmentId: 'fixture-env',
        userId: 'fixture-a',
        expiresAt: past,
      ),
    );
    native.sessionScope = native.scope;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_widget, native.widget);
    messenger.setMockMethodCallHandler(_background, native.background);
    messenger.setMockMethodCallHandler(_renewal, native.renewal);
    final config = CloudBaseConfig.fromValues(
      useDemo: 'false',
      environmentId: 'fixture-env',
      region: 'ap-shanghai',
      publishableKey: 'fixture-publishable-key-00000',
    );
    container = ProviderContainer(
      overrides: [
        cloudBaseAppProvider.overrideWithValue(app),
        cloudBaseConfigProvider.overrideWithValue(config),
        useDemoBackendProvider.overrideWithValue(false),
        offlineSessionSourceProvider.overrideWithValue(
          CloudBaseOfflineSessionSource(app.auth),
        ),
        conversationCacheProvider.overrideWithValue(null),
        photoGatewayUrlProvider.overrideWithValue(
          Uri.parse(
            'https://fixture-env-123.ap-shanghai.app.tcloudbase.com/photos',
          ),
        ),
        cloudBasePostgresClientProvider.overrideWith((ref) {
          final pg = CloudBasePostgresClient(
            config: config,
            accessTokenReader: ref.watch(cloudBaseAccessTokenReaderProvider),
            httpClient: MockClient((request) async {
              expect(request.url.path.endsWith('/profiles'), true);
              final id = request.url.queryParameters['id']!.substring(3);
              if (id == delayedProfile) {
                delayedCalls++;
                if (!profileStarted.isCompleted) profileStarted.complete();
                await releaseProfile.future;
              }
              return http.Response(
                jsonEncode({
                  'id': id,
                  'nickname': '合成成员',
                  'created_at': '2026-01-01T00:00:00Z',
                }),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }),
          );
          ref.onDispose(pg.close);
          return pg;
        }),
      ],
    );
    container.listen(conversationCacheLifecycleProvider, (_, _) {});
    container.listen(photoWidgetLifecycleProvider, (_, _) {});
    await transport.started.future.timeout(const Duration(seconds: 2));
  });
  tearDown(() async {
    if (!transport.release.isCompleted) transport.release.complete();
    if (!releaseProfile.isCompleted) releaseProfile.complete();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [_widget, _background, _renewal]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    app.httpClient.dio.close(force: true);
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> until(bool Function() predicate) async {
    for (var i = 0; i < 200; i++) {
      if (predicate()) return;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    fail('Expected provider state did not settle');
  }

  test('production auth restoration and SDK event cannot invalidate their own native ticket', () async {
    final request = native.request();
    await Future<void>.delayed(Duration.zero);
    transport.release.complete();
    expect(await request.timeout(const Duration(seconds: 2)), true);
    await until(
      () =>
          container.read(currentUserProvider).asData?.value?.id == 'fixture-a',
    );
    expect(native.commits, 1);
    expect(native.credential, true);
    expect(native.generation, '00000000-0000-4000-8000-000000000099');
    expect(native.clears, 0);
  });
  test(
    'logout supersedes a native renewal during the initial SDK refresh',
    () async {
      final request = native.request();
      await Future<void>.delayed(Duration.zero);
      final leaving = container.read(authNotifierProvider.notifier).signOut();
      transport.release.complete();
      expect(await request.timeout(const Duration(seconds: 2)), false);
      expect(await leaving, isNull);
      await until(
        () =>
            container.read(offlineAccessProvider).status ==
            OfflineAccessStatus.signedOut,
      );
      expect(native.commits, 0);
      expect(native.credential, false);
      expect(container.read(currentUserProvider).asData?.value, isNull);
    },
  );
  test(
    'new account during native renewal never receives the old result',
    () async {
      final request = native.request();
      await Future<void>.delayed(Duration.zero);
      final signing = container
          .read(authNotifierProvider.notifier)
          .signInWithEmail(email: 'b@example.test', password: 'synthetic-only');
      transport.release.complete();
      expect(await request.timeout(const Duration(seconds: 2)), false);
      await signing;
      await until(
        () =>
            container.read(currentUserProvider).asData?.value?.id ==
            'fixture-b',
      );
      expect(native.commits, 0);
      expect(native.credential, false);
      final sdkSession = app.httpClient.currentSession!;
      final expected = await photoWidgetScope(
        PhotoWidgetContext(
          environmentId: 'fixture-env',
          userId: 'fixture-b',
          expiresAt: DateTime.fromMillisecondsSinceEpoch(sdkSession.expiresAt!),
        ),
      );
      await until(() => native.sessionScope == expected);
    },
  );
  test('late explicit login profile cannot revive the account after logout', () async {
    transport.release.complete();
    await until(
      () =>
          container.read(currentUserProvider).asData?.value?.id == 'fixture-a',
    );
    delayedProfile = 'fixture-b';
    final notifier = container.read(authNotifierProvider.notifier);
    final signing = notifier.signInWithEmail(
      email: 'b@example.test',
      password: 'synthetic-only',
    );
    await profileStarted.future.timeout(const Duration(seconds: 2));
    await until(() => delayedCalls >= 2);
    expect(await notifier.signOut(), isNull);
    expect(app.httpClient.currentSession, isNull);
    releaseProfile.complete();
    await signing;
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(currentUserProvider).asData?.value,
      isNull,
      reason:
          'An explicit login response must not restore a profile after logout',
    );
  });
}
