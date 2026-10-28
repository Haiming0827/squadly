#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Widget native tests run in the macOS iOS CI job."
  exit 0
fi
swift test \
  --package-path "$repo_root/packages/squadly_widget_bridge/ios/squadly_widget_bridge" \
  --scratch-path "${TMPDIR:-/tmp}/squadly-widget-bridge-tests"
