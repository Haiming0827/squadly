import 'dart:typed_data';

/// Checks header dimensions and rejects original metadata/trailing payloads.
/// Native Image I/O still performs the actual pixel decode and reconstruction.
bool isPreparedJpeg(Uint8List bytes, int width, int height) {
  if (bytes.length < 10 ||
      bytes[0] != 0xff ||
      bytes[1] != 0xd8 ||
      bytes[bytes.length - 2] != 0xff ||
      bytes.last != 0xd9) {
    return false;
  }
  var offset = 2;
  var hasFrame = false;
  while (offset + 3 < bytes.length) {
    if (bytes[offset++] != 0xff) return false;
    final marker = bytes[offset++];
    if (marker == 0xda) return hasFrame;
    if (marker == 0xd8 ||
        marker == 0xd9 ||
        marker == 0xfe ||
        marker == 0xe1 ||
        marker == 0xed ||
        (marker >= 0xe3 && marker <= 0xef)) {
      return false;
    }
    final length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length - 2) return false;
    if (marker == 0xc0 || marker == 0xc2) {
      if (length < 8) return false;
      final frameHeight = bytes[offset + 3] * 256 + bytes[offset + 4];
      final frameWidth = bytes[offset + 5] * 256 + bytes[offset + 6];
      if (frameWidth != width || frameHeight != height) return false;
      hasFrame = true;
    }
    offset += length;
  }
  return false;
}
