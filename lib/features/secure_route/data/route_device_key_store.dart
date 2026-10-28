import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'route_crypto.dart';

/// A small seam for testing; production values live in Keychain/Keystore.
abstract interface class RouteSecretVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterRouteSecretVault implements RouteSecretVault {
  FlutterRouteSecretVault({FlutterSecureStorage? storage})
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

  @override
  Future<void> delete(String key) =>
      _storage.delete(key: key, iOptions: _iosOptions);
}

final class RouteDeviceKeyStore {
  RouteDeviceKeyStore({required this._vault, required this._crypto});

  final RouteSecretVault _vault;
  final RouteCrypto _crypto;

  Future<RouteDeviceKey> loadOrCreate({required String userId}) async {
    final existing = await loadExisting(userId: userId);
    if (existing != null) return existing;
    final device = await _crypto.generateDeviceKey(deviceId: const Uuid().v4());
    await _vault.write(
      _storageKey(userId),
      jsonEncode({
        'version': 1,
        'device_id': device.deviceId,
        'public_key': device.publicKeyBase64,
        'private_key': await device.exportPrivateKeyBase64(),
      }),
    );
    return device;
  }

  /// Reading an old card must never silently rotate a lost device key.
  Future<RouteDeviceKey?> loadExisting({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
    final saved = await _vault.read(_storageKey(userId));
    if (saved != null) {
      final decoded = jsonDecode(saved);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['device_id'] is! String ||
          decoded['public_key'] is! String ||
          decoded['private_key'] is! String) {
        throw const FormatException('Invalid local route key format');
      }
      return RouteDeviceKey.restore(
        deviceId: decoded['device_id'] as String,
        publicKeyBase64: decoded['public_key'] as String,
        privateKeyBase64: decoded['private_key'] as String,
      );
    }
    return null;
  }

  Future<void> deleteForUser({required String userId}) async {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId');
    }
    await _vault.delete(_storageKey(userId));
  }

  String _storageKey(String userId) =>
      'squadly.route.v1.${base64Url.encode(utf8.encode(userId))}';
}
