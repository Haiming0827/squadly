import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:squadly/features/secure_route/data/route_encryption_service.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('device registration RPC error fails closed', () async {
    final client = SupabaseClient(
      'https://project.example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        final body = request.url.path == '/auth/v1/token'
            ? {
                'access_token': 'test-token',
                'token_type': 'bearer',
                'expires_in': 3600,
                'refresh_token': 'test-refresh',
                'user': {
                  'id': 'alice',
                  'email': 'a@example.test',
                  'created_at': '2026-10-08T00:00:00Z',
                },
              }
            : {'error': 'device_key_conflict'};
        return http.Response(
          jsonEncode(body),
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

    await expectLater(
      SupabaseRouteKeyDirectory(client).registerDevice(
        const RouteRecipient(
          userId: 'alice',
          deviceId: 'device-a',
          publicKeyBase64: 'public-key',
        ),
      ),
      throwsA(isA<RouteDeviceRegistrationException>()),
    );
  });
}
