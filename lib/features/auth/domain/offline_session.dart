/// A previously authenticated SDK session, usable only to unlock local records.
/// It contains no bearer/refresh token and grants no server access.
final class OfflineSession {
  const OfflineSession({required this.userId, required this.expiresAt});
  final String userId;
  final DateTime expiresAt;
  bool isValidAt(DateTime now) => userId.isNotEmpty && now.isBefore(expiresAt);
}

abstract interface class OfflineSessionSource {
  /// Null means the SDK has no session. Errors fail closed without deleting
  /// cached history. Expired sessions retain identity so expiry is not logout.
  Stream<OfflineSession?> watch();
}
