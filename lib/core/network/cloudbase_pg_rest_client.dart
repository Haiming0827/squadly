import 'package:dio/dio.dart';

import '../config/cloudbase_config.dart';

typedef AccessTokenReader = Future<String?> Function();

/// Small PostgREST transport for CloudBase PostgreSQL's public schema API.
/// Callers pass a table or `rpc/<function>` path, never a schema name.
final class CloudBasePgRestClient {
  CloudBasePgRestClient({
    required this._config,
    required this._accessTokenReader,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final CloudBaseConfig _config;
  final AccessTokenReader _accessTokenReader;
  final Dio _dio;

  Future<T?> request<T>({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? headers,
    bool returnRepresentation = false,
  }) async {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?$')
        .hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'Must be relative to public API');
    }
    final accessToken = await _accessTokenReader();
    final token = accessToken?.trim().isNotEmpty == true
        ? accessToken!.trim()
        : _config.publishableKey;
    final requestHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (data != null) 'Content-Type': 'application/json',
      if (returnRepresentation) 'Prefer': 'return=representation',
      ...?headers,
    };

    try {
      final response = await _dio.request<T>(
        '${_config.postgresRestBaseUrl}/$path',
        queryParameters: queryParameters,
        data: data,
        options: Options(method: method, headers: requestHeaders),
      );
      return response.data;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final serverMessage = switch (error.response?.data) {
        {'message': final String message} => message,
        {'error_description': final String message} => message,
        _ => null,
      };
      throw CloudBasePgRestException(
        statusCode: statusCode,
        message: serverMessage ?? 'CloudBase PostgreSQL request failed',
      );
    }
  }

  Future<T?> rpc<T>(String function, {Object? params}) =>
      request<T>(method: 'POST', path: 'rpc/$function', data: params);
}

final class CloudBasePgRestException implements Exception {
  const CloudBasePgRestException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CloudBasePgRestException($statusCode): $message';
}
