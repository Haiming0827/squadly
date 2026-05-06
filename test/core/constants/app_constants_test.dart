import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('squad member limits are valid', () {
      expect(AppConstants.squadMinMembers, 2);
      expect(AppConstants.squadMaxMembers, 9);
      expect(
        AppConstants.squadMinMembers,
        lessThan(AppConstants.squadMaxMembers),
      );
    });

    test('roles are defined', () {
      expect(AppConstants.roleCaptain, 'captain');
      expect(AppConstants.roleMember, 'member');
    });
  });
}
