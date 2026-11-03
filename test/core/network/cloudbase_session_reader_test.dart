import 'dart:convert';
import 'dart:typed_data';

import 'package:cloudbase_flutter/cloudbase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';

String jwt(DateTime expiry) {
  String encode(Object value) =>
      base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'RS256'})}.${encode({'sub': 'fixture-a', 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.${base64UrlEncode(List.filled(32, 42)).replaceAll('=', '')}';
}

final class DeniedRefresh implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    expect(options.path, '/auth/v1/token');
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'code': 'invalid_grant', 'message': 'synthetic denial'},
      }),
      400,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final invalid in [
    'none',
    'fresh',
    'wrong-subject',
    'malformed',
    'jwt-expired-before-sdk',
  ]) {
    test('PG token reader validates actual SDK $invalid snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final app = await CloudBase.init(
        env: 'fixture-env',
        region: 'ap-shanghai',
        accessKey: 'fixture-publishable-key-00000',
      );
      final future = DateTime.now().add(const Duration(hours: 1));
      if (invalid != 'none') {
        app.httpClient.currentSession = Session(
          accessToken: invalid == 'malformed'
              ? 'not-a-jwt'
              : jwt(
                  invalid == 'jwt-expired-before-sdk'
                      ? DateTime.utc(2020)
                      : future,
                ),
          expiresAt: future.millisecondsSinceEpoch,
          user: User(
            id: invalid == 'wrong-subject' ? 'different-fixture' : 'fixture-a',
            createdAt: '2026-01-01T00:00:00Z',
          ),
        );
      }
      final adapter = DeniedRefresh();
      app.httpClient.dio.httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [cloudBaseAppProvider.overrideWithValue(app)],
      );
      addTearDown(container.dispose);
      final reader = container.read(cloudBaseAccessTokenReaderProvider);
      if (invalid == 'none') {
        expect(await reader(), isNull);
      } else if (invalid == 'fresh') {
        expect(await reader(), app.httpClient.currentSession!.accessToken);
      } else {
        await expectLater(reader(), throwsA(isA<CloudBaseSessionException>()));
      }
      expect(adapter.calls, 0);
    });
  }
  test(
    'actual SDK failed refresh cannot expose an expired access token to PG',
    () async {
      SharedPreferences.setMockInitialValues({});
      final app = await CloudBase.init(
        env: 'fixture-env',
        region: 'ap-shanghai',
        accessKey: 'fixture-publishable-key-00000',
      );
      final expiry = DateTime.now().subtract(const Duration(hours: 1));
      app.httpClient.currentSession = Session(
        accessToken: jwt(expiry),
        refreshToken: 'synthetic-refresh-only',
        expiresAt: expiry.millisecondsSinceEpoch,
        user: User(id: 'fixture-a', createdAt: '2026-01-01T00:00:00Z'),
      );
      final adapter = DeniedRefresh();
      app.httpClient.dio.httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [cloudBaseAppProvider.overrideWithValue(app)],
      );
      addTearDown(container.dispose);
      var rejected = false;
      try {
        rejected =
            await container.read(cloudBaseAccessTokenReaderProvider)() == null;
      } catch (_) {
        rejected = true;
      }
      expect(adapter.calls, 1);
      expect(
        rejected,
        isTrue,
        reason: 'SDK getSession success alone is not proof that its token was refreshed',
      );
    },
  );
}
