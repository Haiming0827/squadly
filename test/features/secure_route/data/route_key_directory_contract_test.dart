import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/features/secure_route/data/route_encryption_service.dart';
import 'package:squadly/features/secure_route/domain/route_models.dart';

void main() {
  test('device registration RPC error fails closed', () async {
    final client = PostgrestClient(
      'https://pg.example.test/v1/rdb/rest',
      headers: {'Authorization': 'Bearer user-token'},
      httpClient: MockClient((request) async {
        final body = {'error': 'device_key_conflict'};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      CloudBaseRouteKeyDirectory(
        client: client,
        userIdReader: () async => 'alice',
      ).registerDevice(
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
