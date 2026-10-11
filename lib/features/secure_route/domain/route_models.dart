import 'dart:collection';

final class RouteCoordinate {
  const RouteCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  @override
  bool operator ==(Object other) =>
      other is RouteCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// The public key must be checked against the user's trusted device list.
final class RouteRecipient {
  const RouteRecipient({
    required this.userId,
    required this.deviceId,
    required this.publicKeyBase64,
  });

  final String userId;
  final String deviceId;
  final String publicKeyBase64;
}

/// Ciphertext only. Never place coordinates or private keys in this model.
final class EncryptedRouteBundle {
  EncryptedRouteBundle({
    required this.route,
    required List<RouteKeyEnvelope> envelopes,
  }) : envelopes = UnmodifiableListView(envelopes);

  static const version = 1;
  static const algorithm = 'X25519-HKDF-SHA256-AES-256-GCM';

  final RouteCiphertext route;
  final List<RouteKeyEnvelope> envelopes;

  Map<String, Object> toJson() => {
    'version': version,
    'algorithm': algorithm,
    'route': route.toJson(),
    'envelopes': envelopes.map((envelope) => envelope.toJson()).toList(),
  };

  factory EncryptedRouteBundle.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version || json['algorithm'] != algorithm) {
      throw const FormatException('Unsupported route encryption format');
    }
    final route = json['route'];
    final envelopes = json['envelopes'];
    if (route is! Map || envelopes is! List) {
      throw const FormatException('Malformed encrypted route');
    }
    return EncryptedRouteBundle(
      route: RouteCiphertext.fromJson(Map<String, dynamic>.from(route)),
      envelopes: envelopes.map((value) {
        if (value is! Map) {
          throw const FormatException('Malformed route key envelope');
        }
        return RouteKeyEnvelope.fromJson(Map<String, dynamic>.from(value));
      }).toList(),
    );
  }
}

final class RouteCiphertext {
  const RouteCiphertext({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  final String nonce;
  final String ciphertext;
  final String mac;

  Map<String, Object> toJson() => {
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };

  factory RouteCiphertext.fromJson(Map<String, dynamic> json) =>
      RouteCiphertext(
        nonce: _requiredString(json, 'nonce'),
        ciphertext: _requiredString(json, 'ciphertext'),
        mac: _requiredString(json, 'mac'),
      );
}

final class RouteKeyEnvelope {
  const RouteKeyEnvelope({
    required this.recipientUserId,
    required this.recipientDeviceId,
    required this.ephemeralPublicKey,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  final String recipientUserId;
  final String recipientDeviceId;
  final String ephemeralPublicKey;
  final String salt;
  final String nonce;
  final String ciphertext;
  final String mac;

  Map<String, Object> toJson() => {
    'recipient_user_id': recipientUserId,
    'recipient_device_id': recipientDeviceId,
    'ephemeral_public_key': ephemeralPublicKey,
    'salt': salt,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };

  factory RouteKeyEnvelope.fromJson(Map<String, dynamic> json) =>
      RouteKeyEnvelope(
        recipientUserId: _requiredString(json, 'recipient_user_id'),
        recipientDeviceId: _requiredString(json, 'recipient_device_id'),
        ephemeralPublicKey: _requiredString(json, 'ephemeral_public_key'),
        salt: _requiredString(json, 'salt'),
        nonce: _requiredString(json, 'nonce'),
        ciphertext: _requiredString(json, 'ciphertext'),
        mac: _requiredString(json, 'mac'),
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid encrypted route field: $key');
  }
  return value;
}
