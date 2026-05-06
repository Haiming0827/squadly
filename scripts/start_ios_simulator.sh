#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS Simulator is only available on macOS."
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode or Xcode Command Line Tools first."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH."
  exit 1
fi

REQUESTED_DEVICE_NAME="${1:-${IOS_SIMULATOR_NAME:-}}"

if ! DEVICE_LIST="$(xcrun simctl list devices available 2>/dev/null)"; then
  echo "Failed to list iOS simulators. Check Xcode setup and license status."
  echo "You may need to run: sudo xcodebuild -license accept"
  exit 1
fi

if [[ -n "$REQUESTED_DEVICE_NAME" ]]; then
  DEVICE_LINE="$(
    printf '%s\n' "$DEVICE_LIST" |
      awk -v name="$REQUESTED_DEVICE_NAME" '
        {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          if (index(line, name " (") == 1 && line ~ /\((Booted|Shutdown)\)/) {
            print $0
            exit
          }
        }
      '
  )"
else
  DEVICE_LINE="$(
    printf '%s\n' "$DEVICE_LIST" |
      awk '/^[[:space:]]+iPhone / && /\(Booted\)/ { print; exit }'
  )"
  if [[ -z "$DEVICE_LINE" ]]; then
    DEVICE_LINE="$(
      printf '%s\n' "$DEVICE_LIST" |
        awk '/^[[:space:]]+iPhone / && /\((Booted|Shutdown)\)/ { print; exit }'
    )"
  fi
fi

if [[ -z "$DEVICE_LINE" ]]; then
  if [[ -n "$REQUESTED_DEVICE_NAME" ]]; then
    echo "iOS simulator '$REQUESTED_DEVICE_NAME' not found. Available devices:"
  else
    echo "No available iPhone simulator found. Available devices:"
  fi
  printf '%s\n' "$DEVICE_LIST"
  exit 1
fi

DEVICE_ID="$(
  printf '%s\n' "$DEVICE_LINE" |
    grep -Eo '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}' |
    head -n 1
)"
DEVICE_STATUS="$(
  printf '%s\n' "$DEVICE_LINE" |
    grep -Eo '\((Booted|Shutdown)\)' |
    tr -d '()' |
    tail -n 1
)"
DEVICE_NAME="$(
  printf '%s\n' "$DEVICE_LINE" |
    sed -E 's/^[[:space:]]*//; s/[[:space:]]+\([0-9A-Fa-f-]{36}\)[[:space:]]+\((Booted|Shutdown)\).*$//'
)"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Could not parse simulator UDID from:"
  echo "$DEVICE_LINE"
  exit 1
fi

open -a Simulator

if [[ "$DEVICE_STATUS" == "Booted" ]]; then
  echo "iOS Simulator '$DEVICE_NAME' is already booted."
else
  echo "Booting iOS Simulator '$DEVICE_NAME'..."
  xcrun simctl boot "$DEVICE_ID"
fi

xcrun simctl bootstatus "$DEVICE_ID" -b

echo
echo "Flutter devices:"
flutter devices
echo
echo "Run Squadly with:"
echo "flutter run -d $DEVICE_ID"
