import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/squad/data/datasources/cloudbase_squad_remote_datasource.dart';
import 'package:squadly/features/squad/data/repositories/squad_repository_impl.dart';

const _linkToken =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

final _squadResponse = {
  'id': 'squad-a',
  'name': '周末跑步',
  'description': null,
  'avatar_url': null,
  'max_members': 9,
  'created_by': 'user-a',
  'status': 'pending',
  'created_at': '2026-10-08T00:00:00Z',
};

void main() {
  test(
    'squad creation and invitation issuance only call controlled RPCs',
    () async {
      final requests = <http.Request>[];
      final client = PostgrestClient(
        'https://project.example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          requests.add(request);
          final response = request.url.path.endsWith('/create_squad')
              ? _squadResponse
              : {
                  'invitation_id': 'inv-a',
                  'code': 'AB12CD3456',
                  'link_token': _linkToken,
                  'expires_at': '2026-10-15T00:00:00Z',
                  'max_uses': 1,
                };
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final source = CloudBaseSquadRemoteDatasource(client);

      final squad = await source.createSquad(name: '周末跑步');
      final invitation = await source.issueInvitation(squadId: squad.id);

      expect(squad.id, 'squad-a');
      expect(invitation.code, 'AB12CD3456');
      expect(invitation.linkToken, _linkToken);
      expect(requests.map((r) => r.url.path), [
        '/v1/rdb/rest/rpc/create_squad',
        '/v1/rdb/rest/rpc/issue_invitation',
      ]);
      expect(jsonDecode(requests.first.body)['p_name'], '周末跑步');
      expect(jsonDecode(requests.last.body)['p_squad_id'], 'squad-a');
    },
  );

  test(
    'code and link redeem through the same RPC with distinct credentials',
    () async {
      final requests = <http.Request>[];
      final client = PostgrestClient(
        'https://project.example.test/v1/rdb/rest',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(_squadResponse),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final source = CloudBaseSquadRemoteDatasource(client);

      await source.redeemInvitation(credential: 'ab12cd3456');
      await source.redeemInvitation(
        credential: 'https://links.example.test/invite/$_linkToken',
      );

      expect(
        requests.map((request) => request.url.path),
        everyElement('/v1/rdb/rest/rpc/redeem_invitation'),
      );
      expect(jsonDecode(requests.first.body)['p_credential'], 'AB12CD3456');
      expect(jsonDecode(requests.last.body)['p_credential'], _linkToken);
    },
  );

  test('server capacity failure is exposed as squadFull', () async {
    final client = PostgrestClient(
      'https://project.example.test/v1/rdb/rest',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'squad_full'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final result = await SquadRepositoryImpl(
      CloudBaseSquadRemoteDatasource(client),
    ).redeemInvitation(credential: 'AB12CD3456');

    expect(result.swap().toNullable(), isA<SquadFullFailure>());
  });

  test('member projection never requests email or phone columns', () async {
    http.Request? captured;
    final client = PostgrestClient(
      'https://project.example.test/v1/rdb/rest',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': 'member-a',
              'squad_id': 'squad-a',
              'user_id': 'user-a',
              'role': 'captain',
              'joined_at': '2026-10-08T00:00:00Z',
              'profiles': {'nickname': '阿青', 'avatar_url': null},
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final members = await CloudBaseSquadRemoteDatasource(
      client,
    ).getSquadMembers(squadId: 'squad-a');

    expect(members.single.profiles?['nickname'], '阿青');
    expect(captured?.url.path, '/v1/rdb/rest/squad_members');
    final selection = captured?.url.queryParameters['select'];
    expect(selection, contains('profiles(nickname,avatar_url)'));
    expect(selection, isNot(contains('email')));
    expect(selection, isNot(contains('phone')));
  });

  test('non-captain invitation denial is a domain failure', () async {
    final client = PostgrestClient(
      'https://project.example.test/v1/rdb/rest',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'error': 'not_captain'}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final result = await SquadRepositoryImpl(
      CloudBaseSquadRemoteDatasource(client),
    ).issueInvitation(squadId: 'squad-a');

    expect(
      result.swap().toNullable(),
      const ServerFailure(message: '只有队长可以邀请成员'),
    );
  });
}
