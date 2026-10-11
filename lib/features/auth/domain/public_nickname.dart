/// Public to squad peers. Contact details remain in Supabase Auth only.
String? normalizePublicNickname(String input) {
  final nickname = input.trim();
  if (nickname.isEmpty ||
      nickname.runes.length > 60 ||
      nickname.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
    return null;
  }
  return nickname;
}
