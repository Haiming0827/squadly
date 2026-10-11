/// Notification permission and delivery are best effort. Messages remain in
/// the conversation repository even when a push token cannot be registered.
enum PushRegistrationResult { registered, unavailable }

abstract interface class PushTokenSource {
  String get provider;

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

  Future<PushRegistrationResult> register() async {
    final token = await source.requestToken();
    if (token == null || token.isEmpty) {
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
