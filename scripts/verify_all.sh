#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v flutter >/dev/null 2>&1 || ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
  printf 'Required tools: Flutter, Node.js, npm/npx, and Docker.\n' >&2
  exit 2
fi

flutter pub get
flutter analyze
flutter test --no-test-assets
flutter test --no-test-assets --dart-define=USE_DEMO_BACKEND=false \
  test/app/real_mode_router_test.dart \
  test/features/auth/presentation/auth_recovery_state_test.dart

node --experimental-strip-types --test supabase/functions/push-deliveries/*.test.mjs
npx --yes deno check \
  supabase/functions/push-deliveries/index.ts \
  supabase/functions/push-deliveries/apns.ts \
  supabase/functions/push-deliveries/mipush.ts
bash supabase/tests/run_contracts.sh

printf '\nAll local automated checks passed. This does not replace staging or device acceptance.\n'
