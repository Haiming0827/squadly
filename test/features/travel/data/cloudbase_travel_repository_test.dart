import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/travel/data/repositories/cloudbase_travel_repository.dart';

void main() {
  test(
    'creates a travel plan with authenticated owner and ISO dates',
    () async {
      http.Request? capturedRequest;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'id': 'trip-1',
              'squad_id': 'squad-1',
              'title': '周末旅行',
              'destination': '杭州',
              'start_date': '2026-11-01',
              'end_date': '2026-11-03',
              'budget': 3000,
              'linked_fund_id': null,
              'notes': null,
              'created_by': 'user-a',
              'created_at': '2026-10-12T10:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = CloudBaseTravelRepository(
        client: client,
        currentUserId: () async => 'user-a',
      );

      final result = await repository.createTravelPlan(
        squadId: 'squad-1',
        title: '周末旅行',
        destination: '杭州',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 3),
        budget: 3000,
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['created_by'], 'user-a');
      expect(body['start_date'], '2026-11-01');
      expect(body['end_date'], '2026-11-03');
      expect(
        result.match((failure) => failure, (plan) => plan.destination),
        '杭州',
      );
    },
  );

  test('rejects an end date before the start date', () async {
    var requestCount = 0;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    final result =
        await CloudBaseTravelRepository(
          client: client,
          currentUserId: () async => 'user-a',
        ).createTravelPlan(
          squadId: 'squad-1',
          title: 'Trip',
          destination: 'Hangzhou',
          startDate: DateTime(2026, 11, 3),
          endDate: DateTime(2026, 11, 1),
          budget: 100,
        );

    expect(result.isLeft(), isTrue);
    expect(requestCount, 0);
  });
}
