import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/secure_route/data/route_crypto.dart';

void main() {
  const route = [
    RouteCoordinate(latitude: 31.230416, longitude: 121.473701),
    RouteCoordinate(latitude: 31.231002, longitude: 121.475012),
  ];

  test(
    'two approved devices decrypt the same card without cloud plaintext',
    () async {
      final crypto = RouteCrypto();
      final alice = await crypto.generateDeviceKey(deviceId: 'alice-phone');
      final bob = await crypto.generateDeviceKey(deviceId: 'bob-phone');
      final bundle = await crypto.encryptForMembers(
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        route: route,
        recipients: [
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
        ],
      );

      final cloudJson = jsonEncode(bundle.toJson());
      expect(cloudJson, isNot(contains('31.230416')));
      expect(cloudJson, isNot(contains('121.473701')));
      expect(bundle.envelopes, hasLength(2));

      final restored = EncryptedRouteBundle.fromJson(
        jsonDecode(cloudJson) as Map<String, dynamic>,
      );
      expect(
        await crypto.decryptForMe(
          bundle: restored,
          squadId: 'squad-1',
          cardId: 'card-1',
          templateVersion: 1,
          userId: 'alice',
          key: alice,
        ),
        route,
      );
      expect(
        await crypto.decryptForMe(
          bundle: restored,
          squadId: 'squad-1',
          cardId: 'card-1',
          templateVersion: 1,
          userId: 'bob',
          key: bob,
        ),
        route,
      );
    },
  );

  test('card and squad are authenticated associated data', () async {
    final crypto = RouteCrypto();
    final alice = await crypto.generateDeviceKey(deviceId: 'alice-phone');
    final bundle = await crypto.encryptForMembers(
      squadId: 'squad-1',
      cardId: 'card-1',
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

    Future<List<RouteCoordinate>> wrongCard() => crypto.decryptForMe(
      bundle: bundle,
      squadId: 'squad-1',
      cardId: 'card-2',
      templateVersion: 1,
      userId: 'alice',
      key: alice,
    );
    Future<List<RouteCoordinate>> wrongSquad() => crypto.decryptForMe(
      bundle: bundle,
      squadId: 'squad-2',
      cardId: 'card-1',
      templateVersion: 1,
      userId: 'alice',
      key: alice,
    );
    expect(wrongCard, throwsA(isA<RouteDecryptionException>()));
    expect(wrongSquad, throwsA(isA<RouteDecryptionException>()));
  });

  test('wrong device and tampered ciphertext cannot decrypt', () async {
    final crypto = RouteCrypto();
    final alice = await crypto.generateDeviceKey(deviceId: 'alice-phone');
    final impostor = await crypto.generateDeviceKey(deviceId: 'alice-phone');
    final bundle = await crypto.encryptForMembers(
      squadId: 'squad-1',
      cardId: 'card-1',
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

    expect(
      () => crypto.decryptForMe(
        bundle: bundle,
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        userId: 'alice',
        key: impostor,
      ),
      throwsA(isA<RouteDecryptionException>()),
    );

    final tamperedJson = bundle.toJson();
    final routeJson = tamperedJson['route']! as Map<String, Object>;
    routeJson['ciphertext'] = base64Encode(List<int>.filled(32, 0));
    final tampered = EncryptedRouteBundle.fromJson(tamperedJson);
    expect(
      () => crypto.decryptForMe(
        bundle: tampered,
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        userId: 'alice',
        key: alice,
      ),
      throwsA(isA<RouteDecryptionException>()),
    );
  });

  test('missing recipients and invalid coordinates fail closed', () async {
    final crypto = RouteCrypto();
    final alice = await crypto.generateDeviceKey(deviceId: 'alice-phone');
    expect(
      () => crypto.encryptForMembers(
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        route: route,
        recipients: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => crypto.encryptForMembers(
        squadId: 'squad-1',
        cardId: 'card-1',
        templateVersion: 1,
        route: const [RouteCoordinate(latitude: 91, longitude: 121)],
        recipients: [
          RouteRecipient(
            userId: 'alice',
            deviceId: alice.deviceId,
            publicKeyBase64: alice.publicKeyBase64,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
