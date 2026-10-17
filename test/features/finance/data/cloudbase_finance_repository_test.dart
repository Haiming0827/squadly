import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/finance/data/repositories/cloudbase_finance_repository.dart';

void main() {
  group('CloudBaseFinanceRepository', () {
    test('scopes private asset query to the signed-in owner', () async {
      http.Request? capturedRequest;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode([
              {
                'id': 'asset-1',
                'user_id': 'user-a',
                'asset_type': 'savings',
                'name': '个人账户',
                'amount': 88.5,
                'note': 'private',
                'created_at': '2026-10-12T10:00:00Z',
                'updated_at': '2026-10-12T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CloudBaseFinanceRepository(
        client: client,
        currentUserId: () async => 'user-a',
      );

      final result = await repository.getMyPrivateAssets();

      expect(capturedRequest?.url.path, '/v1/rdb/rest/private_assets');
      expect(capturedRequest?.url.queryParameters['user_id'], 'eq.user-a');
      expect(capturedRequest?.url.queryParameters['select'], '*');
      expect(
        result.match((failure) => failure, (assets) => assets.single.amount),
        88.5,
      );
    });

    test(
      'does not issue a private asset query without an authenticated user',
      () async {
        var requestCount = 0;
        final client = PostgrestClient(
          'https://env.example/v1/rdb/rest',
          httpClient: MockClient((request) async {
            requestCount++;
            return http.Response('[]', 200, request: request);
          }),
        );
        addTearDown(client.dispose);
        final repository = CloudBaseFinanceRepository(
          client: client,
          currentUserId: () async => null,
        );

        final result = await repository.getMyPrivateAssets();

        expect(result.isLeft(), isTrue);
        expect(requestCount, 0);
      },
    );
  });
}
