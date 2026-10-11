import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/features/auth/domain/chinese_phone.dart';

void main() {
  test('a mainland mobile number is sent to Auth in E.164 form', () {
    expect(ChinesePhone.toE164('13800138000'), '+8613800138000');
    expect(ChinesePhone.toE164('+86 13800138000'), '+8613800138000');
  });

  test('invalid or non-mainland numbers cannot request a code', () {
    expect(() => ChinesePhone.toE164('1234'), throwsFormatException);
    expect(() => ChinesePhone.toE164('+12025550100'), throwsFormatException);
  });
}
