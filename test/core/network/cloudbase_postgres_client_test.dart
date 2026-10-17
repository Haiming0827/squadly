import 'dart:convert';

import 'package:cloudbase_flutter/cloudbase_flutter.dart' hide CloudBaseConfig;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_client_provider.dart';
import 'package:squadly/core/network/cloudbase_postgres_client.dart';

class _CloudBaseMock extends Mock implements CloudBase {}

class _CloudBaseAuthMock extends Mock implements CloudBaseAuth {}

void main() {
  test(
    'uses CloudBase PG REST and attaches the current user JWT per request',
    () async {
      final transport = _RecordingHttpClient();
      final client = CloudBasePostgresClient(
        config: _config(),
        accessTokenReader: () async => 'cloudbase-user-jwt',
        httpClient: transport,
      );
      addTearDown(client.close);

      final rows = await client.rest
          .from('profiles')
          .select('id,nickname')
          .eq('id', 'user-a');

      expect(rows, isEmpty);
      expect(
        transport.request!.url.host,
        'squadly-test-123456.api.tcloudbasegateway.com',
      );
      expect(transport.request!.url.path, '/v1/rdb/rest/profiles');
      expect(transport.request!.url.queryParameters['id'], 'eq.user-a');
      expect(
        transport.request!.headers['Authorization'],
        'Bearer cloudbase-user-jwt',
      );
    },
  );

  test('uses the public key for anonymous REST calls', () async {
    final transport = _RecordingHttpClient();
    final client = CloudBasePostgresClient(
      config: _config(),
      accessTokenReader: () async => null,
      httpClient: transport,
    );
    addTearDown(client.close);

    await client.rest.rpc('public_status');

    expect(transport.request!.url.path, '/v1/rdb/rest/rpc/public_status');
    expect(
      transport.request!.headers['Authorization'],
      'Bearer public-publishable-key-for-tests',
    );
  });

  test(
    'a CloudBase no-session response uses the public key fallback',
    () async {
      final app = _CloudBaseMock();
      final auth = _CloudBaseAuthMock();
      when(() => app.auth).thenReturn(auth);
      when(() => auth.getSession()).thenAnswer(
        (_) async => SignInRes(error: AuthError(code: 'no_session')),
      );
      final container = ProviderContainer(
        overrides: [cloudBaseAppProvider.overrideWithValue(app)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(cloudBaseAccessTokenReaderProvider)(),
        isNull,
      );
    },
  );
}

CloudBaseConfig _config() => CloudBaseConfig.fromValues(
  useDemo: 'false',
  environmentId: 'squadly-test-123456',
  region: 'ap-shanghai',
  publishableKey: 'public-publishable-key-for-tests',
);

final class _RecordingHttpClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}
