#!/usr/bin/env bash
# Open existing local acceptance apps without rebuilding or replacing their data.
set -euo pipefail

case "${1:-all}" in
  -h|--help)
    echo 'Usage: bash scripts/ios/open_acceptance_apps.sh [a|b|all]'
    echo 'Opens installed Squadly in Device Hub; preserves accounts and app data.'
    exit 0
    ;;
  a) acceptance_targets=(370493B7-843A-47ED-AE82-7CB75E21691E) ;;
  b) acceptance_targets=(DA33717A-0E70-4727-8623-A22CED1A5432) ;;
  all) acceptance_targets=(370493B7-843A-47ED-AE82-7CB75E21691E DA33717A-0E70-4727-8623-A22CED1A5432) ;;
  *) echo 'Choose a, b, or all.' >&2; exit 2 ;;
esac

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This helper requires macOS and Xcode.' >&2
  exit 1
fi

acceptance_hub=/Applications/Xcode.app/Contents/Applications/DeviceHub.app
if [[ -d "$acceptance_hub" ]]; then
  open -a "$acceptance_hub"
elif [[ -d /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app ]]; then
  open -a /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
else
  echo 'Open the simulator application from your installed Xcode.' >&2
  exit 1
fi

for acceptance_device in "${acceptance_targets[@]}"; do
  acceptance_state="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
target = sys.argv[1]
matches = [d for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"] == target]
if len(matches) != 1:
    raise SystemExit("Configured acceptance simulator is unavailable.")
print(matches[0]["state"])
' "$acceptance_device")"
  if [[ "$acceptance_state" == Shutdown ]]; then
    xcrun simctl boot "$acceptance_device"
  elif [[ "$acceptance_state" != Booted ]]; then
    echo 'Simulator is transitioning; wait and retry.' >&2
    exit 1
  fi
  xcrun simctl bootstatus "$acceptance_device" -b
  if ! xcrun simctl get_app_container "$acceptance_device" com.squadly.squadly app >/dev/null 2>&1; then
    echo 'Squadly is not installed in this simulator; see the operation manual build section.' >&2
    exit 1
  fi
  xcrun simctl launch "$acceptance_device" com.squadly.squadly
done

echo 'In Device Hub > Window, choose iPhone 17 Pro (A) or iPhone 17 (B).'
echo 'Use Squadly, not Squadly Integration Test. No data was reset.'
