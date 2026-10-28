#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

apk_path="${1:-build/app/outputs/flutter-apk/app-release.apk}"
if [[ ! -f "$apk_path" ]]; then
  printf 'Release APK not found: %s\n' "$apk_path" >&2
  exit 2
fi

registrant="android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"
if [[ ! -f "$registrant" ]] || grep -Fq 'integration_test' "$registrant"; then
  printf 'Production plugin registrant must not include the integration test plugin.\n' >&2
  exit 1
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
  printf 'Set ANDROID_SDK_ROOT or ANDROID_HOME to an Android SDK.\n' >&2
  exit 2
fi

build_tools="$(find "$sdk_root/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
if [[ -z "$build_tools" || ! -x "$build_tools/aapt" || ! -x "$build_tools/apksigner" ]]; then
  printf 'Android build-tools must include aapt and apksigner.\n' >&2
  exit 2
fi

if [[ -z "${JAVA_HOME:-}" && -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

badging="$("$build_tools/aapt" dump badging "$apk_path")"
permissions="$("$build_tools/aapt" dump permissions "$apk_path")"
manifest="$("$build_tools/aapt" dump xmltree "$apk_path" AndroidManifest.xml)"

grep -Fq "package: name='com.squadly.squadly'" <<< "$badging" || {
  printf 'Unexpected Android application ID in release APK.\n' >&2
  exit 1
}
grep -Fq "uses-permission: name='android.permission.INTERNET'" <<< "$permissions" || {
  printf 'Release APK is missing INTERNET permission.\n' >&2
  exit 1
}
grep -Fq "uses-permission: name='android.permission.POST_NOTIFICATIONS'" <<< "$permissions" || {
  printf 'Release APK is missing POST_NOTIFICATIONS permission.\n' >&2
  exit 1
}
grep -Fq "uses-permission: name='android.permission.health.READ_EXERCISE'" <<< "$permissions" || {
  printf 'Release APK is missing the declared Health Connect exercise read permission.\n' >&2
  exit 1
}
grep -Fq "uses-permission: name='android.permission.health.READ_DISTANCE'" <<< "$permissions" || {
  printf 'Release APK is missing the declared Health Connect distance read permission.\n' >&2
  exit 1
}
if grep -Eq "uses-permission: name='android.permission.health.READ_(STEPS|TOTAL_CALORIES_BURNED)'" <<< "$permissions"; then
  printf 'Release APK requests Health Connect data outside workout import needs.\n' >&2
  exit 1
fi
grep -Eq 'A: android:usesCleartextTraffic[^=]*=.*0x0' <<< "$manifest" || {
  printf 'Release APK must explicitly disable cleartext traffic.\n' >&2
  exit 1
}

signature_log="$(mktemp)"
trap 'rm -f "$signature_log"' EXIT
if "$build_tools/apksigner" verify --verbose "$apk_path" >"$signature_log" 2>&1; then
  printf 'Release contract APK must remain unsigned when signing secrets are absent.\n' >&2
  exit 1
fi
if ! grep -Fq 'DOES NOT VERIFY' "$signature_log"; then
  cat "$signature_log" >&2
  printf 'Could not establish the expected unsigned APK state.\n' >&2
  exit 1
fi

printf 'Release APK package, least-privilege health permissions, TLS policy, plugin isolation, and unsigned state passed.\n'
