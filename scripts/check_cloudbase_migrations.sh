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
-- Local fixture of the documented CloudBase PG Storage metadata contract.
-- This does not emulate the Storage service or prove cloud byte permissions.
CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
  id text PRIMARY KEY, name text NOT NULL, public boolean DEFAULT false,
  file_size_limit bigint, allowed_mime_types text[], owner_id text
);
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text REFERENCES storage.buckets(id),
  name text, owner_id text, metadata jsonb, user_metadata jsonb,
  path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/')) STORED,
  UNIQUE(bucket_id,name)
);
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON storage.buckets, storage.objects TO anon, authenticated, service_role;
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
  if [[ "$migration_name" == 20261018000200_social_snapshots.sql ]]; then
    echo "Creating legacy plan fixtures before unified plan migration"
    docker exec --interactive "$container_name" psql \
      --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users (id)
VALUES ('00000000-0000-4000-8000-00000000000d');
INSERT INTO public.squads (id, name, created_by, status)
VALUES ('00000000-0000-4000-8000-000000000002', 'Legacy plan check', '00000000-0000-4000-8000-00000000000d', 'active');
INSERT INTO public.workout_plans (
  id, squad_id, name, plan_type, description, created_by, created_at
)
VALUES (
  '00000000-0000-4000-8000-000000000041',
  '00000000-0000-4000-8000-000000000002',
  'Legacy fitness plan', 'custom', 'fitness details',
  '00000000-0000-4000-8000-00000000000d', '2026-10-01T08:00:00Z'
);
INSERT INTO public.travel_plans (
  id, squad_id, title, destination, start_date, end_date,
  budget, notes, created_by, created_at
)
VALUES (
  '00000000-0000-4000-8000-000000000042',
  '00000000-0000-4000-8000-000000000002',
  'Legacy travel plan', '杭州', '2026-11-01', '2026-11-03',
  1200, 'travel details', '00000000-0000-4000-8000-00000000000d',
  '2026-10-02T08:00:00Z'
);
SQL
  fi
done

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.travel_plans (
  id, squad_id, title, destination, start_date, end_date, budget,
  created_by
)
VALUES (
  '00000000-0000-4000-8000-000000000043',
  '00000000-0000-4000-8000-000000000002',
  'New travel plan', '苏州', '2026-12-01', '2026-12-02', 800,
  '00000000-0000-4000-8000-00000000000d'
);
UPDATE public.travel_plans SET budget = 900
WHERE id = '00000000-0000-4000-8000-000000000043';
DO $$
BEGIN
  IF (SELECT (legacy_data ->> 'budget')::numeric
      FROM public.squad_plans
      WHERE legacy_source = 'travel_plan'
        AND legacy_id = '00000000-0000-4000-8000-000000000043') <> 900 THEN
    RAISE EXCEPTION 'New legacy travel plans are not synchronized into unified plans';
  END IF;
END
$$;
SQL

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 <<'SQL'
INSERT INTO auth.users (id) VALUES
  ('00000000-0000-4000-8000-00000000000a'),
  ('00000000-0000-4000-8000-00000000000b'),
  ('00000000-0000-4000-8000-00000000000c');

INSERT INTO public.squads (id, name, created_by, status)
VALUES ('00000000-0000-4000-8000-000000000001', 'Finance check', '00000000-0000-4000-8000-00000000000a', 'active');
INSERT INTO public.squad_members (squad_id, user_id, role)
VALUES
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'captain'),
  ('00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000b', 'member');
DO $$
BEGIN
  IF (SELECT count(*) FROM public.squad_plans
      WHERE legacy_source = 'workout_plan'
        AND legacy_id = '00000000-0000-4000-8000-000000000041'
        AND legacy_data ->> 'name' = 'Legacy fitness plan'
        AND squad_id = '00000000-0000-4000-8000-000000000002') <> 1 THEN
    RAISE EXCEPTION 'Legacy workout plan was not mapped with its source and Squad';
  END IF;
  IF (SELECT count(*) FROM public.squad_plans
      WHERE legacy_source = 'travel_plan'
        AND legacy_id = '00000000-0000-4000-8000-000000000042'
        AND legacy_data ->> 'destination' = '杭州'
        AND (legacy_data ->> 'budget')::numeric = 1200
        AND start_date = '2026-11-01'
        AND end_date = '2026-11-03') <> 1 THEN
    RAISE EXCEPTION 'Legacy travel plan details were not preserved';
  END IF;
