import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postgrest/postgrest.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/auth/data/repositories/personal_avatar_repository.dart';
import 'package:squadly/features/squad/domain/squad_avatar_format.dart';

void main() {
  test('avatar update is bound to owner and only modifies avatar_url', () async {
    http.Request? captured;
    final client = PostgrestClient(
      'https://example.com/rest',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"id":"alice"}',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final avatar =
        '$squadAvatarPrefix${base64Encode(File('test/features/squad/fixtures/avatar.png').readAsBytesSync())}';
    final result = await CloudBasePersonalAvatarRepository(
      client,
      'alice',
    ).save(avatar);
    expect(result.isRight(), true);
    expect(captured!.method, 'PATCH');
    expect(captured!.url.queryParameters['id'], 'eq.alice');
    expect(jsonDecode(captured!.body), {'avatar_url': avatar});
  });
  test('invalid avatar and signed-out owner never make a request', () async {
    var calls = 0;
    final client = PostgrestClient(
      'https://example.com/rest',
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('{}', 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    expect(
      (await CloudBasePersonalAvatarRepository(
        client,
        'alice',
      ).save('https://example.com/avatar')).getLeft().toNullable(),
      isA<ValidationFailure>(),
    );
    expect(
      (await CloudBasePersonalAvatarRepository(client, '').save(null))
          .getLeft()
          .toNullable(),
      isA<UnauthorizedFailure>(),
    );
    expect(calls, 0);
  });
  test(
    'permission failures and unexpected owner cannot become success',
    () async {
      var deny = true;
      final client = PostgrestClient(
        'https://example.com/rest',
        httpClient: MockClient(
          (request) async => http.Response(
            deny
                ? '{"code":"42501","message":"permission denied"}'
                : '{"id":"bob"}',
            deny ? 403 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      final repo = CloudBasePersonalAvatarRepository(client, 'alice');
      expect(
        (await repo.save(null)).getLeft().toNullable(),
        isA<PermissionDeniedFailure>(),
      );
      deny = false;
      expect(
        (await repo.save(null)).getLeft().toNullable(),
        isA<PermissionDeniedFailure>(),
      );
    },
  );
}
