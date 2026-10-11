import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/push_registration.dart';

final class SecurePushDeviceIdStore implements PushDeviceIdStore {
  SecurePushDeviceIdStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'squadly.push.device.v1';
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> loadExisting() =>
      _storage.read(key: _key, iOptions: _iosOptions);

  @override
  Future<String> loadOrCreate() async {
    final existing = await loadExisting();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _key, value: id, iOptions: _iosOptions);
    return id;
  }
}
