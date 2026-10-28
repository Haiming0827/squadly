import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/error/failures.dart';
import 'package:squadly/features/photos/data/cloudbase_photo_repository.dart';
import 'package:squadly/features/photos/domain/photo.dart';

const squad = '10000000-0000-4000-8000-000000000001';
const message = '10000000-0000-4000-8000-000000000002';
const media = '10000000-0000-4000-8000-000000000003';
const nonce = '10000000-0000-4000-8000-000000000004';
const digest =
    '9c4ad0cc80a44a2d234c284e474e8feff187fb71a568f3b09d6c5737e49e0cd5';
const credentials = PhotoCredentials(
  userId: 'user-a',
  accessToken: 'user-a-token',
);
final endpoint = Uri.parse('https://env-id.app.tcloudbase.com/photos');
final bytes = File('test/features/photos/fixtures/sanitized.jpg')
    .readAsBytesSync();
PhotoDraft draft({String user = 'user-a', String? parent}) => PhotoDraft(
  target: PhotoTarget(
    userId: user,
    squadId: squad,
    squadName: '测试队',
    replyToMessageId: parent,
  ),
  image: PhotoImage(bytes: bytes, width: 4, height: 3, sha256: digest),
  clientNonce: nonce,
  preparedAt: DateTime.utc(2026, 10, 27),
);
Map<String, Object?> published({String user = 'user-a', String? parent}) => {
  'message_id': message,
  'media_id': media,
  'squad_id': squad,
  'author_id': user,
  'client_nonce': nonce,
  'published_at': '2026-10-27T08:00:00Z',
  'reply_to_message_id': parent,
};
ResponseBody json(Object? value, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);
Dio dioWith(FutureOr<ResponseBody> Function(RequestOptions) handle) =>
    Dio()..httpClientAdapter = _Adapter(handle);
CloudBasePhotoRepository repository(
  Dio dio, {
  PhotoCredentialsReader? reader,
}) => CloudBasePhotoRepository(
  userId: 'user-a',
  endpoint: endpoint,
  credentials: reader ?? () async => credentials,
  dio: dio,
);
Map<String, dynamic> body(RequestOptions options) => options.data is String
    ? jsonDecode(options.data as String) as Map<String, dynamic>
    : Map<String, dynamic>.from(options.data as Map);

