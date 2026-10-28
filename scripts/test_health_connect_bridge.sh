#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_java_home="${JAVA_HOME:-}"

if [[ -z "$android_java_home" ]]; then
  java_binary="$(flutter doctor -v | sed -n 's/.*Java binary at: //p' | head -n 1)"
  android_java_home="${java_binary%/bin/java}"
fi

if [[ ! -x "$android_java_home/bin/java" ]]; then
  printf 'Could not find the JDK selected by Flutter. Set JAVA_HOME to JDK 17 and retry.\n' >&2
  exit 2
fi

cd "$project_root/android"
env JAVA_HOME="$android_java_home" \
  PATH="$android_java_home/bin:$PATH" \
  ./gradlew :health_connect_bridge:testDebugUnitTest
