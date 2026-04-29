/// 数据层异常类型
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException: $message (code: $statusCode)';
}

class NetworkException implements Exception {
  final String? message;

  const NetworkException({this.message});

  @override
  String toString() => 'NetworkException: ${message ?? "No network connection"}';
}

class CacheException implements Exception {
  final String? message;

  const CacheException({this.message});

  @override
  String toString() => 'CacheException: ${message ?? "Cache error"}';
}
