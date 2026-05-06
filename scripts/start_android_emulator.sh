#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-$HOME/.local/share/jdks/jdk-17.0.19+10/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

AVD_NAME="${1:-squadly_api35}"

if ! emulator -list-avds | grep -qx "$AVD_NAME"; then
  echo "AVD '$AVD_NAME' not found. Available AVDs:"
  emulator -list-avds
  exit 1
fi

emulator -avd "$AVD_NAME" -netdelay none -netspeed full