void main() {
  test('publishes only prepared content and fixed target; retries retain nonce and bytes', () async {
    final calls = <Map<String, dynamic>>[];
    final repo = repository(
      dioWith((o) {
        expect(o.uri, endpoint);
        expect(o.headers['Authorization'], 'Bearer user-a-token');
        expect(o.followRedirects, isFalse);
        calls.add(body(o));
        return json(published(parent: message));
      }),
    );
    final d = draft(parent: message);
    final first = await repo.publish(d);
    final second = await repo.publish(d);
    expect(first.isRight(), isTrue);
    expect(second.isRight(), isTrue);
    expect(calls, hasLength(2));
    expect(calls[0], calls[1]);
    expect(calls[0], {
      'action': 'publish',
      'squad_id': squad,
      'client_nonce': nonce,
      'source_sha256': digest,
      'reply_to_message_id': message,
      'bytes': base64Encode(bytes),
    });
    first.fold((f) => fail('$f'), (photo) {
      expect(photo.authorId, 'user-a');
      expect(photo.replyToMessageId, message);
      expect(photo.publishedAt.isUtc, isTrue);
    });
  });
  test(
    'wrong draft owner and session account cannot send original image',
    () async {
      var calls = 0;
      final dio = dioWith((o) {
        calls++;
        return json(published());
      });
      expect(
        (await repository(dio).publish(draft(user: 'user-b'))).isLeft(),
        isTrue,
      );
      final changed = repository(
        dio,
        reader: () async =>
            const PhotoCredentials(userId: 'user-b', accessToken: 'b'),
      );
      expect((await changed.publish(draft())).isLeft(), isTrue);
      expect(calls, 0);
    },
  );
  test('account switch while response is pending discards publication and loaded bytes', () async {
    var current = credentials;
    final dio = dioWith((o) {
      current = const PhotoCredentials(userId: 'user-b', accessToken: 'b');
      return json(published());
    });
    final result = await repository(
      dio,
      reader: () async => current,
    ).publish(draft());
    expect(result.getLeft().toNullable(), isA<UnauthorizedFailure>());
  });
  test(
    'publication response must match original author, squad, nonce and parent',
    () async {
      for (final change in [
        {'author_id': 'user-b'},
        {'squad_id': media},
        {'client_nonce': media},
        {'reply_to_message_id': message},
        {'media_id': 'not-uuid'},
        {'published_at': 'bad'},
      ]) {
        final repo = repository(
          dioWith((o) => json({...published(), ...change})),
        );
        expect(
          (await repo.publish(draft())).isLeft(),
          isTrue,
          reason: change.toString(),
        );
      }
    },
  );
  test(
    'load verifies checksum/header and exposes immutable bytes with no URL',
    () async {
      final repo = repository(
        dioWith((o) {
          expect(body(o), {
            'action': 'load',
            'squad_id': squad,
            'message_id': message,
          });
          return json({
            'bytes': base64Encode(bytes),
            'width': 4,
            'height': 3,
            'sha256': digest,
          });
        }),
      );
      final result = await repo.load(squadId: squad, messageId: message);
      result.fold((f) => fail('$f'), (photo) {
        expect(photo.bytes, bytes);
        expect(photo.sha256, digest);
        expect(() => photo.bytes[0] = 0, throwsUnsupportedError);
      });
      for (final patch in [
        {'sha256': 'a' * 64},
        {'width': 10},
        {'url': 'https://private.invalid'},
        {'bytes': 'invalid'},
      ]) {
        final invalid = repository(
          dioWith(
            (o) => json({
              'bytes': base64Encode(bytes),
              'width': 4,
              'height': 3,
              'sha256': digest,
              ...patch,
            }),
          ),
        );
        expect(
          (await invalid.load(squadId: squad, messageId: message)).isLeft(),
          isTrue,
        );
      }
    },
  );
  test('load discards bytes after switching account during download', () async {
    var session = credentials;
    final repo = repository(
      dioWith((o) {
        session = const PhotoCredentials(userId: 'user-b', accessToken: 'b');
        return json({
          'bytes': base64Encode(bytes),
          'width': 4,
          'height': 3,
          'sha256': digest,
        });
      }),
      reader: () async => session,
    );
    final result = await repo.load(squadId: squad, messageId: message);
    expect(result.getLeft().toNullable(), isA<UnauthorizedFailure>());
  });
  test('revoke preserves target and maps safe errors without leaking upstream data', () async {
    final repo = repository(
      dioWith((o) {
        expect(body(o), {
          'action': 'revoke',
          'squad_id': squad,
          'message_id': message,
        });
        return json({'revoked': true});
      }),
    );
    expect(
      (await repo.revoke(squadId: squad, messageId: message)).isRight(),
      isTrue,
    );
    for (final error in [
      'not_member',
      'revoked',
      'nonce_conflict',
      'invalid_reply',
      'rate_limited',
      {'sensitive': 'value'},
    ]) {
      final failed = repository(
        dioWith(
          (o) => json({'error': error, 'diagnostic': 'private info'}, 403),
        ),
      );
      final result = await failed.revoke(squadId: squad, messageId: message);
      expect(result.isLeft(), isTrue);
      expect(result.toString(), isNot(contains('private info')));
    }
  });
  test('invalid JPEG/digest and non-gateway endpoints fail before any HTTP request', () async {
    var calls = 0;
    final dio = dioWith((o) {
      calls++;
      return json(published());
    });
    final d = draft();
    for (final image in [
      PhotoImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 4,
        height: 3,
        sha256: digest,
      ),
      PhotoImage(bytes: bytes, width: 4, height: 3, sha256: 'b' * 64),
    ]) {
      expect(
        (await repository(dio).publish(d.copyWith(image: image))).isLeft(),
        isTrue,
      );
    }
    expect(calls, 0);
    expect(
      () => CloudBasePhotoRepository(
        userId: 'user-a',
        endpoint: Uri.parse('https://evil.test'),
        credentials: () async => credentials,
      ),
      throwsArgumentError,
    );
  });
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.handle);
  final FutureOr<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async => handle(options);
  @override
  void close({bool force = false}) {}
}