END
$$;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}';
INSERT INTO public.travel_plans (
  id, squad_id, title, destination, start_date, end_date, budget, created_by
)
VALUES (
  '00000000-0000-4000-8000-000000000044',
  '00000000-0000-4000-8000-000000000001',
  'Member-created travel plan', '苏州', '2026-12-05', '2026-12-06', 600,
  '00000000-0000-4000-8000-00000000000a'
);
UPDATE public.travel_plans SET budget = 650
WHERE id = '00000000-0000-4000-8000-000000000044';
DO $$
BEGIN
  IF (SELECT (legacy_data ->> 'budget')::numeric
      FROM public.squad_plans
      WHERE legacy_source = 'travel_plan'
        AND legacy_id = '00000000-0000-4000-8000-000000000044') <> 650 THEN
    RAISE EXCEPTION 'Authenticated legacy plan writes did not sync through the trigger';
  END IF;
END
$$;
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
INSERT INTO public.external_data_items (
  id, user_id, source, source_label, category, title, summary,
  metric_value, metric_unit, range_start, range_end, trend
)
VALUES (
  '00000000-0000-4000-8000-000000000021',
  '00000000-0000-4000-8000-00000000000a',
  'manual', '手动记录', 'fitness', '晨跑', '周末慢跑记录',
  '5.0', '公里', now() - interval '1 day', now(), '[4.5,5.0]'::jsonb
);
SELECT public.publish_social_post(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000021',
  '周末慢跑', '跑完很舒服', 'story', 'squad', '{}',
  '00000000-0000-4000-8000-000000000031'
);
SELECT public.publish_social_post(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000021',
  '指定成员分享', '只给队友看', 'story', 'selected',
  ARRAY['00000000-0000-4000-8000-00000000000b'],
  '00000000-0000-4000-8000-000000000032'
);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.social_posts
    WHERE id = '00000000-0000-4000-8000-000000000031'
      AND metric_value = '5.0' AND metric_unit = '公里'
      AND source_label = '手动记录'
  ) THEN
    RAISE EXCEPTION 'Social post did not capture the confirmed metric snapshot';
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'social_posts'
      AND column_name IN ('source_item_id', 'data_item_id')
  ) THEN
    RAISE EXCEPTION 'Published post must not retain a pointer to private source data';
  END IF;
  BEGIN
    PERFORM public.publish_social_post(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000021',
      'Invalid recipient', '', 'story', 'selected',
      ARRAY['00000000-0000-4000-8000-00000000000c'],
      '00000000-0000-4000-8000-000000000033'
    );
    RAISE EXCEPTION 'Share publication accepted a non-member recipient';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
INSERT INTO public.squad_plans (
  id, squad_id, title, category, visibility, created_by
)
VALUES
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'Shared plan', 'custom', 'squad', '00000000-0000-4000-8000-00000000000a'),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'Private plan', 'custom', 'private', '00000000-0000-4000-8000-00000000000a');
INSERT INTO public.squad_plan_tasks (
  plan_id, squad_id, title, created_by
)
VALUES
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'Shared task', '00000000-0000-4000-8000-00000000000a'),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'Private task', '00000000-0000-4000-8000-00000000000a');
SELECT public.send_squad_plan_message(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000011',
  'Shared plan discussion',
  '00000000-0000-4000-8000-000000000051'
);
SELECT public.send_squad_plan_message(
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000012',
  'Private plan discussion',
  '00000000-0000-4000-8000-000000000052'
);
SELECT public.send_text_message(
  '00000000-0000-4000-8000-000000000001',
  'Squad general conversation',
  '00000000-0000-4000-8000-000000000053'
);
UPDATE public.squad_plans SET description = 'owner edit'
WHERE id = '00000000-0000-4000-8000-000000000012';
DO $$
BEGIN
  IF (SELECT current_amount FROM public.public_funds
      WHERE squad_id = '00000000-0000-4000-8000-000000000001') <> 25.5 THEN
    RAISE EXCEPTION 'Fund balance trigger failed to apply ledger transaction';
  END IF;
  IF (SELECT description FROM public.squad_plans
      WHERE id = '00000000-0000-4000-8000-000000000012') <> 'owner edit' THEN
    RAISE EXCEPTION 'Private plan owner cannot update own plan';
  END IF;
  BEGIN
    UPDATE public.squad_plans SET created_by = '00000000-0000-4000-8000-00000000000b'
      WHERE id = '00000000-0000-4000-8000-000000000012';
    RAISE EXCEPTION 'Plan owner identity must be immutable';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}';
