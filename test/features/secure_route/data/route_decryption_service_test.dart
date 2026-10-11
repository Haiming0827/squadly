import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';
import 'package:squadly/features/secure_route/data/route_decryption_service.dart';
import 'package:squadly/features/secure_route/data/route_device_key_store.dart';
import 'package:squadly/features/secure_route/domain/route_bundle_repository.dart';
import 'package:squadly/features/secure_route/domain/route_reader.dart';

final class _Vault implements RouteSecretVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _Repository implements RouteBundleRepository {
  _Repository(this.bundle);

  final EncryptedRouteBundle bundle;
  int calls = 0;

  @override
  Future<EncryptedRouteBundle> loadForDevice({
    required String squadId,
    required String cardId,
    required String userId,
    required String deviceId,
  }) async {
    calls++;
    if (squadId != 'squad-a' ||
        cardId != 'card-a' ||
        userId != 'alice' ||
        deviceId != bundle.envelopes.single.recipientDeviceId) {
      throw const RouteEnvelopeUnavailable();
    }
    return bundle;
  }
}

void main() {
  const route = [
    RouteCoordinate(latitude: 31.2, longitude: 121.5),
    RouteCoordinate(latitude: 31.3, longitude: 121.6),
  ];

  test('decrypts a selected card only with the existing device key', () async {
    final crypto = RouteCrypto();
    final vault = _Vault();
    final store = RouteDeviceKeyStore(vault: vault, crypto: crypto);
    final alice = await store.loadOrCreate(userId: 'alice');
    final bundle = await crypto.encryptForMembers(
      squadId: 'squad-a',
      cardId: 'card-a',
      templateVersion: 1,
      route: route,
      recipients: [
        RouteRecipient(
          userId: 'alice',
          deviceId: alice.deviceId,
          publicKeyBase64: alice.publicKeyBase64,
        ),
      ],
    );
    final repository = _Repository(bundle);
    final reader = RouteDecryptionService(
      keyStore: store,
      repository: repository,
      crypto: crypto,
    );
    expect(
      await reader.loadForMe(
        squadId: 'squad-a',
        cardId: 'card-a',
        templateVersion: 1,
        userId: 'alice',
      ),
      route,
    );
    expect(repository.calls, 1);
    await expectLater(
      reader.loadForMe(
        squadId: 'squad-a',
        cardId: 'card-a',
        templateVersion: 2,
        userId: 'alice',
      ),
      throwsA(isA<RouteDecryptionException>()),
    );
  });

  test('a missing old key does not fetch a bundle or rotate a key', () async {
    final crypto = RouteCrypto();
    final vault = _Vault();
    final repository = _Repository(
      EncryptedRouteBundle(
        route: const RouteCiphertext(nonce: 'n', ciphertext: 'c', mac: 'm'),
        envelopes: const [],
      ),
    );
    final reader = RouteDecryptionService(
      keyStore: RouteDeviceKeyStore(vault: vault, crypto: crypto),
      repository: repository,
      crypto: crypto,
    );
    await expectLater(
      reader.loadForMe(
        squadId: 'squad-a',
        cardId: 'card-a',
        templateVersion: 1,
        userId: 'alice',
      ),
      throwsA(isA<RouteKeyMissing>()),
    );
    expect(vault.values, isEmpty);
    expect(repository.calls, 0);
  });
}
