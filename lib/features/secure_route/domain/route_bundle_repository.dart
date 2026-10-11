import 'route_models.dart';

/// Only the encrypted route and one currently signed-in device's envelope.
abstract interface class RouteBundleRepository {
  Future<EncryptedRouteBundle> loadForDevice({
    required String squadId,
    required String cardId,
    required String userId,
    required String deviceId,
  });
}

final class RouteBundleUnavailable implements Exception {
  const RouteBundleUnavailable();
}

final class RouteEnvelopeUnavailable implements Exception {
  const RouteEnvelopeUnavailable();
}
