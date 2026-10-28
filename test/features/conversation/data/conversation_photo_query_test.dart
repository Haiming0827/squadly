import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/data/cloudbase_conversation_repository.dart';
import 'package:squadly/features/conversation/domain/timeline_entry.dart';

Map<String, dynamic> _photo() => {
  'id': 'photo',
  'squad_id': 'squad',
  'sender_id': 'author',
  'author': {'nickname': '队友'},
  'kind': 'photo',
  'photo_id': 'media',
  'photo': {
    'id': 'media',
    'width': 4,
    'height': 3,
    'byte_length': 600,
    'revoked': false,
  },
  'client_nonce': 'nonce',
  'created_at': '2026-10-28T00:00:00Z',
};
void main() {
  test(
    'atomic head preserves large revision, empty state and member denial',
    () async {
      Object? response = {'revision': '9007199254740993', 'photo': _photo()};
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/rdb/rest/rpc/get_squad_photo_head');
          expect(jsonDecode(request.body), {'p_squad_id': 'squad'});
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = CloudBaseConversationRepository(client);
      final first = (await repo.photoHead('squad')).getRight().toNullable()!;
      expect(first.revision, '9007199254740993');
      expect(first.photo?.id, 'photo');
      response = {'revision': '9007199254740994', 'photo': null};
      final empty = (await repo.photoHead('squad')).getRight().toNullable()!;
      expect(empty.revision, '9007199254740994');
      expect(empty.photo, isNull);
      response = null;
      expect(
        (await repo.photoHead('squad')).getLeft().toNullable(),
        isA<PermissionDeniedFailure>(),
      );
    },
  );
  for (final invalid in [
    '-1',
    '+1',
    '01',
    '1.0',
    '1e3',
    ' 1',
    '9223372036854775808',
    1,
    null,
  ]) {
    test('head rejects invalid revision $invalid', () async {
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'revision': invalid, 'photo': null}),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.dispose);
      expect(
        (await CloudBaseConversationRepository(client).photoHead('squad'))
            .getLeft()
            .toNullable(),
        isA<ServerFailure>(),
      );
    });
  }
  for (final invalid in [
    'wrong_squad',
    'revoked',
    'zero_photo',
    'missing_photo',
  ]) {
    test('head rejects invalid $invalid projection', () async {
      final photo = _photo();
      if (invalid == 'wrong_squad') photo['squad_id'] = 'other';
      if (invalid == 'revoked') (photo['photo'] as Map)['revoked'] = true;
      final response = {
        'revision': invalid == 'zero_photo' ? '0' : '1',
        'photo': photo,
      };
      if (invalid == 'missing_photo') response.remove('photo');
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.dispose);
      expect(
        (await CloudBaseConversationRepository(client).photoHead('squad'))
            .isLeft(),
        isTrue,
      );
    });
  }
  test(
    'latest photo uses filtered RPC limit one and stable photo cursor',
    () async {
      final requests = <http.Request>[];
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([_photo()]),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = CloudBaseConversationRepository(client);
      final result = await repo.pagePhotos(
        'squad',
        limit: 1,
        before: TimelineCursor(
          createdAt: DateTime.utc(2026, 10, 29),
          id: 'cursor',
        ),
      );
      expect(result.isRight(), isTrue, reason: result.toString());
      expect(result.getOrElse((_) => []).single.id, 'photo');
      expect(requests.single.url.path, '/v1/rdb/rest/rpc/page_squad_photos');
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['p_limit'], 1);
      expect(body['p_before_id'], 'cursor');
      expect(body.containsKey('p_plan_id'), isFalse);
    },
  );
  for (final mutation in ['wrong_squad', 'revoked', 'text']) {
    test('photo-only RPC rejects $mutation projection', () async {
      final value = _photo();
      if (mutation == 'wrong_squad') value['squad_id'] = 'other';
      if (mutation == 'revoked') (value['photo'] as Map)['revoked'] = true;
      if (mutation == 'text') {
        value['kind'] = 'text';
        value['body'] = 'text';
        value.remove('photo');
        value.remove('photo_id');
      }
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([value]),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.dispose);
      expect(
        (await CloudBaseConversationRepository(client).pagePhotos('squad'))
            .isLeft(),
        isTrue,
      );
    });
  }
  test(
    'specific parent returns only the original identity and null when missing',
    () async {
      Object? response = _photo();
      final client = PostgrestClient(
        'https://example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/rdb/rest/rpc/get_squad_photo');
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = CloudBaseConversationRepository(client);
      final found = await repo.findPhoto(squadId: 'squad', messageId: 'photo');
      expect(found.isRight(), isTrue, reason: found.toString());
      expect(found.getOrElse((_) => null)!.id, 'photo');
      expect(
        (await repo.findPhoto(squadId: 'squad', messageId: 'another')).isLeft(),
        isTrue,
      );
      response = null;
      expect(
        (await repo.findPhoto(
          squadId: 'squad',
          messageId: 'photo',
        )).getOrElse((_) => throw StateError('Unexpected failure')),
        isNull,
      );
    },
  );
}
