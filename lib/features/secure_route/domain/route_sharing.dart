import 'route_models.dart';

abstract interface class RouteSharePreparer {
  Future<EncryptedRouteBundle> prepare({
    required String userId,
    required String squadId,
    required String cardId,
    required int templateVersion,
    required List<RouteCoordinate> route,
    required Map<String, String> approvedPublicKeys,
    required bool explicitlyConfirmed,
  });
}

final class RouteShareNotConfirmedException implements Exception {
  const RouteShareNotConfirmedException();
}

final class UntrustedRouteDeviceException implements Exception {
  const UntrustedRouteDeviceException();
}

final class RouteDeviceRegistrationException implements Exception {
  const RouteDeviceRegistrationException();
}
