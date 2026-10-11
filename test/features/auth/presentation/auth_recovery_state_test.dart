import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:squadly/core/network/supabase_client_provider.dart';
import 'package:squadly/features/auth/presentation/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const useDemoBackend = bool.fromEnvironment(
    'USE_DEMO_BACKEND',
    defaultValue: true,
  );
  test(
    'late recovery profile response cannot revive a signed-out user',
    () async {
      final profileStarted = Completer<void>();
      final releaseProfile = Completer<void>();
      final client = SupabaseClient(
        'https://project.example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((request) async {
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
              request: request,
            );
          }
          if (request.url.path == '/rest/v1/profiles') {
            profileStarted.complete();
            await releaseProfile.future;
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
          if (request.url.path == '/auth/v1/logout') {
            return http.Response('{}', 200);
          }
          return http.Response('unexpected request', 500);
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(authNotifierProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(container.read(authNotifierProvider).valueOrNull, isNull);

      await client.auth.verifyOTP(
        email: 'a@example.test',
        token: '123456',
        type: OtpType.recovery,
      );
      await profileStarted.future.timeout(const Duration(seconds: 3));
      await client.auth.signOut(scope: SignOutScope.local);
      releaseProfile.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(authNotifierProvider).valueOrNull, isNull);
    },
    skip: useDemoBackend,
  );
}
