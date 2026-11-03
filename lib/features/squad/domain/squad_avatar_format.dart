import 'dart:convert';
import 'dart:typed_data';

const squadAvatarPrefix = 'data:image/png;base64,';
const squadAvatarMaxBytes = 48 * 1024;

Uint8List? decodeSquadAvatar(String? value) {
  if (value == null ||
      !value.startsWith(squadAvatarPrefix) ||
      value.length > squadAvatarPrefix.length + 65536) {
    return null;
  }
  try {
    final bytes = base64Decode(value.substring(squadAvatarPrefix.length));
    if (bytes.length < 33 || bytes.length > squadAvatarMaxBytes) return null;
    const header = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
    ];
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header[i]) return null;
    }
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(16) != 96 || data.getUint32(20) != 96) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}
