import 'route_models.dart';

abstract interface class RouteReader {
  Future<List<RouteCoordinate>> loadForMe({
    required String squadId,
    required String cardId,
    required int templateVersion,
    required String userId,
  });
}

final class RouteKeyMissing implements Exception {
  const RouteKeyMissing();
}

final class RouteDecryptionException implements Exception {
  const RouteDecryptionException();

  @override
  String toString() => 'RouteDecryptionException';
}
