import 'route_models.dart';

/// Only currently active devices of current squad members may be returned.
abstract interface class RouteKeyDirectory {
  Future<void> registerDevice(RouteRecipient device);
  Future<List<RouteRecipient>> listRecipients(String squadId);
}
