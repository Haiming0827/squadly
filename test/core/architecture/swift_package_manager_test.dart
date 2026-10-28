import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app and integration host use Swift Package Manager without CocoaPods',
    () {
      final appPubspec = File('pubspec.yaml').readAsStringSync();
      final integrationPubspec = File('integration_test/pubspec.yaml')
          .readAsStringSync();

      expect(appPubspec, contains('enable-swift-package-manager: true'));
      expect(
        integrationPubspec,
        contains('enable-swift-package-manager: true'),
      );
      expect(File('ios/Podfile').existsSync(), isFalse);
      expect(File('ios/Podfile.lock').existsSync(), isFalse);
      expect(File('integration_test/ios/Podfile').existsSync(), isFalse);
      expect(File('integration_test/ios/Podfile.lock').existsSync(), isFalse);

      for (final configPath in [
        'ios/Flutter/Debug.xcconfig',
        'ios/Flutter/Release.xcconfig',
        'integration_test/ios/Flutter/Debug.xcconfig',
        'integration_test/ios/Flutter/Release.xcconfig',
      ]) {
        expect(File(configPath).readAsStringSync(), isNot(contains('Pods/')));
      }

      for (final workspacePath in [
        'ios/Runner.xcworkspace/contents.xcworkspacedata',
        'integration_test/ios/Runner.xcworkspace/contents.xcworkspacedata',
      ]) {
        expect(
          File(workspacePath).readAsStringSync(),
          isNot(contains('Pods/Pods.xcodeproj')),
        );
      }

      expect(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        contains('FlutterGeneratedPluginSwiftPackage'),
      );
      expect(
        File('integration_test/ios/Runner.xcodeproj/project.pbxproj')
            .readAsStringSync(),
        contains('FlutterGeneratedPluginSwiftPackage'),
      );
    },
  );
}
