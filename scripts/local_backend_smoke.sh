#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  printf 'Usage: %s <booted-ios-simulator-id>\n' "$0" >&2
  exit 2
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker is required for the local Supabase stack.\n' >&2
  exit 2
fi
if ! command -v flutter >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
  printf 'Flutter and OpenSSL are required.\n' >&2
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# The local Supabase keys stay in shell memory and are never printed or saved.
npx --yes supabase@latest start >/dev/null 2>&1 || {
  printf 'Could not start the local Supabase stack.\n' >&2
  exit 1
}
local_status="$(npx --yes supabase@latest status -o env)"
api_url="$(printf '%s\n' "$local_status" | sed -n 's/^API_URL="\([^"]*\)"$/\1/p')"
anon_key="$(printf '%s\n' "$local_status" | sed -n 's/^ANON_KEY="\([^"]*\)"$/\1/p')"
if [[ -z "$api_url" || -z "$anon_key" ]]; then
  printf 'Could not read the local public Supabase endpoint.\n' >&2
  exit 1
fi

smoke_id="$(openssl rand -hex 8)"
smoke_email="squadly-smoke-${smoke_id}@example.test"
smoke_password="Squadly$(openssl rand -hex 16)"
second_email="squadly-smoke-${smoke_id}-second@example.test"
second_password="Squadly$(openssl rand -hex 16)"

flutter test integration_test/app_smoke_test.dart \
  -d "$1" \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=ENABLE_LOCAL_HTTP_BACKEND=true \
  --dart-define="SUPABASE_URL=$api_url" \
  --dart-define="SUPABASE_ANON_KEY=$anon_key" \
  --dart-define="SMOKE_TEST_EMAIL=$smoke_email" \
  --dart-define="SMOKE_TEST_PASSWORD=$smoke_password" \
  --dart-define="SMOKE_TEST_SECOND_EMAIL=$second_email" \
  --dart-define="SMOKE_TEST_SECOND_PASSWORD=$second_password"
