-- Run after registration_contract.sql in an isolated test database.
-- Contract seam: API-role privileges before row-level checks.
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.create_squad(text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.publish_card_message(uuid,text,jsonb,text,integer,uuid,uuid,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.store_encrypted_route(uuid,uuid,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.timeline_entry_json(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'API role can execute an unauthorized or internal function';
  END IF;
  IF has_table_privilege('authenticated', 'public.squad_members', 'INSERT')
     OR has_table_privilege('authenticated', 'public.squads', 'INSERT')
     OR has_table_privilege('authenticated', 'public.squad_messages', 'INSERT')
     OR has_table_privilege('authenticated', 'public.card_snapshots', 'INSERT')
     OR has_table_privilege('authenticated', 'public.card_route_ciphertexts', 'INSERT')
     OR has_table_privilege('authenticated', 'public.health_snapshots', 'SELECT')
     OR has_table_privilege('anon', 'public.profiles', 'SELECT') THEN
    RAISE EXCEPTION 'API role can mutate controlled rows or read private data';
  END IF;
END;
$$;

-- Both invitation entry points must redeem one record through one transaction.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-4000-8000-000000000004', 'd@example.invalid', '{"nickname":"丁"}'),
  ('00000000-0000-4000-8000-000000000005', 'e@example.invalid', '{"nickname":"戊"}');

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT (public.create_squad('双入口小队', NULL) ->> 'id') AS link_squad_id \gset
SELECT public.issue_invitation(:'link_squad_id'::uuid, 2) AS issued_invitation \gset
SELECT (:'issued_invitation'::jsonb ->> 'code') AS same_code \gset
SELECT (:'issued_invitation'::jsonb ->> 'link_token') AS same_link \gset
SELECT set_config('test.link_squad_id', :'link_squad_id', false) \gset
SELECT set_config('test.same_code', :'same_code', false) \gset

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000004';
SELECT public.redeem_invitation(:'same_code') AS code_redeem \gset
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000005';
SELECT public.redeem_invitation(:'same_link') AS link_redeem \gset

DO $$
BEGIN
  IF (SELECT count(*) FROM public.squad_members
      WHERE squad_id = current_setting('test.link_squad_id')::uuid) <> 3 THEN
    RAISE EXCEPTION 'code and link did not join the same squad';
  END IF;
  IF (public.redeem_invitation(current_setting('test.same_code')) ->> 'error')
     IS DISTINCT FROM 'invalid_invitation' THEN
    RAISE EXCEPTION 'exhausted invitation was accepted';
  END IF;
  IF (public.issue_invitation(current_setting('test.link_squad_id')::uuid) ->> 'error')
     IS DISTINCT FROM 'not_captain' THEN
    RAISE EXCEPTION 'non-captain issued an invitation';
  END IF;
END;
$$;

RESET ROLE;

SELECT id AS run_squad_id FROM public.squads WHERE name = '跑步小队' \gset
SELECT id AS route_squad_id FROM public.squads WHERE name = '轨迹加密小队' \gset
SELECT id AS first_text_id FROM public.squad_messages
  WHERE body = '明早跑步？' AND squad_id = :'run_squad_id'::uuid \gset
SELECT id AS teammate_text_id FROM public.squad_messages
  WHERE body = '到！' AND squad_id = :'run_squad_id'::uuid \gset

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT set_config('test.run_squad_id', :'run_squad_id', false) \gset
SELECT set_config('test.route_squad_id', :'route_squad_id', false) \gset
SELECT set_config('test.first_text_id', :'first_text_id', false) \gset
SELECT set_config('test.teammate_text_id', :'teammate_text_id', false) \gset

DO $$
DECLARE v_result jsonb; v_snapshot jsonb;
BEGIN
  v_result := public.publish_card_message(
    current_setting('test.run_squad_id')::uuid, 'activity',
    '{"activity_type":"run","date":"2026-10-08","distance_m":1000,"duration_s":360,"pace_s_per_km":360,"route":[[31,121]]}'::jsonb,
    'run-classic', 1, '10000000-0000-4000-8000-000000000010'::uuid);
  IF v_result ->> 'error' IS DISTINCT FROM 'invalid_snapshot' THEN
    RAISE EXCEPTION 'plaintext route passed card snapshot whitelist';
  END IF;
  v_result := public.publish_card_message(
    current_setting('test.run_squad_id')::uuid, 'activity',
    '{"activity_type":"run","date":"2026-10-08","distance_m":1000,"duration_s":360,"pace_s_per_km":360,"weight_kg":70}'::jsonb,
    'run-classic', 1, '10000000-0000-4000-8000-000000000011'::uuid);
  IF v_result ->> 'error' IS DISTINCT FROM 'sensitive_confirmation_required' THEN
    RAISE EXCEPTION 'sensitive field published without confirmation';
  END IF;
  v_snapshot := '{"activity_type":"run","date":"2026-10-08","distance_m":1000,"duration_s":360,"pace_s_per_km":360,"weight_kg":70,"confirmed_sensitive_fields":["weight_kg"]}'::jsonb;
  v_result := public.publish_card_message(
    current_setting('test.run_squad_id')::uuid, 'activity', v_snapshot,
    'run-classic', 1, '10000000-0000-4000-8000-000000000012'::uuid);
  IF v_result -> 'card_snapshot' -> 'snapshot' IS DISTINCT FROM v_snapshot THEN
    RAISE EXCEPTION 'confirmed selected field not reproduced';
  END IF;
  v_result := public.publish_card_message(
    current_setting('test.run_squad_id')::uuid, 'conversation',
    jsonb_build_object('selected_message_ids',
      jsonb_build_array(current_setting('test.teammate_text_id'))),
    'chat-classic', 1, '10000000-0000-4000-8000-000000000013'::uuid);
  IF v_result ->> 'error' IS DISTINCT FROM 'invalid_source_message' THEN
    RAISE EXCEPTION 'other member message used without consent';
  END IF;
  v_result := public.publish_card_message(
    current_setting('test.run_squad_id')::uuid, 'conversation',
    jsonb_build_object('selected_message_ids',
      jsonb_build_array(current_setting('test.first_text_id'))),
    'chat-classic', 1, '10000000-0000-4000-8000-000000000014'::uuid);
  IF v_result ->> 'kind' IS DISTINCT FROM 'card' THEN
    RAISE EXCEPTION 'own selected chat text could not become a card';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
DO $$
BEGIN
  IF (SELECT count(*) FROM public.card_route_ciphertexts
      WHERE squad_id = current_setting('test.route_squad_id')::uuid) <> 1
     OR (SELECT count(*) FROM public.card_route_envelopes
      WHERE squad_id = current_setting('test.route_squad_id')::uuid) <> 1
     OR EXISTS (SELECT 1 FROM public.card_route_envelopes
      WHERE recipient_user_id = '00000000-0000-4000-8000-000000000001') THEN
    RAISE EXCEPTION 'teammate cannot read own route envelope or can read another';
  END IF;
  IF EXISTS (SELECT 1 FROM public.private_assets
      WHERE user_id = '00000000-0000-4000-8000-000000000001') THEN
    RAISE EXCEPTION 'teammate can read private asset';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.card_route_ciphertexts
      WHERE squad_id = current_setting('test.route_squad_id')::uuid)
     OR EXISTS (SELECT 1 FROM public.card_route_envelopes
      WHERE squad_id = current_setting('test.route_squad_id')::uuid)
     OR EXISTS (SELECT 1 FROM public.list_route_recipients(
      current_setting('test.route_squad_id')::uuid))
     OR EXISTS (SELECT 1 FROM public.page_squad_timeline(
      current_setting('test.run_squad_id')::uuid)) THEN
    RAISE EXCEPTION 'stranger can read route or timeline';
  END IF;
  IF (public.send_text_message(
      current_setting('test.run_squad_id')::uuid, '越权',
      '30000000-0000-4000-8000-000000000099'::uuid) ->> 'error')
     IS DISTINCT FROM 'not_member' THEN
    RAISE EXCEPTION 'stranger can write same-squad message';
  END IF;
END;
$$;
RESET ROLE;
