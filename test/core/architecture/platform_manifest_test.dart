import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android production manifest grants internet but denies cleartext', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    expect(manifest, contains('android:name="android.permission.INTERNET"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('Android Health Connect access is limited to workouts and distance', () {
    final manifest = File(
      'packages/health_connect_bridge/android/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.health.READ_EXERCISE'));
    expect(manifest, contains('android.permission.health.READ_DISTANCE'));
    expect(manifest, isNot(contains('android.permission.health.READ_STEPS')));
    expect(
      manifest,
      isNot(contains('android.permission.health.READ_TOTAL_CALORIES_BURNED')),
    );
    expect(
      manifest,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
    expect(
      File(
        'packages/health_connect_bridge/android/src/main/kotlin/com/squadly/health_connect_bridge/HealthConnectBridgePlugin.kt',
      ).readAsStringSync(),
      isNot(contains('StepsRecord')),
    );
  });

  test('app and local bridge stop applying Kotlin Gradle Plugin', () {
    final appGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final gradle = File('packages/health_connect_bridge/android/build.gradle')
        .readAsStringSync();
    final packageManifest = File('packages/health_connect_bridge/pubspec.yaml')
        .readAsStringSync();

    expect(appGradle, isNot(contains('id("kotlin-android")')));
    expect(appGradle, contains('kotlin {'));
    expect(
      settings,
      contains(
        'id("org.jetbrains.kotlin.android") version "2.3.20" apply false',
      ),
    );
    expect(gradle, contains("id 'com.android.library'"));
    expect(gradle, isNot(contains('org.jetbrains.kotlin.android')));
    expect(gradle, contains('kotlin {'));
    expect(gradle, contains('compilerOptions {'));
    expect(packageManifest, contains("flutter: '>=3.44.0'"));
    expect(
      File('android/gradle.properties').readAsStringSync(),
      contains('android.builtInKotlin=false'),
    );
  });

  test(
    'iOS allows health reads only with a scoped explanation and default ATS',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('<key>NSHealthShareUsageDescription</key>'));
      expect(plist, contains('仅在你主动选择时读取跑步、徒步记录'));
      expect(plist, contains('<key>NSHealthUpdateUsageDescription</key>'));
      expect(plist, contains('不会向 Apple 健康写入运动数据'));
      expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
    },
  );
}
