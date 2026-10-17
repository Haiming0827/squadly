import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:postgrest/postgrest.dart';

import '../config/cloudbase_config.dart';
import 'cloudbase_pg_rest_client.dart';

/// PostgREST query interface backed by CloudBase's PostgreSQL REST endpoint.
/// It refreshes the bearer token for each request and never exposes schemas
/// other than CloudBase's public REST surface.
final class CloudBasePostgresClient {
  CloudBasePostgresClient({
    required CloudBaseConfig config,
    required AccessTokenReader accessTokenReader,
    http.Client? httpClient,
  }) : _httpClient = _CloudBaseAuthHttpClient(
         delegate: httpClient ?? http.Client(),
         accessTokenReader: accessTokenReader,
         publishableKey: config.publishableKey,
       ) {
    rest = PostgrestClient(
      config.postgresRestBaseUrl,
      headers: {'Authorization': 'Bearer ${config.publishableKey}'},
      httpClient: _httpClient,
    );
  }

  final http.Client _httpClient;
  late final PostgrestClient rest;

  void close() => _httpClient.close();
}

final class _CloudBaseAuthHttpClient extends http.BaseClient {
  _CloudBaseAuthHttpClient({
    required http.Client delegate,
    required AccessTokenReader accessTokenReader,
    required String publishableKey,
  }) : _delegate = delegate,
       _accessTokenReader = accessTokenReader,
       _publishableKey = publishableKey;

  final http.Client _delegate;
  final AccessTokenReader _accessTokenReader;
  final String _publishableKey;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final accessToken = await _accessTokenReader();
    final token = accessToken?.trim().isNotEmpty == true
        ? accessToken!.trim()
        : _publishableKey;
    final authenticated = http.StreamedRequest(request.method, request.url)
      ..contentLength = request.contentLength
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..headers['Authorization'] = 'Bearer $token';

    unawaited(request.finalize().pipe(authenticated.sink));
    return _delegate.send(authenticated);
  }

  @override
  void close() => _delegate.close();
}
