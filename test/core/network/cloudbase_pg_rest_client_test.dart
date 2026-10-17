import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/config/cloudbase_config.dart';
import 'package:squadly/core/network/cloudbase_pg_rest_client.dart';

void main() {
  final config = CloudBaseConfig.fromValues(
    useDemo: 'false',
    environmentId: 'squadly-test-123456',
    region: 'ap-shanghai',
    publishableKey: 'public-publishable-key-for-tests',
  );

  test('sends CloudBase access token to the PG REST endpoint', () async {
    final adapter = _RecordingAdapter();
    final client = CloudBasePgRestClient(
      config: config,
      accessTokenReader: () async => 'user-access-token',
      dio: Dio()..httpClientAdapter = adapter,
    );

    final result = await client.request<Map<String, dynamic>>(
      method: 'GET',
      path: 'profiles',
      queryParameters: {'select': 'id,nickname', 'id': 'eq.user-1'},
    );

    expect(result, {'ok': true});
    expect(
      adapter.request!.uri.host,
      'squadly-test-123456.api.tcloudbasegateway.com',
    );
    expect(adapter.request!.uri.path, '/v1/rdb/rest/profiles');
    expect(
      adapter.request!.headers['Authorization'],
      'Bearer user-access-token',
    );
    expect(adapter.request!.uri.queryParameters['id'], 'eq.user-1');
  });

  test(
    'falls back to the public key when no user session is available',
    () async {
      final adapter = _RecordingAdapter();
      final client = CloudBasePgRestClient(
        config: config,
        accessTokenReader: () async => null,
        dio: Dio()..httpClientAdapter = adapter,
      );

      await client.rpc<void>('read_public_status', params: {'p_id': 'one'});

      expect(adapter.request!.uri.path, '/v1/rdb/rest/rpc/read_public_status');
      expect(
        adapter.request!.headers['Authorization'],
        'Bearer public-publishable-key-for-tests',
      );
    },
  );

  test('rejects paths that can escape the public REST endpoint', () async {
    final client = CloudBasePgRestClient(
      config: config,
      accessTokenReader: () async => null,
    );

    await expectLater(
      client.request(method: 'GET', path: '../auth/users'),
      throwsArgumentError,
    );
  });
}

final class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
