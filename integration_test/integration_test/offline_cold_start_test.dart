import 'dart:convert';
import 'dart:io';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' as cb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/app/app.dart';
import 'package:squadly/app/providers/conversation_cache_provider.dart';
import 'package:squadly/app/providers/conversation_runtime_providers.dart';
import 'package:squadly/app/providers/domain_repository_providers.dart';
import 'package:squadly/app/providers/offline_access_provider.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/features/auth/data/datasources/cloudbase_offline_session_source.dart';
import 'package:squadly/features/conversation/data/drift_conversation_cache.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

const _environment = 'squadly-offline-native-fixture';
const _userId = 'offline-coldstart-fixture-a';
const _squadId = 'offline-squad-fixture';
const _planId = 'offline-plan-fixture';
const _message = '独立宿主跨进程缓存验收';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_OFFLINE_CACHE_NATIVE');
  const phase = String.fromEnvironment('OFFLINE_CACHE_PHASE');

  testWidgets('native offline cold start: $phase', (tester) async {
    expect(['seed', 'read'], contains(phase));
    final previousHttp = HttpOverrides.current;
    HttpOverrides.global = _OfflineHttp();
    final config = CloudBaseConfig.fromValues(
      useDemo: 'false',
      environmentId: _environment,
      region: 'ap-shanghai',
      publishableKey: 'synthetic-offline-fixture-public-key',
    );
    final preferences = await SharedPreferences.getInstance();
    ProviderContainer? container;
    DriftConversationCache? cache;
    cb.CloudBase? app;
    try {
      if (phase == 'seed') {
        // Test-only SDK persistence fixture in an isolated host/environment.
        // This is not a real credential or a CloudBase cloud-auth assertion.
        final expires = DateTime.now().toUtc().add(const Duration(hours: 1));
        final payload = base64Url
            .encode(
              utf8.encode(
                jsonEncode({
                  'sub': _userId,
                  'exp': expires.millisecondsSinceEpoch ~/ 1000,
                }),
              ),
            )
            .replaceAll('=', '');
        final session = cb.Session(
          accessToken: 'e30.$payload.synthetic',
          expiresAt: expires.millisecondsSinceEpoch,
          user: cb.User(id: _userId, createdAt: '2026-01-01T00:00:00Z'),
        );
        await preferences.setString(
          'credentials_$_environment',
          jsonEncode(session.toJson()),
        );
        container = ProviderContainer(
          overrides: [cloudBaseConfigProvider.overrideWithValue(config)],
        );
        cache =
            container.read(conversationCacheProvider) as DriftConversationCache;
        await cache.clearUser(_userId);
        final lease = cache.lease(_userId)!;
        await cache.rememberThread(
          lease,
          _squadId,
          '原生离线测试小队',
          planId: _planId,
          planTitle: '跨进程测试计划',
        );
        await cache.save(lease, _squadId, [
          TimelineEntry(
            id: 'native-cache-message',
            squadId: _squadId,
            planId: _planId,
            authorId: _userId,
            authorName: '测试成员',
            kind: TimelineEntryKind.text,
            text: _message,
            clientNonce: 'native-cache-nonce',
            createdAt: DateTime.now().toUtc(),
          ),
        ], planId: _planId);
        expect(
          (await cache.page(lease, _squadId, planId: _planId)).single.text,
          _message,
        );
      } else {
        // A separate invocation cold-starts the app process. SDK preferences,
        // SQLite and Keychain/Keystore must all survive the previous exit.
        app = await cb.CloudBase.init(
          env: _environment,
          region: 'ap-shanghai',
          accessKey: config.publishableKey,
        );
        var now = DateTime.now();
        final source = CloudBaseOfflineSessionSource(app.auth);
        container = ProviderContainer(
          overrides: [
            cloudBaseConfigProvider.overrideWithValue(config),
            useDemoBackendProvider.overrideWithValue(false),
            cloudBaseAppProvider.overrideWithValue(app),
            offlineAccessProvider.overrideWith(
              (ref) =>
                  OfflineAccessController(source: source, clock: () => now),
            ),
            conversationRepositoryProvider.overrideWith(
              (ref) => throw StateError(
                'Offline view must not initialize remote timeline',
              ),
            ),
            conversationOutboxProvider.overrideWith(
              (ref) => throw StateError('Offline view must not retry outbox'),
            ),
          ],
        );
        cache =
            container.read(conversationCacheProvider) as DriftConversationCache;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SquadlyApp(),
          ),
        );
        await _waitFor(tester, find.text('本机聊天记录'));
        await tester.ensureVisible(find.text('本机聊天记录'));
        await tester.tap(find.text('本机聊天记录'));
        await _waitFor(tester, find.text('跨进程测试计划'));
        await tester.tap(find.text('跨进程测试计划'));
        await _waitFor(tester, find.text(_message));
        expect(find.byType(TextField), findsNothing);
        expect(find.byTooltip('发送消息'), findsNothing);
        final session = container.read(offlineAccessProvider).session!;
        now = session.expiresAt.add(const Duration(seconds: 1));
        container.read(offlineAccessProvider.notifier).checkExpiry();
        await tester.pumpAndSettle();
        expect(find.text(_message), findsNothing);
        expect(find.text('登录已过期'), findsOneWidget);
        expect(
          (await cache.page(
            cache.lease(_userId)!,
            _squadId,
            planId: _planId,
          )).single.text,
          _message,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await cache.clearUser(_userId);
        await preferences.remove('credentials_$_environment');
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await cache?.close();
      container?.dispose();
      app?.httpClient.dio.close(force: true);
      HttpOverrides.global = previousHttp;
    }
  }, skip: !enabled);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
  await tester.pumpAndSettle();
}

class _OfflineHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _NoHttpClient();
}

class _NoHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      throw const SocketException('Network disabled in isolated offline test');
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
