import 'dart:typed_data';

enum ShareOutcome { selectedTarget, dismissed, unavailable }

/// The save/share adapter receives only rendered local PNG bytes. Selecting a
/// target is not proof that WeChat (or any destination) received the picture.
abstract interface class DeviceImageShare {
  Future<void> saveImage(Uint8List pngBytes);

  Future<ShareOutcome> shareImage(Uint8List pngBytes);
}
