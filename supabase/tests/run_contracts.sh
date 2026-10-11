#!/usr/bin/env bash
set -euo pipefail

test_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_container="squadly-contract-$$"
test_image="${SUPABASE_TEST_POSTGRES_IMAGE:-public.ecr.aws/supabase/postgres:17.11.0.004}"

cleanup() {
  docker stop "$test_container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm -d --name "$test_container" \
  -v "$test_root:/repo:ro" \
  -e POSTGRES_PASSWORD=contract-test-only "$test_image" >/dev/null

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if docker exec "$test_container" pg_isready -U postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$test_container" pg_isready -U postgres >/dev/null

docker exec "$test_container" psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -q -f /repo/supabase/tests/parts/auth_fixture.inc >/dev/null

for relative_path in \
  supabase/migrations/001_core_tables.sql \
  supabase/migrations/002_feature_tables.sql \
  supabase/migrations/003_registration_foundation.sql \
  supabase/migrations/004_notification_outbox.sql \
  supabase/migrations/005_push_deliveries.sql \
  supabase/migrations/006_public_nickname_policy.sql \
  supabase/migrations/007_conversation_card_limit.sql; do
  docker exec "$test_container" psql -U postgres -d postgres \
    -v ON_ERROR_STOP=1 -q -f "/repo/$relative_path" >/dev/null
done

docker exec "$test_container" psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -q -c 'CREATE EXTENSION IF NOT EXISTS pgtap' >/dev/null
docker exec "$test_container" psql -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -q -f /repo/supabase/tests/contracts.sql >/dev/null

printf 'PostgreSQL registration contracts passed.\n'