DO $$
DECLARE
  affected_rows integer;
BEGIN
  IF (SELECT count(*) FROM public.squad_plans WHERE id = '00000000-0000-4000-8000-000000000011') <> 1 THEN
    RAISE EXCEPTION 'Squad plan visibility failed: member B cannot read squad plan';
  END IF;
  IF (SELECT count(*) FROM public.squad_plans WHERE id = '00000000-0000-4000-8000-000000000012') <> 0 THEN
    RAISE EXCEPTION 'Private plan isolation failed: member B can read member A plan';
  END IF;
  IF (SELECT count(*) FROM public.squad_plan_tasks WHERE title = 'Shared task') <> 1 THEN
    RAISE EXCEPTION 'Squad task visibility failed: member B cannot read squad task';
  END IF;
  IF (SELECT count(*) FROM public.squad_plan_tasks WHERE title = 'Private task') <> 0 THEN
    RAISE EXCEPTION 'Private task isolation failed: member B can read private task';
  END IF;
  IF (SELECT count(*) FROM public.squad_messages
      WHERE body = 'Shared plan discussion') <> 1 THEN
    RAISE EXCEPTION 'Squad member cannot read the shared plan discussion';
  END IF;
  IF (SELECT count(*) FROM public.squad_messages
      WHERE body = 'Private plan discussion') <> 0 THEN
    RAISE EXCEPTION 'Private plan discussion leaked to another Squad member';
  END IF;
  IF (SELECT count(*) FROM public.squad_messages
      WHERE body = 'Squad general conversation') <> 1 THEN
    RAISE EXCEPTION 'General Squad conversation was hidden from its member';
  END IF;
  IF (SELECT count(*) FROM public.page_squad_plan_discussion(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000011')) <> 1 THEN
    RAISE EXCEPTION 'Plan discussion RPC did not return the correct thread';
  END IF;
  IF (SELECT count(*) FROM public.page_squad_plan_discussion(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000012')) <> 0 THEN
    RAISE EXCEPTION 'Plan discussion RPC leaked a private thread';
  END IF;
  IF public.send_squad_plan_message(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000012',
      'forged private discussion',
      '00000000-0000-4000-8000-000000000054'
    ) ->> 'error' IS DISTINCT FROM 'not_allowed' THEN
    RAISE EXCEPTION 'Squad member wrote into another member private discussion';
  END IF;
  IF (SELECT count(*) FROM public.external_data_items) <> 0 THEN
    RAISE EXCEPTION 'External data isolation failed: member B read member A material';
  END IF;
  IF (SELECT count(*) FROM public.social_posts WHERE id = '00000000-0000-4000-8000-000000000031') <> 1 THEN
    RAISE EXCEPTION 'Squad social post was not visible to a Squad member';
  END IF;
  IF (SELECT count(*) FROM public.social_posts WHERE id = '00000000-0000-4000-8000-000000000032') <> 1 THEN
    RAISE EXCEPTION 'Selected social post was not visible to its recipient';
  END IF;
  IF public.toggle_social_post_reaction(
    '00000000-0000-4000-8000-000000000031',
    '00000000-0000-4000-8000-000000000001'
  ) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Visible Squad member could not react to a social post';
  END IF;
  IF public.toggle_social_post_reaction(
    '00000000-0000-4000-8000-000000000031',
    '00000000-0000-4000-8000-000000000001'
  ) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Social post reaction toggle was not idempotent';
  END IF;
  BEGIN
    PERFORM public.publish_social_post(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000021',
      'Forged share', '', 'story', 'squad', '{}', NULL
    );
    RAISE EXCEPTION 'Member B published member A private material';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  UPDATE public.squad_plans SET title = 'Member B changed private plan'
    WHERE id = '00000000-0000-4000-8000-000000000012';
  GET DIAGNOSTICS affected_rows = ROW_COUNT;
  IF affected_rows <> 0 THEN
    RAISE EXCEPTION 'Private plan isolation failed: member B updated member A plan';
  END IF;
  BEGIN
    INSERT INTO public.squad_plan_tasks (
      plan_id, squad_id, title, created_by
    ) VALUES (
      '00000000-0000-4000-8000-000000000012',
      '00000000-0000-4000-8000-000000000001',
      'Forged private task',
      '00000000-0000-4000-8000-00000000000b'
    );
    RAISE EXCEPTION 'Private plan isolation failed: member B inserted task in member A plan';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claims = '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}';
DO $$
BEGIN
  IF (SELECT count(*) FROM public.squad_plans) <> 0 THEN
    RAISE EXCEPTION 'Squad plan isolation failed: non-member read a plan';
  END IF;
  IF (SELECT count(*) FROM public.squad_plan_tasks) <> 0 THEN
    RAISE EXCEPTION 'Squad task isolation failed: non-member read a task';
  END IF;
  IF (SELECT count(*) FROM public.social_posts) <> 0 THEN
    RAISE EXCEPTION 'Social isolation failed: non-member read a post';
  END IF;
  BEGIN
    INSERT INTO public.squad_plans (
      squad_id, title, category, visibility, created_by
    ) VALUES (
      '00000000-0000-4000-8000-000000000001',
      'Non-member plan',
      'custom',
      'squad',
      '00000000-0000-4000-8000-00000000000c'
    );
    RAISE EXCEPTION 'Squad plan isolation failed: non-member created a plan';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    PERFORM public.toggle_social_post_reaction(
      '00000000-0000-4000-8000-000000000031',
      '00000000-0000-4000-8000-000000000001'
    );
    RAISE EXCEPTION 'Social isolation failed: non-member reacted to a post';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
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

SET ROLE anon;
DO $$
BEGIN
  BEGIN
    PERFORM count(*) FROM public.squad_plans;
    RAISE EXCEPTION 'Plan access failed: anonymous role queried plan data';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    PERFORM count(*) FROM public.social_posts;
    RAISE EXCEPTION 'Social access failed: anonymous role queried posts';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    PERFORM public.publish_social_post(
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000021',
      'Anonymous share', '', 'story', 'squad', '{}', NULL
    );
    RAISE EXCEPTION 'Social access failed: anonymous role published data';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END
$$;
RESET ROLE;
SQL

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
  < "$repo_root/scripts/sql/conversation_read_cursors_test.sql"

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
  < "$repo_root/scripts/sql/public_fund_permissions_test.sql"

echo "CloudBase SQL objects, legacy-plan mapping, discussion/read cursor RLS, plan/social visibility, one-time share snapshots, reactions, fund balance, PrivateAsset RLS, and health snapshot isolation checks passed."

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
  < "$repo_root/scripts/sql/check_private_photo_media.sql"
printf '\nPrivate photo metadata, publication, nonce, restrictive storage RLS and cleanup checks passed (local fixture only).\n'

docker exec --interactive "$container_name" psql \
  --username postgres --dbname postgres --set ON_ERROR_STOP=1 \
  < "$repo_root/scripts/sql/check_push_photo_hints.sql"
printf '\nServer-only V2 photo push hints, per-device leases, retry, channel isolation and departed-member cancellation passed (local fixture only).\n'

python3 "$repo_root/scripts/sql/check_photo_head_concurrency.py" "$container_name"
