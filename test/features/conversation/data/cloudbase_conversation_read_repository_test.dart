import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/conversation/data/cloudbase_conversation_read_repository.dart';
import 'package:squadly/features/conversation/domain/conversation_target.dart';
import 'package:squadly/features/conversation/domain/message_read_receipt.dart';

const _target = ConversationTarget(squadId: 'squad-a', planId: 'plan-a');

Map<String, Object> _member(String id, String status) => {
  'membership_id': 'membership-$id',
  'user_id': 'user-$id',
  'nickname': '成员$id',
  'status': status,
};

Map<String, Object> _receipt(String id) => {
  'message_id': id,
  'members': [
    _member('a', 'read'),
    _member('b', 'unread'),
    _member('c', 'not_applicable'),
  ],
};

PostgrestClient _client(
  FutureOr<http.Response> Function(http.Request) handler,
) => PostgrestClient(
  'https://staging.example/v1/rdb/rest',
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);

http.Response _json(Object? value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('advance sends only the thread and message identity', () async {
    http.Request? request;
    final client = _client((value) {
      request = value;
      return _json(true);
    });
    addTearDown(client.dispose);
    final result = await CloudBaseConversationReadRepository(client)
        .advance(target: _target, messageId: 'message-1');
    expect(result.isRight(), isTrue);
    expect(request?.method, 'POST');
    expect(
      request?.url.path,
      endsWith('/rpc/advance_conversation_read_cursor'),
    );
    expect(jsonDecode(request!.body), {
      'p_squad_id': 'squad-a',
      'p_plan_id': 'plan-a',
      'p_message_id': 'message-1',
    });
  });

  test('general conversation sends an explicit null plan scope', () async {
    final client = _client((request) {
      expect(jsonDecode(request.body)['p_plan_id'], isNull);
      return _json(true);
    });
    addTearDown(client.dispose);
    expect(
      (await CloudBaseConversationReadRepository(client).advance(
        target: const ConversationTarget(squadId: 'squad-a'),
        messageId: 'message-1',
      )).isRight(),
      isTrue,
    );
  });

  test(
    'loads a batch with distinct read, unread and inapplicable states',
    () async {
      final client = _client((request) {
        expect(request.url.path, endsWith('/rpc/get_message_read_receipts'));
        expect(jsonDecode(request.body), {
          'p_squad_id': 'squad-a',
          'p_plan_id': 'plan-a',
          'p_message_ids': ['message-1'],
        });
        return _json([_receipt('message-1')]);
      });
      addTearDown(client.dispose);
      final result = await CloudBaseConversationReadRepository(client)
          .loadForMessages(target: _target, messageIds: ['message-1']);
      final rows = result.getOrElse(
        (failure) => throw StateError('Unexpected failure'),
      );
      expect(rows.single.readCount, 1);
      expect(rows.single.participantCount, 2);
      expect(
        rows.single.members.last.status,
        ConversationReadStatus.notApplicable,
      );
      expect(() => rows.clear(), throwsUnsupportedError);
      expect(() => rows.single.members.clear(), throwsUnsupportedError);
    },
  );

  test('snapshots requested message IDs before awaiting transport', () async {
    final gate = Completer<http.Response>();
    final client = _client((request) => gate.future);
    addTearDown(client.dispose);
    final ids = ['message-1'];
    final pending = CloudBaseConversationReadRepository(client)
        .loadForMessages(target: _target, messageIds: ids);
    ids[0] = 'different-message';
    gate.complete(_json([_receipt('message-1')]));
    expect((await pending).isRight(), isTrue);
  });

  test(
    'rejects invalid targets and batch boundaries without a request',
    () async {
      var requests = 0;
      final client = _client((request) {
        requests++;
        return _json(true);
      });
      addTearDown(client.dispose);
      final repository = CloudBaseConversationReadRepository(client);
      for (final ids in [
        [''],
        ['message-1', 'message-1'],
        List.generate(51, (i) => 'message-$i'),
      ]) {
        expect(
          (await repository.loadForMessages(
            target: _target,
            messageIds: ids,
          )).isLeft(),
          isTrue,
        );
      }
      for (final target in [
        const ConversationTarget(squadId: ''),
        const ConversationTarget(squadId: 'squad-a', planId: ''),
      ]) {
        expect(
          (await repository.advance(target: target, messageId: 'm')).isLeft(),
          isTrue,
        );
      }
      expect(
        (await repository.advance(target: _target, messageId: '')).isLeft(),
        isTrue,
      );
      expect(
        (await repository.loadForMessages(
          target: _target,
          messageIds: [],
        )).isRight(),
        isTrue,
      );
      expect(requests, 0);
    },
  );

  test(
    'accepts the maximum batch of 50 without extra per-message requests',
    () async {
      var requests = 0;
      final ids = List.generate(50, (i) => 'message-$i');
      final client = _client((request) {
        requests++;
        return _json(ids.map(_receipt).toList());
      });
      addTearDown(client.dispose);
      expect(
        (await CloudBaseConversationReadRepository(
          client,
        ).loadForMessages(target: _target, messageIds: ids)).isRight(),
        isTrue,
      );
      expect(requests, 1);
    },
  );

  final invalidResponses = <String, Object?>{
    'non-list response': {},
    'missing message': [],
    'unrequested message': [_receipt('other-message')],
    'unknown status': [
      {
        'message_id': 'message-1',
        'members': [_member('a', 'unknown')],
      },
    ],
    'duplicate member': [
      {
        'message_id': 'message-1',
        'members': [_member('a', 'read'), _member('a', 'unread')],
      },
    ],
    'too many members': [
      {
        'message_id': 'message-1',
        'members': List.generate(10, (i) => _member('$i', 'read')),
      },
    ],
    'missing nickname': [
      {
        'message_id': 'message-1',
        'members': [
          {'membership_id': 'a', 'user_id': 'a', 'status': 'read'},
        ],
      },
    ],
  };
  for (final entry in invalidResponses.entries) {
    test('${entry.key} stays unavailable instead of becoming unread', () async {
      final client = _client((request) => _json(entry.value));
      addTearDown(client.dispose);
      final result = await CloudBaseConversationReadRepository(client)
          .loadForMessages(target: _target, messageIds: ['message-1']);
      expect(
        result.match((failure) => failure, (_) => null),
        const Failure.server(message: '已读状态暂不可用'),
      );
    });
  }

  test(
    'maps the CloudBase permission envelope for both receipt RPCs',
    () async {
      final client = _client(
        (request) => _json({
          'code': 'DATABASE_42501',
          'message': 'conversation_read_forbidden',
          'requestId': 'private-request-marker',
        }, status: 403),
      );
      addTearDown(client.dispose);
      final repository = CloudBaseConversationReadRepository(client);
      const expected = Failure.permissionDenied(message: '无权查看或更新此会话已读状态');
      expect(
        (await repository.advance(
          target: _target,
          messageId: 'message-1',
        )).match((failure) => failure, (_) => null),
        expected,
      );
      expect(
        (await repository.loadForMessages(
          target: _target,
          messageIds: ['message-1'],
        )).match((failure) => failure, (_) => null),
        expected,
      );
    },
  );

  test(
    'maps permission denial without retaining sensitive backend details',
    () async {
      final client = _client(
        (request) => _json({
          'code': '42501',
          'message': 'private message text',
          'details': 'private-health-value',
        }, status: 403),
      );
      addTearDown(client.dispose);
      final result = await CloudBaseConversationReadRepository(client)
          .loadForMessages(target: _target, messageIds: ['message-1']);
      expect(
        result.match((failure) => failure, (_) => null),
        const Failure.permissionDenied(message: '无权查看或更新此会话已读状态'),
      );
      expect(result.toString(), isNot(contains('private message text')));
      expect(result.toString(), isNot(contains('private-health-value')));
    },
  );

  test(
    'does not treat an invalid acknowledgement as a successful write',
    () async {
      final client = _client((request) => _json({'ok': true}));
      addTearDown(client.dispose);
      expect(
        (await CloudBaseConversationReadRepository(
          client,
        ).advance(target: _target, messageId: 'message-1')).isLeft(),
        isTrue,
      );
    },
  );

  test('transport failure stays safe and retryable', () async {
    final client = _client(
      (request) => throw StateError('secret transport payload'),
    );
    addTearDown(client.dispose);
    final result = await CloudBaseConversationReadRepository(client)
        .advance(target: _target, messageId: 'message-1');
    expect(
      result.match((failure) => failure, (_) => null),
      const Failure.network(message: '无法同步已读状态'),
    );
    expect(result.toString(), isNot(contains('secret transport payload')));
  });
}
