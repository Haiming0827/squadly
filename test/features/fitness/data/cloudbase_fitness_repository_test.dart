import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/fitness/data/repositories/cloudbase_fitness_repository.dart';

void main() {
  group('CloudBaseFitnessRepository', () {
    test(
      'limits calories query to the authenticated owner and requested day',
      () async {
        http.Request? capturedRequest;
        final client = PostgrestClient(
          'https://env.example/v1/rdb/rest',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode([
                {'calories_burned': 325},
                {'calories_burned': null},
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = CloudBaseFitnessRepository(
          client: client,
          currentUserId: () async => 'user-a',
        );

        final result = await repository.getDailyCaloriesBurned(
          userId: 'user-a',
          date: DateTime(2026, 10, 12),
        );

        expect(capturedRequest?.url.queryParameters['user_id'], 'eq.user-a');
        expect(
          capturedRequest?.url.queryParameters['recorded_date'],
          'eq.2026-10-12',
        );
        expect(result.match((failure) => failure, (calories) => calories), 325);
      },
    );

    test(
      'rejects calorie lookup for another user before querying the database',
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
        final repository = CloudBaseFitnessRepository(
          client: client,
          currentUserId: () async => 'user-a',
        );

        final result = await repository.getDailyCaloriesBurned(
          userId: 'user-b',
          date: DateTime(2026, 10, 12),
        );

        expect(result.isLeft(), isTrue);
        expect(requestCount, 0);
      },
    );
  });
}
