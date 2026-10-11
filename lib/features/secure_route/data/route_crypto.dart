import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../domain/route_models.dart';

export '../domain/route_models.dart';

final class RouteDecryptionException implements Exception {
  const RouteDecryptionException();

  @override
  String toString() => 'RouteDecryptionException';
}

/// A device-private X25519 key. Only [exportPrivateKeyBase64] may persist it,
/// and only through the device's protected key store.
final class RouteDeviceKey {
  RouteDeviceKey._({
    required this.deviceId,
    required this.publicKeyBase64,
    required SimpleKeyPair keyPair,
  }) : _keyPair = keyPair;

  final String deviceId;
  final String publicKeyBase64;
  final SimpleKeyPair _keyPair;

  Future<String> exportPrivateKeyBase64() async =>
      base64Encode(await _keyPair.extractPrivateKeyBytes());

  static Future<RouteDeviceKey> restore({
    required String deviceId,
    required String publicKeyBase64,
    required String privateKeyBase64,
  }) async {
    final publicBytes = base64Decode(publicKeyBase64);
    final privateBytes = base64Decode(privateKeyBase64);
    if (deviceId.isEmpty ||
        publicBytes.length != 32 ||
        privateBytes.length != 32) {
      throw const FormatException('Invalid local route device key');
    }
    final derived = await X25519().newKeyPairFromSeed(privateBytes);
    try {
      final derivedPublic = await derived.extractPublicKey();
      if (derivedPublic.bytes.length != publicBytes.length ||
          List.generate(
            publicBytes.length,
            (index) => index,
          ).any((index) => derivedPublic.bytes[index] != publicBytes[index])) {
        throw const FormatException('Local route key pair does not match');
      }
    } finally {
      derived.destroy();
    }
    final keyPair = SimpleKeyPairData(
      privateBytes,
      publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    return RouteDeviceKey._(
      deviceId: deviceId,
      publicKeyBase64: publicKeyBase64,
      keyPair: keyPair,
    );
  }
}

/// E2EE route codec. The server receives only [EncryptedRouteBundle.toJson].
/// Authentication of recipients' public keys is a separate device-trust step.
final class RouteCrypto {
  RouteCrypto()
    : _x25519 = X25519(),
      _aes = AesGcm.with256bits(),
      _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final X25519 _x25519;
  final AesGcm _aes;
  final Hkdf _hkdf;

