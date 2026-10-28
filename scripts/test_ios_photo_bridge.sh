#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo "Photo Image I/O tests require macOS; run them in the iOS CI job."
  exit 0
fi
swift test \
  --package-path "$repo_root/packages/squadly_photo_bridge/ios/squadly_photo_bridge" \
  --scratch-path "${TMPDIR:-/tmp}/squadly-photo-bridge-tests"
