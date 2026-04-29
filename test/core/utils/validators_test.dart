import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('isValidChinesePhone', () {
      test('valid phone numbers', () {
        expect(Validators.isValidChinesePhone('13800138000'), isTrue);
        expect(Validators.isValidChinesePhone('15912345678'), isTrue);
        expect(Validators.isValidChinesePhone('18600001111'), isTrue);
      });

      test('invalid phone numbers', () {
        expect(Validators.isValidChinesePhone('12345678901'), isFalse);
        expect(Validators.isValidChinesePhone('1380013800'), isFalse); // 10 digits
        expect(Validators.isValidChinesePhone('138001380001'), isFalse); // 12 digits
        expect(Validators.isValidChinesePhone('abcdefghijk'), isFalse);
        expect(Validators.isValidChinesePhone(''), isFalse);
      });
    });

    group('isValidEmail', () {
      test('valid emails', () {
        expect(Validators.isValidEmail('test@example.com'), isTrue);
        expect(Validators.isValidEmail('user.name@domain.co'), isTrue);
      });

      test('invalid emails', () {
        expect(Validators.isValidEmail('notanemail'), isFalse);
        expect(Validators.isValidEmail('@domain.com'), isFalse);
        expect(Validators.isValidEmail(''), isFalse);
      });
    });

    group('isValidSquadName', () {
      test('valid names', () {
        expect(Validators.isValidSquadName('我的小队'), isTrue);
        expect(Validators.isValidSquadName('Squad Alpha'), isTrue);
      });

      test('invalid names', () {
        expect(Validators.isValidSquadName(''), isFalse);
        expect(Validators.isValidSquadName('   '), isFalse);
        expect(Validators.isValidSquadName('a' * 21), isFalse);
      });
    });

    group('isValidPassword', () {
      test('valid passwords', () {
        expect(Validators.isValidPassword('password1'), isTrue);
        expect(Validators.isValidPassword('Abc12345'), isTrue);
      });

      test('invalid passwords', () {
        expect(Validators.isValidPassword('short1'), isFalse); // too short
        expect(Validators.isValidPassword('nonnumber'), isFalse); // no digit
        expect(Validators.isValidPassword('12345678'), isFalse); // no letter
      });
    });
  });
}
