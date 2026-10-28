#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
  printf 'Required tools: Flutter, Node.js, and Docker.\n' >&2
  exit 2
fi

flutter pub get
dart format --set-exit-if-changed lib/ test/ integration_test/
flutter analyze
(
  cd integration_test
  flutter pub get
  flutter analyze
)
flutter test --no-test-assets
flutter test --no-test-assets --dart-define=USE_DEMO_BACKEND=false \
  test/app/real_mode_router_test.dart \
  test/features/auth/presentation/auth_async_state_test.dart \
  test/features/auth/presentation/auth_recovery_state_test.dart
bash scripts/test_health_connect_bridge.sh
bash scripts/test_ios_photo_bridge.sh
bash scripts/test_ios_widget_bridge.sh

node --test cloudbase/functions/push-deliveries/*.test.js cloudbase/functions/push-deliveries-cron/*.test.js scripts/verify_cloudbase_access.test.mjs
npm ci --prefix cloudbase/functions/photos --ignore-scripts --no-audit --no-fund
node --test cloudbase/functions/photos/*.test.js cloudbase/functions/photos-cleanup-cron/*.test.js
bash scripts/check_cloudbase_migrations.sh

printf '\nAll local automated checks passed. This does not replace staging or device acceptance.\n'
