import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/food/data/repositories/cloudbase_food_repository.dart';

void main() {
  test('loads public candidates with squad votes mapped to scores', () async {
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        final response = request.url.path.endsWith('/food_spots')
            ? [
                {
                  'id': 'spot-1',
                  'squad_id': 'squad-1',
                  'name': '面馆',
                  'category': '正餐',
                  'average_cost': 35,
                  'calories_estimate': 600,
                  'added_by': 'user-a',
                  'created_at': '2026-10-12T10:00:00Z',
                  'address': null,
                  'note': null,
                },
              ]
            : [
                {'food_spot_id': 'spot-1', 'user_id': 'user-a', 'vote': 1},
                {'food_spot_id': 'spot-1', 'user_id': 'user-b', 'vote': -1},
              ];
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await CloudBaseFoodRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).getSquadFoodSpots(squadId: 'squad-1');

    expect(
      result.match((failure) => failure, (spots) => spots.single.score),
      0,
    );
  });

  test('upserts only the current user vote', () async {
    http.Request? capturedRequest;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);

    final result = await CloudBaseFoodRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).voteFoodSpot(foodSpotId: 'spot-1', vote: 1);

    expect(result.isRight(), isTrue);
    expect(capturedRequest?.url.path, '/v1/rdb/rest/food_votes');
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body, {'food_spot_id': 'spot-1', 'user_id': 'user-a', 'vote': 1});
  });
}