  Future<RouteDeviceKey> generateDeviceKey({required String deviceId}) async {
    if (deviceId.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return RouteDeviceKey._(
      deviceId: deviceId,
      publicKeyBase64: base64Encode(publicKey.bytes),
      keyPair: keyPair,
    );
  }

  Future<EncryptedRouteBundle> encryptForMembers({
    required String squadId,
    required String cardId,
    required int templateVersion,
    required List<RouteCoordinate> route,
    required List<RouteRecipient> recipients,
  }) async {
    if (squadId.isEmpty || cardId.isEmpty || templateVersion < 1) {
      throw ArgumentError(
        'A valid squad, card and template version are required',
      );
    }
    if (route.length < 2 ||
        route.length > 20000 ||
        route.any((p) => !p.isValid)) {
      throw ArgumentError.value(route, 'route', 'Invalid precise route');
    }
    if (recipients.isEmpty || recipients.length > 27) {
      throw ArgumentError.value(recipients, 'recipients');
    }
    final deviceIds = <String>{};
    for (final recipient in recipients) {
      if (recipient.userId.isEmpty ||
          recipient.deviceId.isEmpty ||
          !deviceIds.add(recipient.deviceId) ||
          _decodePublicKey(recipient.publicKeyBase64).length != 32) {
        throw ArgumentError.value(recipients, 'recipients');
      }
    }

    final routeAad = _routeAad(squadId, cardId, templateVersion);
    final contentKey = await _aes.newSecretKey();
    final cleartext = utf8.encode(
      jsonEncode({
        'coordinates': route
            .map((point) => [point.latitude, point.longitude])
            .toList(),
      }),
    );
    final routeBox = await _aes.encrypt(
      cleartext,
      secretKey: contentKey,
      aad: routeAad,
    );
    final contentKeyBytes = await contentKey.extractBytes();
    final envelopes = <RouteKeyEnvelope>[];
    for (final recipient in recipients) {
      final ephemeral = await _x25519.newKeyPair();
      try {
        final ephemeralPublic = await ephemeral.extractPublicKey();
        final remotePublic = SimplePublicKey(
          _decodePublicKey(recipient.publicKeyBase64),
          type: KeyPairType.x25519,
        );
        final shared = await _x25519.sharedSecretKey(
          keyPair: ephemeral,
          remotePublicKey: remotePublic,
        );
        final salt = _secureBytes(16);
        final envelopeAad = _envelopeAad(
          routeAad,
          recipient.userId,
          recipient.deviceId,
        );
        final wrappingKey = await _hkdf.deriveKey(
          secretKey: shared,
          nonce: salt,
          info: envelopeAad,
        );
        final wrapped = await _aes.encrypt(
          contentKeyBytes,
          secretKey: wrappingKey,
          aad: envelopeAad,
        );
        envelopes.add(
          RouteKeyEnvelope(
            recipientUserId: recipient.userId,
            recipientDeviceId: recipient.deviceId,
            ephemeralPublicKey: base64Encode(ephemeralPublic.bytes),
            salt: base64Encode(salt),
            nonce: base64Encode(wrapped.nonce),
            ciphertext: base64Encode(wrapped.cipherText),
            mac: base64Encode(wrapped.mac.bytes),
          ),
        );
      } finally {
        ephemeral.destroy();
      }
    }
    return EncryptedRouteBundle(
      route: RouteCiphertext(
        nonce: base64Encode(routeBox.nonce),
        ciphertext: base64Encode(routeBox.cipherText),
        mac: base64Encode(routeBox.mac.bytes),
      ),
      envelopes: envelopes,
    );
  }

  Future<List<RouteCoordinate>> decryptForMe({
    required EncryptedRouteBundle bundle,
    required String squadId,
    required String cardId,
    required int templateVersion,
    required String userId,
    required RouteDeviceKey key,
  }) async {
    try {
      final candidates = bundle.envelopes.where(
        (envelope) =>
            envelope.recipientUserId == userId &&
            envelope.recipientDeviceId == key.deviceId,
      );
      if (candidates.length != 1) {
        throw const RouteDecryptionException();
      }
      final envelope = candidates.single;
      final routeAad = _routeAad(squadId, cardId, templateVersion);
      final envelopeAad = _envelopeAad(routeAad, userId, key.deviceId);
      final shared = await _x25519.sharedSecretKey(
        keyPair: key._keyPair,
        remotePublicKey: SimplePublicKey(
          _decodePublicKey(envelope.ephemeralPublicKey),
          type: KeyPairType.x25519,
        ),
      );
      final wrappingKey = await _hkdf.deriveKey(
        secretKey: shared,
        nonce: base64Decode(envelope.salt),
        info: envelopeAad,
      );
      final contentKeyBytes = await _aes.decrypt(
        _secretBox(envelope.nonce, envelope.ciphertext, envelope.mac),
        secretKey: wrappingKey,
        aad: envelopeAad,
      );
      final cleartext = await _aes.decrypt(
        _secretBox(
          bundle.route.nonce,
          bundle.route.ciphertext,
          bundle.route.mac,
        ),
        secretKey: SecretKey(contentKeyBytes),
        aad: routeAad,
      );
      final decoded = jsonDecode(utf8.decode(cleartext));
      if (decoded is! Map || decoded['coordinates'] is! List) {
        throw const FormatException('Invalid route plaintext');
      }
      final coordinates = (decoded['coordinates'] as List).map((point) {
        if (point is! List ||
            point.length != 2 ||
            point[0] is! num ||
            point[1] is! num) {
          throw const FormatException('Invalid route point');
        }
        return RouteCoordinate(
          latitude: (point[0] as num).toDouble(),
          longitude: (point[1] as num).toDouble(),
        );
      }).toList();
      if (coordinates.length < 2 ||
          coordinates.any((point) => !point.isValid)) {
        throw const FormatException('Invalid route coordinates');
      }
      return coordinates;
    } catch (_) {
      // Do not leak cryptographic failure details or coordinate content to logs.
      throw const RouteDecryptionException();
    }
  }

  List<int> _decodePublicKey(String encoded) {
    try {
      return base64Decode(encoded);
    } on FormatException {
      throw ArgumentError.value(encoded, 'publicKeyBase64');
    }
  }

  List<int> _routeAad(String squadId, String cardId, int templateVersion) =>
      utf8.encode(
        jsonEncode(['squadly-route-v1', squadId, cardId, templateVersion]),
      );

  List<int> _envelopeAad(List<int> routeAad, String userId, String deviceId) =>
      utf8.encode(
        jsonEncode([
          'squadly-route-key-v1',
          base64Encode(routeAad),
          userId,
          deviceId,
        ]),
      );

  SecretBox _secretBox(String nonce, String ciphertext, String mac) =>
      SecretBox(
        base64Decode(ciphertext),
        nonce: base64Decode(nonce),
        mac: Mac(base64Decode(mac)),
      );

  List<int> _secureBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
