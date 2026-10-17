#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
container_name="squadly-cloudbase-pg-check-$$"

cleanup() {
  docker rm --force "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach \
  --name "$container_name" \
  --env POSTGRES_PASSWORD=local-only \
  postgres:16-alpine >/dev/null

attempt=0
until docker exec "$container_name" pg_isready --username postgres >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if (( attempt >= 30 )); then
    echo "PostgreSQL did not become ready" >&2
    exit 1
  fi
  sleep 1
done

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY
);
CREATE FUNCTION auth.uid() RETURNS text
  LANGUAGE sql STABLE
  AS $$ SELECT current_setting('request.jwt.claims', true)::jsonb ->> 'sub' $$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
SQL

for migration in "$repo_root"/cloudbase/migrations/*.sql; do
  migration_name="$(basename "$migration")"
  if [[ ! "$migration_name" =~ ^[0-9]{14}_[a-z0-9_]+\.sql$ ]]; then
    printf 'CloudBase CLI migration filename must use a 14-digit UTC version and lowercase name: %s\n' "$migration_name" >&2
    exit 1
  fi
  echo "Applying $migration_name to disposable PostgreSQL"
  docker exec --interactive "$container_name" psql \
    --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
    < "$migration"
  if [[ "$migration_name" == 20261012000300_registration_foundation.sql ]]; then
    echo "Reapplying registration migration to verify retry safety after a failed attempt"
    docker exec --interactive "$container_name" psql \
      --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
      < "$migration"
  fi
done

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-8000-00000000000a'),
  ('00000000-0000-4000-8000-00000000000b');

INSERT INTO public.squads (id, name, created_by, status)
VALUES ('00000000-0000-4000-8000-000000000001', 'Finance check', '00000000-0000-4000-8000-00000000000a', 'active');
INSERT INTO public.squad_members (squad_id, user_id, role)
VALUES ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'captain');

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}';
INSERT INTO public.public_funds (squad_id, name, fund_type, created_by)
VALUES ('00000000-0000-4000-8000-000000000001', 'Travel', 'travel', '00000000-0000-4000-8000-00000000000a');
INSERT INTO public.fund_transactions (fund_id, user_id, amount)
SELECT id, '00000000-0000-4000-8000-00000000000a', 25.5 FROM public.public_funds
WHERE squad_id = '00000000-0000-4000-8000-000000000001';
INSERT INTO public.health_snapshots (
  user_id, squad_id, weight, calories_burned, recorded_date
)
VALUES (
  '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-000000000001', 70, 300, CURRENT_DATE
);
DO $$
BEGIN
  IF (SELECT current_amount FROM public.public_funds
      WHERE squad_id = '00000000-0000-4000-8000-000000000001') <> 25.5 THEN
    RAISE EXCEPTION 'Fund balance trigger failed to apply ledger transaction';
  END IF;
END
$$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}';
INSERT INTO public.private_assets (user_id, asset_type, name, amount)
VALUES ('00000000-0000-4000-8000-00000000000a', 'savings', 'A private asset', 100);
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}';
DO $$
BEGIN
  IF (SELECT count(*) FROM public.private_assets) <> 0 THEN
    RAISE EXCEPTION 'PrivateAsset isolation failed: user B can read user A data';
  END IF;
  IF (SELECT count(*) FROM public.health_snapshots) <> 0 THEN
    RAISE EXCEPTION 'Health snapshot isolation failed: user B can read user A data';
  END IF;
  BEGIN
    INSERT INTO public.health_snapshots (
      user_id, squad_id, weight, recorded_date
    ) VALUES (
      '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-000000000001', 55, CURRENT_DATE
    );
    RAISE EXCEPTION 'Health snapshot isolation failed: user B forged user A ownership';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    INSERT INTO public.private_assets (user_id, asset_type, name, amount)
    VALUES ('00000000-0000-4000-8000-00000000000a', 'savings', 'forged owner', 1);
    RAISE EXCEPTION 'PrivateAsset isolation failed: user B forged user A ownership';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
RESET ROLE;
SQL

echo "CloudBase SQL object, fund balance, PrivateAsset RLS, and health snapshot isolation checks passed."
