#!/usr/bin/env bash
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-$HOME/.local/share/jdks/jdk-17.0.19+10/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Cold boot with explicit DNS to avoid stale emulator DNS forwarding.
# This restarts only the selected AVD and preserves installed apps/user data.
android_sdk_dir="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
avd_name="${1:-Squadly_Android_16}"
dns_servers="${ANDROID_EMULATOR_DNS_SERVERS:-223.5.5.5,119.29.29.29}"
adb_bin="$android_sdk_dir/platform-tools/adb"
emulator_bin="$android_sdk_dir/emulator/emulator"

if [[ "$avd_name" == --help ]]; then
  printf 'Usage: bash scripts/start_android_emulator.sh [avd-name]\n'
  printf 'Optional: ANDROID_EMULATOR_DNS_SERVERS=ip1,ip2\n'
  exit 0
fi
if [[ $# -gt 1 ]]; then
  printf 'Usage: bash scripts/start_android_emulator.sh [avd-name]\n' >&2
  exit 2
fi
if [[ ! -x "$adb_bin" || ! -x "$emulator_bin" ]]; then
  printf 'Android SDK tools not found at %s; set ANDROID_SDK_ROOT.\n' "$android_sdk_dir" >&2
  exit 1
fi

avd_exists=false
while IFS= read -r available_avd; do
  if [[ "$available_avd" == "$avd_name" ]]; then avd_exists=true; fi
done < <("$emulator_bin" -list-avds)
if [[ "$avd_exists" != true ]]; then
  printf 'AVD not found: %s\n' "$avd_name" >&2
  "$emulator_bin" -list-avds
  exit 1
fi

while read -r emulator_device connection_state _; do
  [[ "$emulator_device" == emulator-* && "$connection_state" == device ]] || continue
  running_avd="$("$adb_bin" -s "$emulator_device" emu avd name | tr -d '\r' | head -n 1)"
  [[ "$running_avd" == "$avd_name" ]] || continue
  printf 'Restarting %s; installed apps and user data are preserved.\n' "$avd_name"
  "$adb_bin" -s "$emulator_device" emu kill
  for ((attempt=0; attempt<15; attempt++)); do
    if ! "$adb_bin" -s "$emulator_device" get-state >/dev/null 2>&1; then break; fi
    sleep 1
  done
done < <("$adb_bin" devices)

printf 'Starting %s with DNS %s. Keep this terminal open.\n' "$avd_name" "$dns_servers"
exec "$emulator_bin" -avd "$avd_name" -netdelay none -netspeed full \
  -dns-server "$dns_servers" -no-snapshot-load
