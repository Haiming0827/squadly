import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/features/social/data/cloudbase_social_repository.dart';
import 'package:squadly/features/social/domain/entities/external_data_item.dart';

void main() {
  test(
    'imports an item under the authenticated owner, ignoring supplied user',
    () async {
      http.Request? request;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((value) async {
          request = value;
          final body = jsonDecode(value.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(_itemRow()..['user_id'] = body['user_id']),
            201,
            headers: {'content-type': 'application/json'},
            request: value,
          );
        }),
      );
      addTearDown(client.dispose);

      final result = await CloudBaseSocialRepository(
        client: client,
        currentUserId: () async => 'user-a',
      ).importDataItem(item: _item(userId: 'attacker'));

      final body = jsonDecode(request!.body) as Map<String, dynamic>;
      expect(body['user_id'], 'user-a');
      expect(body['metric_value'], '8,420');
      expect(body.containsKey('id'), isFalse);
      expect(
        result.match((failure) => failure, (item) => item.userId),
        'user-a',
      );
    },
  );

  test('rejects invalid private material before making a request', () async {
    var requests = 0;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);

    final result = await CloudBaseSocialRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).importDataItem(item: _item(rangeEnd: DateTime(2026, 10, 1)));

    expect(result.isLeft(), isTrue);
    expect(requests, 0);
  });

  test(
    'publishes through snapshot RPC and maps only the copied post',
    () async {
      http.Request? request;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((value) async {
          request = value;
          return http.Response(
            jsonEncode(_postRow()),
            200,
            headers: {'content-type': 'application/json'},
            request: value,
          );
        }),
      );
      addTearDown(client.dispose);

      final result =
          await CloudBaseSocialRepository(
            client: client,
            currentUserId: () async => 'user-a',
          ).publishDataPost(
            squadId: 'squad-1',
            dataItemId: 'private-item-id',
            title: '  今日运动  ',
            body: '完成训练',
            template: 'story',
            visibility: 'selected',
            visibleToUserIds: const ['user-b'],
          );

      final payload = jsonDecode(request!.body) as Map<String, dynamic>;
      expect(request!.url.path, endsWith('/rpc/publish_social_post'));
      expect(payload['p_data_item_id'], 'private-item-id');
      expect(payload['p_title'], '今日运动');
      expect(payload['p_visible_to_user_ids'], ['user-b']);
      expect(payload.containsKey('source_item_id'), isFalse);
      expect(
        result.match((failure) => failure, (post) => post.metricValue),
        '8,420',
      );
      expect(
        result.match((failure) => failure, (post) => post.visibleToUserIds),
        ['user-b'],
      );
    },
  );

  test('reaction changes use the visibility-checking RPC', () async {
    http.Request? request;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((value) async {
        request = value;
        return http.Response('true', 200, request: value);
      }),
    );
    addTearDown(client.dispose);

    final result = await CloudBaseSocialRepository(
      client: client,
      currentUserId: () async => 'user-a',
    ).togglePostReaction(postId: 'post-1', squadId: 'squad-1');

    expect(request!.url.path, endsWith('/rpc/toggle_social_post_reaction'));
    expect(jsonDecode(request!.body), {
      'p_post_id': 'post-1',
      'p_squad_id': 'squad-1',
    });
    expect(result.match((failure) => failure, (changed) => changed), isTrue);
  });

  test(
    'a later polling result recovers after a transient feed failure',
    () async {
      var postRequests = 0;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/social_posts')) {
            postRequests++;
            if (postRequests == 1) {
              return http.Response(
                jsonEncode({'code': 'XX000', 'message': 'temporary failure'}),
                500,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            return http.Response(
              jsonEncode([_postRow()]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final iterator = StreamIterator(
        CloudBaseSocialRepository(
          client: client,
          currentUserId: () async => 'user-a',
          pollInterval: const Duration(milliseconds: 10),
        ).watchPosts('squad-1'),
      );
      addTearDown(iterator.cancel);

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current.isLeft(), isTrue);
      expect(
        await iterator.moveNext().timeout(const Duration(seconds: 1)),
        isTrue,
      );
      expect(iterator.current.isRight(), isTrue);
      expect(postRequests, 2);
    },
  );

  test('stops polling when the feed subscription is cancelled', () async {
    var requests = 0;
    final client = PostgrestClient(
      'https://env.example/v1/rdb/rest',
      httpClient: MockClient((request) async {
        requests++;
        final response = request.url.path.endsWith('/social_posts')
            ? jsonEncode([_postRow()])
            : '[]';
        return http.Response(
          response,
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final iterator = StreamIterator(
      CloudBaseSocialRepository(
        client: client,
        currentUserId: () async => 'user-a',
        pollInterval: const Duration(milliseconds: 20),
      ).watchPosts('squad-1'),
    );
    addTearDown(iterator.cancel);

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.isRight(), isTrue);
    await iterator.cancel();
    final requestsAtCancellation = requests;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(requestsAtCancellation, 2);
    expect(requests, requestsAtCancellation);
  });

  test(
    'does not access the service without an authenticated identity',
    () async {
      var requests = 0;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          requests++;
          return http.Response('{}', 200, request: request);
        }),
      );
      addTearDown(client.dispose);

      final result = await CloudBaseSocialRepository(
        client: client,
        currentUserId: () async => null,
      ).getMyImportedData();

      expect(result.isLeft(), isTrue);
      expect(requests, 0);
    },
  );
}

ExternalDataItem _item({String userId = 'user-a', DateTime? rangeEnd}) =>
    ExternalDataItem(
      id: 'local-id',
      userId: userId,
      source: 'apple_health',
      sourceLabel: 'Apple 健康',
      category: 'steps',
      title: '今日步数',
      summary: '步行活跃',
      value: '8,420',
      unit: '步',
      rangeStart: DateTime.utc(2026, 10, 18),
      rangeEnd: rangeEnd ?? DateTime.utc(2026, 10, 18, 23, 59),
      importedAt: DateTime.utc(2026, 10, 18),
      trend: const [3, 4, 5],
    );

Map<String, dynamic> _itemRow() => {
  'id': 'item-1',
  'user_id': 'user-a',
  'source': 'apple_health',
  'source_label': 'Apple 健康',
  'category': 'steps',
  'title': '今日步数',
  'summary': '步行活跃',
  'metric_value': '8,420',
  'metric_unit': '步',
  'range_start': '2026-10-18T00:00:00Z',
  'range_end': '2026-10-18T23:59:00Z',
  'imported_at': '2026-10-18T00:00:00Z',
  'trend': [3, 4, 5],
};

Map<String, dynamic> _postRow() => {
  'id': 'post-1',
  'squad_id': 'squad-1',
  'author_id': 'user-a',
  'author_name': 'Haoming',
  'title': '今日运动',
  'body': '完成训练',
  'template': 'story',
  'visibility': 'selected',
  'visible_to_user_ids': ['user-b'],
  'source_label': 'Apple 健康',
  'metric_value': '8,420',
  'metric_unit': '步',
  'range_start': '2026-10-18T00:00:00Z',
  'range_end': '2026-10-18T23:59:00Z',
  'created_at': '2026-10-18T01:00:00Z',
  'trend': [3, 4, 5],
};
