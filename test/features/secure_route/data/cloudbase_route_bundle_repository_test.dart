import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/features/secure_route/data/cloudbase_route_bundle_repository.dart';
import 'package:squadly/features/secure_route/domain/route_bundle_repository.dart';

void main() {
  test('requests ciphertext and only this device envelope', () async {
    final requests = <http.Request>[];
    final client = PostgrestClient(
      'https://pg.example.test/v1/rdb/rest',
      headers: {'Authorization': 'Bearer user-token'},
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = switch (request.url.path) {
          '/v1/rdb/rest/card_route_ciphertexts' => {
            'algorithm': 'X25519-HKDF-SHA256-AES-256-GCM',
            'nonce': 'route-nonce',
            'ciphertext': 'route-ciphertext',
            'mac': 'route-mac',
          },
          '/v1/rdb/rest/card_route_envelopes' => {
            'recipient_user_id': 'alice',
            'recipient_device_id': 'device-a',
            'ephemeral_public_key': 'public',
            'salt': 'salt',
            'nonce': 'envelope-nonce',
            'ciphertext': 'envelope-ciphertext',
            'mac': 'envelope-mac',
          },
          _ => throw StateError('Unexpected request path: ${request.url.path}'),
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final bundle =
        await CloudBaseRouteBundleRepository(
          client: client,
          userIdReader: () async => 'alice',
        ).loadForDevice(
          squadId: 'squad-a',
          cardId: 'card-a',
          userId: 'alice',
          deviceId: 'device-a',
        );

    expect(bundle.envelopes, hasLength(1));
    expect(bundle.envelopes.single.recipientDeviceId, 'device-a');
    expect(requests, hasLength(2));
    expect(
      requests[0].url.queryParameters['select'],
      'algorithm,nonce,ciphertext,mac',
    );
    expect(requests[0].url.queryParameters['card_id'], 'eq.card-a');
    expect(requests[1].url.queryParameters['recipient_user_id'], 'eq.alice');
    expect(
      requests[1].url.queryParameters['recipient_device_id'],
      'eq.device-a',
    );
    expect(
      requests[1].url.queryParameters['select'],
      isNot(contains('private_key')),
    );
  });

  test('cannot request another account envelope', () async {
    var requests = 0;
    final client = PostgrestClient(
      'https://pg.example.test/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      CloudBaseRouteBundleRepository(
        client: client,
        userIdReader: () async => null,
      ).loadForDevice(
        squadId: 'squad-a',
        cardId: 'card-a',
        userId: 'alice',
        deviceId: 'device-a',
      ),
      throwsA(isA<RouteEnvelopeUnavailable>()),
    );
    expect(requests, 0);
  });
}
