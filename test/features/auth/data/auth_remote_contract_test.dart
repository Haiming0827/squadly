import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:squadly/core/error/exceptions.dart';
import 'package:squadly/features/auth/data/datasources/apple_identity_gateway.dart';
import 'package:squadly/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'password recovery verifies email OTP before updating password',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/recover') {
            return http.Response('{}', 200);
          }
          if (request.url.path == '/auth/v1/verify') {
            return http.Response(
              jsonEncode({
                'access_token': 'recovery-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'recovery-refresh',
                'user': {
                  'id': 'user-a',
                  'email': 'a@example.test',
                  'created_at': '2026-10-08T00:00:00Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/auth/v1/user') {
            return http.Response(
              jsonEncode({
                'id': 'user-a',
                'email': 'a@example.test',
                'created_at': '2026-10-08T00:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/auth/v1/logout') {
            return http.Response('{}', 200);
          }
          return http.Response('unexpected request', 500);
        }),
      );
      addTearDown(client.dispose);

      final source = AuthRemoteDatasource(client);
      await source.requestPasswordRecovery(email: ' a@example.test ');
      await source.completePasswordRecovery(
        email: ' a@example.test ',
        code: ' 123456 ',
        newPassword: 'newPassword1',
      );

      expect(requests.map((request) => request.url.path), [
        '/auth/v1/recover',
        '/auth/v1/verify',
        '/auth/v1/user',
        '/auth/v1/logout',
      ]);
      expect(jsonDecode(requests[0].body)['email'], 'a@example.test');
      final verification = jsonDecode(requests[1].body);
      expect(verification['email'], 'a@example.test');
      expect(verification['token'], '123456');
      expect(verification['type'], 'recovery');
      expect(jsonDecode(requests[2].body), {'password': 'newPassword1'});
      expect(client.auth.currentSession, isNull);
    },
  );

  test('wrong recovery code never sends a password update', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"msg":"Token has expired or is invalid"}',
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      AuthRemoteDatasource(client).completePasswordRecovery(
        email: 'a@example.test',
        code: '000000',
        newPassword: 'newPassword1',
      ),
      throwsA(isA<ServerException>()),
    );
    expect(requests.map((request) => request.url.path), ['/auth/v1/verify']);
    expect(client.auth.currentSession, isNull);
  });

  test('password update failure closes the recovered session', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/verify') {
          return http.Response(
            jsonEncode({
              'access_token': 'recovery-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'recovery-refresh',
              'user': {
                'id': 'user-a',
                'email': 'a@example.test',
                'created_at': '2026-10-08T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/auth/v1/user') {
          return http.Response(
            '{"msg":"password rejected"}',
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      AuthRemoteDatasource(client).completePasswordRecovery(
        email: 'a@example.test',
        code: '123456',
        newPassword: 'newPassword1',
      ),
      throwsA(isA<ServerException>()),
    );
    expect(requests.map((request) => request.url.path), [
      '/auth/v1/verify',
      '/auth/v1/user',
      '/auth/v1/logout',
    ]);
    expect(client.auth.currentSession, isNull);
  });

  test(
    'native Apple ID token exchange binds a hashed nonce to raw nonce',
    () async {
      final requests = <http.Request>[];
      final apple = _FakeAppleIdentityGateway('apple-id-token');
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'test-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'test-refresh',
                'user': {
                  'id': 'user-a',
                  'email': 'a@example.test',
                  'created_at': '2026-10-08T00:00:00Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.url.path == '/rest/v1/profiles') {
            return http.Response(
              jsonEncode({
                'id': 'user-a',
                'nickname': '阿青',
                'avatar_url': null,
                'created_at': '2026-10-08T00:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response('unexpected request', 500, request: request);
        }),
      );
      addTearDown(client.dispose);

      final user = await AuthRemoteDatasource(
        client,
        appleIdentity: apple,
        isIOS: true,
      ).signInWithApple();

      expect(user.nickname, '阿青');
      expect(requests, hasLength(2));
      expect(requests.first.url.queryParameters['grant_type'], 'id_token');
      final exchange = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(exchange['provider'], 'apple');
      expect(exchange['id_token'], 'apple-id-token');
      final rawNonce = exchange['nonce'] as String;
      expect(rawNonce, isNotEmpty);
      final digest = await Sha256().hash(utf8.encode(rawNonce));
      expect(
        apple.hashedNonce,
        digest.bytes
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(),
      );
      expect(
        requests.last.url.queryParameters['select'],
        'id,nickname,avatar_url,created_at',
      );
    },
  );

  test(
    'Apple login stays off Android and missing token never reaches Auth',
    () async {
      var requestCount = 0;
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response('{}', 200, request: request);
        }),
      );
      addTearDown(client.dispose);
      final apple = _FakeAppleIdentityGateway(null);
      await expectLater(
        AuthRemoteDatasource(
          client,
          appleIdentity: apple,
          isIOS: false,
        ).signInWithApple(),
        throwsA(isA<ServerException>()),
      );
      expect(apple.hashedNonce, isNull);
      await expectLater(
        AuthRemoteDatasource(
          client,
          appleIdentity: apple,
          isIOS: true,
        ).signInWithApple(),
        throwsA(isA<ServerException>()),
      );
      expect(requestCount, 0);
    },
  );

  test(
    'unconfirmed email registration sends nickname but never writes profile',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/signup') {
            return http.Response(
              jsonEncode({
                'id': 'user-a',
                'email': 'a@example.test',
                'created_at': '2026-10-08T00:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected request', 500);
        }),
      );
      addTearDown(client.dispose);

      final registration = await AuthRemoteDatasource(client).signUpWithEmail(
        email: 'a@example.test',
        password: 'password1',
        nickname: '阿青',
      );

      expect(registration, isNull);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/auth/v1/signup');
      expect(jsonDecode(requests.single.body)['data']['nickname'], '阿青');
    },
  );

  test('phone code request uses mainland E.164 format', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await AuthRemoteDatasource(
      client,
    ).sendPhoneVerification(phone: '13800138000');

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/auth/v1/otp');
    expect(jsonDecode(requests.single.body)['phone'], '+8613800138000');
  });

  test('login reads only public profile fields and own Auth contact', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/auth/v1/token') {
          return http.Response(
            jsonEncode({
              'access_token': 'test-token',
              'token_type': 'bearer',
              'expires_in': 3600,
              'refresh_token': 'test-refresh',
              'user': {
                'id': 'user-a',
                'email': 'a@example.test',
                'phone': '+8613800138000',
                'created_at': '2026-10-08T00:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 'user-a',
            'nickname': '阿青',
            'avatar_url': null,
            'created_at': '2026-10-08T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final profile = await AuthRemoteDatasource(
      client,
    ).signInWithEmail(email: 'a@example.test', password: 'password1');

    expect(profile.nickname, '阿青');
    expect(profile.email, 'a@example.test');
    expect(profile.phone, '+8613800138000');
    final selection = requests.last.url.queryParameters['select'];
    expect(selection, 'id,nickname,avatar_url,created_at');
    expect(selection, isNot(contains('email')));
    expect(selection, isNot(contains('phone')));
  });

  test(
    'nickname update targets the authenticated profile and no contact field',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/auth/v1/token') {
            return http.Response(
              jsonEncode({
                'access_token': 'test-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'test-refresh',
                'user': {
                  'id': 'user-a',
                  'email': 'a@example.test',
                  'created_at': '2026-10-08T00:00:00Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 'user-a',
              'nickname': '晨跑阿青',
              'avatar_url': null,
              'created_at': '2026-10-08T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'a@example.test',
        password: 'password1',
      );

      final updated = await AuthRemoteDatasource(
        client,
      ).updateNickname(nickname: '晨跑阿青');

      expect(updated.nickname, '晨跑阿青');
      expect(updated.email, 'a@example.test');
      expect(requests.last.method, 'PATCH');
      expect(requests.last.url.queryParameters['id'], 'eq.user-a');
      expect(
        requests.last.url.queryParameters['select'],
        'id,nickname,avatar_url,created_at',
      );
      expect(jsonDecode(requests.last.body), {'nickname': '晨跑阿青'});
    },
  );
}

final class _FakeAppleIdentityGateway implements AppleIdentityGateway {
  _FakeAppleIdentityGateway(this.token);

  final String? token;
  String? hashedNonce;

  @override
  Future<String?> requestIdToken({required String hashedNonce}) async {
    this.hashedNonce = hashedNonce;
    return token;
  }
}
