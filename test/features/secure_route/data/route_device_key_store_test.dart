import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';
import 'package:squadly/features/secure_route/data/route_device_key_store.dart';

final class MemoryRouteSecretVault implements RouteSecretVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  test(
    'reading a missing historical key does not create a replacement',
    () async {
      final vault = MemoryRouteSecretVault();
      final store = RouteDeviceKeyStore(vault: vault, crypto: RouteCrypto());
      expect(await store.loadExisting(userId: 'alice'), isNull);
      expect(vault.values, isEmpty);
    },
  );

  test(
    'device key remains stable across app restarts and is user-scoped',
    () async {
      final vault = MemoryRouteSecretVault();
      final firstStore = RouteDeviceKeyStore(
        vault: vault,
        crypto: RouteCrypto(),
      );
      final first = await firstStore.loadOrCreate(userId: 'alice');
      final secondStore = RouteDeviceKeyStore(
        vault: vault,
        crypto: RouteCrypto(),
      );
      final restored = await secondStore.loadOrCreate(userId: 'alice');
      final bob = await secondStore.loadOrCreate(userId: 'bob');

      expect(restored.deviceId, first.deviceId);
      expect(restored.publicKeyBase64, first.publicKeyBase64);
      expect(
        await restored.exportPrivateKeyBase64(),
        await first.exportPrivateKeyBase64(),
      );
      expect(bob.publicKeyBase64, isNot(first.publicKeyBase64));
      expect(vault.values, hasLength(2));
    },
  );

  test('corrupt key fails closed instead of silently rotating', () async {
    final vault = MemoryRouteSecretVault();
    final store = RouteDeviceKeyStore(vault: vault, crypto: RouteCrypto());
    await store.loadOrCreate(userId: 'alice');
    final key = vault.values.keys.single;
    vault.values[key] = jsonEncode({
      'device_id': 'bad',
      'public_key': 'bad',
      'private_key': 'bad',
    });

    final nextStore = RouteDeviceKeyStore(vault: vault, crypto: RouteCrypto());
    expect(
      () => nextStore.loadOrCreate(userId: 'alice'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'a substituted public key cannot be paired with stored private key',
    () async {
      final vault = MemoryRouteSecretVault();
      final store = RouteDeviceKeyStore(vault: vault, crypto: RouteCrypto());
      await store.loadOrCreate(userId: 'alice');
      final impostor = await RouteCrypto().generateDeviceKey(deviceId: 'other');
      final key = vault.values.keys.single;
      final saved = jsonDecode(vault.values[key]!) as Map<String, dynamic>;
      saved['public_key'] = impostor.publicKeyBase64;
      vault.values[key] = jsonEncode(saved);

      expect(
        () => RouteDeviceKeyStore(
          vault: vault,
          crypto: RouteCrypto(),
        ).loadOrCreate(userId: 'alice'),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
