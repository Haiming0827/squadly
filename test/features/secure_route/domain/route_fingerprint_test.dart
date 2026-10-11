import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/secure_route/domain/route_fingerprint.dart';

void main() {
  test(
    'public key fingerprints are stable, complete and distinguish keys',
    () async {
      final first = base64Encode(List<int>.filled(32, 1));
      final second = base64Encode(List<int>.filled(32, 2));
      final a = await RouteFingerprint.ofPublicKey(first);
      expect(a.replaceAll(' ', ''), hasLength(64));
      expect(await RouteFingerprint.ofPublicKey(first), a);
      expect(await RouteFingerprint.ofPublicKey(second), isNot(a));
      await expectLater(
        RouteFingerprint.ofPublicKey(base64Encode([1, 2])),
        throwsFormatException,
      );
    },
  );
}
