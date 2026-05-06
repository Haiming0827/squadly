/// 输入校验工具
class Validators {
  Validators._();

  /// 中国手机号校验
  static bool isValidChinesePhone(String phone) {
    final regex = RegExp(r'^1[3-9]\d{9}$');
    return regex.hasMatch(phone);
  }

  /// 邮箱校验
  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  /// 小队名称校验（1-20 字符）
  static bool isValidSquadName(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty && trimmed.length <= 20;
  }

  /// 密码校验（至少 8 位，包含字母和数字）
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    return hasLetter && hasDigit;
  }
}
