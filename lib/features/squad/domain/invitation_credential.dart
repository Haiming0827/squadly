/// Converts either invitation entry point into the single server credential.
/// The server, not this parser, decides whether a credential is valid.
abstract final class InvitationCredential {
  static String parse(String input) {
    final value = input.trim();
    if (value.isEmpty) throw const FormatException('请输入邀请码或邀请链接');

    if (!value.contains('://')) {
      if (RegExp(r'^[0-9a-fA-F]{10}$').hasMatch(value)) {
        return value.toUpperCase();
      }
      if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value)) {
        return value.toLowerCase();
      }
      throw const FormatException('邀请码格式无效');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'invite' ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(uri.pathSegments.last) ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw const FormatException('邀请链接格式无效');
    }
    return uri.pathSegments.last.toLowerCase();
  }

  static Uri linkFor({required String baseUrl, required String token}) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        base.pathSegments.where((segment) => segment.isNotEmpty).isNotEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw const FormatException('邀请链接配置无效');
    }
    return base.replace(pathSegments: ['invite', token]);
  }
}
