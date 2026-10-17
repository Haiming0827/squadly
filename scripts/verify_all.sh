#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
  printf 'Required tools: Flutter, Node.js, and Docker.\n' >&2
  exit 2
fi

flutter pub get
flutter analyze
flutter test --no-test-assets
flutter test --no-test-assets --dart-define=USE_DEMO_BACKEND=false \
  test/app/real_mode_router_test.dart \
  test/features/auth/presentation/auth_recovery_state_test.dart

node --test cloudbase/functions/push-deliveries/*.test.js cloudbase/functions/push-deliveries-cron/*.test.js
bash scripts/check_cloudbase_migrations.sh

printf '\nAll local automated checks passed. This does not replace staging or device acceptance.\n'
