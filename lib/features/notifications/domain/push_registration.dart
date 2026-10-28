/// Notification permission and delivery are best effort. Messages remain in
/// the conversation repository even when a push token cannot be registered.
enum PushRegistrationResult { registered, permissionRequired, unavailable }

abstract interface class PushTokenSource {
  String get provider;

  /// Whether this app build contains a delivery provider for this platform.
  Future<bool> isAvailable();

  /// Whether this installation is already allowed to show notifications.
  Future<bool> isAuthorized();

  /// Returns null when the platform or user does not permit notifications.
  Future<String?> requestToken();

  /// Stops native delivery for this installation (best effort by caller).
  Future<void> unregister();
}

abstract interface class PushDeviceIdStore {
  Future<String> loadOrCreate();
  Future<String?> loadExisting();
}

abstract interface class PushTokenRepository {
  Future<void> register({
    required String deviceId,
    required String provider,
    required String token,
  });

  Future<void> unregister({required String deviceId, required String provider});
}

final class PushRegistration {
  const PushRegistration({
    required this.source,
    required this.deviceIds,
    required this.repository,
  });

  final PushTokenSource source;
  final PushDeviceIdStore deviceIds;
  final PushTokenRepository repository;

  Future<PushRegistrationResult> register({
    bool requestPermission = false,
  }) async {
    if (!await source.isAvailable()) return PushRegistrationResult.unavailable;
    if (!requestPermission && !await source.isAuthorized()) {
      return PushRegistrationResult.permissionRequired;
    }
    final token = await source.requestToken();
    if (token == null || token.isEmpty) {
      if (!await source.isAuthorized()) {
        return PushRegistrationResult.permissionRequired;
      }
      return PushRegistrationResult.unavailable;
    }
    await repository.register(
      deviceId: await deviceIds.loadOrCreate(),
      provider: source.provider,
      token: token,
    );
    return PushRegistrationResult.registered;
  }

  /// Called while the account still has an authenticated session.
  Future<void> unregister() async {
    final deviceId = await deviceIds.loadExisting();
    try {
      if (deviceId != null) {
        await repository.unregister(
          deviceId: deviceId,
          provider: source.provider,
        );
      }
    } finally {
      await source.unregister();
    }
  }
}
