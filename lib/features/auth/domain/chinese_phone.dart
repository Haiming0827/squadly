/// Mainland mobile numbers accepted by the first phone-registration flow.
abstract final class ChinesePhone {
  static String toE164(String input) {
    final compact = input.replaceAll(RegExp(r'[\s-]'), '');
    final local = compact.startsWith('+86') ? compact.substring(3) : compact;
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(local)) {
      throw const FormatException('请输入有效的中国大陆手机号');
    }
    return '+86$local';
  }
}
