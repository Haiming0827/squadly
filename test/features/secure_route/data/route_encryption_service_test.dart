import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';
import 'package:squadly/features/secure_route/data/route_device_key_store.dart';
import 'package:squadly/features/secure_route/data/route_encryption_service.dart';
import 'package:squadly/features/secure_route/domain/route_key_directory.dart';
import 'package:squadly/features/secure_route/domain/route_sharing.dart';

final class _MemoryVault implements RouteSecretVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _Directory implements RouteKeyDirectory {
  List<RouteRecipient> recipients = [];
  RouteRecipient? registered;

  @override
  Future<void> registerDevice(RouteRecipient device) async {
    registered = device;
    recipients = [
      device,
      ...recipients.where((entry) => entry.deviceId != device.deviceId),
    ];
  }

  @override
  Future<List<RouteRecipient>> listRecipients(String squadId) async =>
      recipients;
}

void main() {
  const route = [
    RouteCoordinate(latitude: 31.2304, longitude: 121.4737),
    RouteCoordinate(latitude: 31.2310, longitude: 121.4740),
  ];

  test(
    'requires per-card confirmation before any registration or upload',
    () async {
      final directory = _Directory();
      final service = RouteEncryptionService(
        keyStore: RouteDeviceKeyStore(
          vault: _MemoryVault(),
          crypto: RouteCrypto(),
        ),
        directory: directory,
        crypto: RouteCrypto(),
      );

      await expectLater(
        service.prepare(
          userId: 'alice',
          squadId: 'squad-1',
          cardId: 'card-1',
          templateVersion: 1,
          route: route,
          approvedPublicKeys: const {},
          explicitlyConfirmed: false,
        ),
        throwsA(isA<RouteShareNotConfirmedException>()),
      );
      expect(directory.registered, isNull);
    },
  );

  test('unknown or substituted teammate key blocks route sharing', () async {
    final crypto = RouteCrypto();
    final bob = await crypto.generateDeviceKey(deviceId: 'bob-phone');
    final directory = _Directory();
    final vault = _MemoryVault();
    final service = RouteEncryptionService(
      keyStore: RouteDeviceKeyStore(vault: vault, crypto: crypto),
      directory: directory,
      crypto: crypto,
    );
    // The service registers Alice first; the directory returns that key too.
    directory.recipients = [
      RouteRecipient(
        userId: 'bob',
        deviceId: bob.deviceId,
        publicKeyBase64: bob.publicKeyBase64,
      ),
    ];

    await expectLater(
      service.prepare(
        userId: 'alice',
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        route: route,
        approvedPublicKeys: const {},
        explicitlyConfirmed: true,
      ),
      throwsA(isA<UntrustedRouteDeviceException>()),
    );
    expect(directory.registered, isNotNull);
  });

  test('approved complete device set creates only encrypted bundle', () async {
    final crypto = RouteCrypto();
    final bob = await crypto.generateDeviceKey(deviceId: 'bob-phone');
    final directory = _Directory();
    final vault = _MemoryVault();
    final keyStore = RouteDeviceKeyStore(vault: vault, crypto: crypto);
    final alice = await keyStore.loadOrCreate(userId: 'alice');
    directory.recipients = [
      RouteRecipient(
        userId: 'alice',
        deviceId: alice.deviceId,
        publicKeyBase64: alice.publicKeyBase64,
      ),
      RouteRecipient(
        userId: 'bob',
        deviceId: bob.deviceId,
        publicKeyBase64: bob.publicKeyBase64,
      ),
    ];
    final service = RouteEncryptionService(
      keyStore: keyStore,
      directory: directory,
      crypto: crypto,
    );

    final bundle = await service.prepare(
      userId: 'alice',
      squadId: 'squad-1',
      cardId: 'card-1',
      templateVersion: 1,
      route: route,
      approvedPublicKeys: {'bob-phone': bob.publicKeyBase64},
      explicitlyConfirmed: true,
    );

    expect(bundle.envelopes, hasLength(2));
    expect(
      await crypto.decryptForMe(
        bundle: bundle,
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        userId: 'bob',
        key: bob,
      ),
      route,
    );
  });
}
