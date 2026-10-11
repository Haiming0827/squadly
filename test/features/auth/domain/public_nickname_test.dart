import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/auth/domain/public_nickname.dart';

void main() {
  test('accepts trimmed public nickname at the 60-character boundary', () {
    expect(normalizePublicNickname('  阿青  '), '阿青');
    final sixtyCharacters = List.filled(60, '跑').join();
    expect(normalizePublicNickname(sixtyCharacters), sixtyCharacters);
  });

  test('rejects blank, overlong, and control-character nicknames', () {
    expect(normalizePublicNickname('   '), isNull);
    expect(normalizePublicNickname(List.filled(61, '跑').join()), isNull);
    expect(normalizePublicNickname('阿\n青'), isNull);
    expect(normalizePublicNickname('阿\u0000青'), isNull);
  });
}
