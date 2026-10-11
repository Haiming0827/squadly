import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:squadly/features/notifications/data/supabase_push_token_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('registers and unregisters only through authenticated RPCs', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = switch (request.url.path) {
          '/auth/v1/token' => {
            'access_token': 'test-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'test-refresh-token',
            'user': {
              'id': '00000000-0000-4000-8000-000000000001',
              'email': 'a@example.test',
              'created_at': '2026-10-08T00:00:00Z',
            },
          },
          '/rest/v1/rpc/register_push_token' => {
            'device_id': '50000000-0000-4000-8000-000000000001',
            'provider': 'apns',
          },
          '/rest/v1/rpc/unregister_push_token' => null,
          _ => throw StateError('Unexpected path ${request.url.path}'),
        };
        return http.Response(
          response == null ? '' : jsonEncode(response),
          response == null ? 204 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabasePushTokenRepository(client);
    await expectLater(
      repository.register(
        deviceId: '50000000-0000-4000-8000-000000000001',
        provider: 'apns',
        token: 'apns-test-token',
      ),
      throwsStateError,
    );
    expect(requests, isEmpty);

    await client.auth.signInWithPassword(
      email: 'a@example.test',
      password: 'password1',
    );
    await repository.register(
      deviceId: '50000000-0000-4000-8000-000000000001',
      provider: 'apns',
      token: 'apns-test-token',
    );
    await repository.unregister(
      deviceId: '50000000-0000-4000-8000-000000000001',
      provider: 'apns',
    );
    expect(requests.map((request) => request.url.path), [
      '/auth/v1/token',
      '/rest/v1/rpc/register_push_token',
      '/rest/v1/rpc/unregister_push_token',
    ]);
    expect(jsonDecode(requests[1].body), {
      'p_device_id': '50000000-0000-4000-8000-000000000001',
      'p_provider': 'apns',
      'p_token': 'apns-test-token',
    });
    expect(jsonDecode(requests[2].body), {
      'p_device_id': '50000000-0000-4000-8000-000000000001',
      'p_provider': 'apns',
    });
  });
}
