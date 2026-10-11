import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// A human-checkable digest of the complete X25519 public key. Display it on
/// both devices and compare out of band; the server cannot attest itself.
final class RouteFingerprint {
  const RouteFingerprint._();

  static Future<String> ofPublicKey(String publicKeyBase64) async {
    final bytes = base64Decode(publicKeyBase64);
    if (bytes.length != 32) {
      throw const FormatException('Invalid route public key');
    }
    final digest = await Sha256().hash(bytes);
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return RegExp(
      r'.{1,4}',
    ).allMatches(hex).map((match) => match.group(0)!).join(' ');
  }
}
