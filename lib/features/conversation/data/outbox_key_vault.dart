import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class OutboxKeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class FlutterOutboxKeyVault implements OutboxKeyVault {
  FlutterOutboxKeyVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );

  @override
  Future<String?> read(String key) =>
      _storage.read(key: key, iOptions: _iosOptions);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value, iOptions: _iosOptions);
}
