#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-$HOME/.local/share/jdks/jdk-17.0.19+10/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

echo "==> Flutter dependencies"
flutter pub get

echo "==> Code generation"
dart run build_runner build --delete-conflicting-outputs

echo "==> Formatting check"
dart format --set-exit-if-changed lib/ test/ integration_test/

echo "==> Static analysis"
flutter analyze

echo "==> Unit and widget tests"
flutter test

if [[ "${RUN_INTEGRATION_TESTS:-0}" == "1" ]]; then
  echo "==> Integration tests"
  flutter test integration_test
fi

if [[ "${BUILD_ANDROID_DEBUG:-0}" == "1" ]]; then
  echo "==> Android debug build"
  flutter build apk --debug
fi

