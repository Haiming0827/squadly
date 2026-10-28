import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';

import 'package:squadly/features/conversation/data/cloudbase_conversation_repository.dart';

void main() {
  group('CloudBaseConversationRepository', () {
    test(
      'loads the public timeline projection through the PG RPC endpoint',
      () async {
        http.Request? capturedRequest;
        final client = PostgrestClient(
          'https://env.example/v1/rdb/rest',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              jsonEncode([
                {
                  'id': 'message-1',
                  'squad_id': 'squad-1',
                  'sender_id': 'user-1',
                  'author': {'nickname': '小明'},
                  'kind': 'text',
                  'body': '周末见',
                  'card_id': null,
                  'card_snapshot': null,
                  'reply_to_message_id': null,
                  'client_nonce': 'nonce-1',
                  'created_at': '2026-10-12T10:00:00Z',
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = CloudBaseConversationRepository(client);

        final result = await repository.loadRecent('squad-1');

        expect(capturedRequest?.method, 'POST');
        expect(
          capturedRequest?.url.path,
          '/v1/rdb/rest/rpc/page_squad_timeline',
        );
        final requestBody =
            jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
        expect(requestBody['p_squad_id'], 'squad-1');
        expect(requestBody['p_limit'], 50);
        expect(
          result.match((failure) => failure, (entries) => entries.single.text),
          '周末见',
        );
      },
    );

    test('maps malformed projections to a safe server failure', () async {
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient(
          (request) async =>
              http.Response('[{"kind":"unknown"}]', 200, request: request),
        ),
      );
      addTearDown(client.dispose);

      final result = await CloudBaseConversationRepository(client)
          .loadRecent('squad-1');

      expect(result.isLeft(), isTrue);
    });

    test('loads plan messages through the plan-scoped RPC', () async {
      http.Request? capturedRequest;
      final client = PostgrestClient(
        'https://env.example/v1/rdb/rest',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode([
              {
                'id': 'message-plan-1',
                'squad_id': 'squad-1',
                'plan_id': 'plan-1',
                'sender_id': 'user-1',
                'author': {'nickname': '小明'},
                'kind': 'text',
                'body': '计划讨论',
                'card_id': null,
                'card_snapshot': null,
                'reply_to_message_id': null,
                'client_nonce': 'nonce-plan-1',
                'created_at': '2026-10-12T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final result = await CloudBaseConversationRepository(client)
          .loadRecent('squad-1', planId: 'plan-1');

      expect(
        capturedRequest?.url.path,
        '/v1/rdb/rest/rpc/page_squad_plan_discussion',
      );
      expect(jsonDecode(capturedRequest!.body), {
        'p_squad_id': 'squad-1',
        'p_plan_id': 'plan-1',
        'p_limit': 50,
      });
      expect(
        result.match((failure) => failure, (entries) => entries.single.planId),
        'plan-1',
      );
    });
  });
}
