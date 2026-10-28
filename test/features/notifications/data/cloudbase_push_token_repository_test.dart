import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/features/notifications/data/cloudbase_push_token_repository.dart';

void main() {
  test(
    'registers and unregisters through authenticated CloudBase RPCs',
    () async {
      final requests = <http.Request>[];
      final client = PostgrestClient(
        'https://pg.example.test/v1/rdb/rest',
        headers: {'Authorization': 'Bearer user-jwt'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final token = <String?>[null];
      final repository = CloudBasePushTokenRepository(
        client: client,
        accessTokenReader: () async => token.first,
      );

      await expectLater(
        repository.register(
          deviceId: 'device-1',
          provider: 'apns',
          token: 'push-token',
        ),
        throwsStateError,
      );
      expect(requests, isEmpty);

      token[0] = 'user-jwt';
      await repository.register(
        deviceId: 'device-1',
        provider: 'apns',
        token: 'push-token',
      );
      await repository.unregister(deviceId: 'device-1', provider: 'apns');

      expect(requests.map((request) => request.url.path), [
        '/v1/rdb/rest/rpc/register_push_token',
        '/v1/rdb/rest/rpc/unregister_push_token',
      ]);
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer user-jwt',
        ),
        isTrue,
      );
      expect(jsonDecode(requests.first.body), {
        'p_device_id': 'device-1',
        'p_provider': 'apns',
        'p_token': 'push-token',
      });
    },
  );
}
