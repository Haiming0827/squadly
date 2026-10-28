import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS integration host declares HealthKit read purpose and entitlement',
    () {
      final infoPlist = File('integration_test/ios/Runner/Info.plist')
          .readAsStringSync();
      final project = File(
        'integration_test/ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final entitlements = File(
        'integration_test/ios/Runner/Runner.entitlements',
      ).readAsStringSync();

      expect(infoPlist, contains('NSHealthShareUsageDescription'));
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
      );
      expect(entitlements, contains('com.apple.developer.healthkit'));
      expect(entitlements, contains('<true/>'));
    },
  );
}
