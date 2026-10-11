-- Run after auth_fixture.sql and migrations 001..latest with psql -v ON_ERROR_STOP=1.
-- A/B share a squad; C is an authenticated stranger.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('00000000-0000-4000-8000-000000000001', 'a@example.invalid', '{"nickname":"甲"}'),
  ('00000000-0000-4000-8000-000000000002', 'b@example.invalid', '{"nickname":"乙"}'),
  ('00000000-0000-4000-8000-000000000003', 'c@example.invalid', '{"nickname":"丙"}')
ON CONFLICT (id) DO NOTHING;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';

DO $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM public.profiles WHERE id = auth.uid();
  IF v_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'auth.users trigger did not provision profile';
  END IF;
END;
$$;

RESET ROLE;

-- Encrypted route recipients are device-specific and never expose a private key.
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT (public.create_squad('轨迹加密小队', NULL) ->> 'id') AS route_squad_id \gset
SELECT set_config('test.squad_id', :'route_squad_id', false) \gset
SELECT (public.issue_invitation(:'route_squad_id'::uuid) ->> 'code') AS route_code \gset
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT public.redeem_invitation(:'route_code') \gset
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT public.register_route_device_key(
  '40000000-0000-4000-8000-000000000001'::uuid,
  encode(convert_to(repeat('A', 32), 'UTF8'), 'base64'));
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT public.register_route_device_key(
  '40000000-0000-4000-8000-000000000002'::uuid,
  encode(convert_to(repeat('B', 32), 'UTF8'), 'base64'));
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';

DO $$
DECLARE
  v_bundle jsonb;
  v_result jsonb;
BEGIN
  IF (SELECT count(*) FROM public.list_route_recipients(
      current_setting('test.squad_id')::uuid)) <> 2 THEN
    RAISE EXCEPTION 'missing same-squad device recipients';
  END IF;
  v_bundle := jsonb_build_object(
    'version', 1,
    'algorithm', 'X25519-HKDF-SHA256-AES-256-GCM',
    'route', jsonb_build_object(
      'nonce', encode(convert_to(repeat('N', 12), 'UTF8'), 'base64'),
      'ciphertext', encode(convert_to('encrypted-route', 'UTF8'), 'base64'),
      'mac', encode(convert_to(repeat('M', 16), 'UTF8'), 'base64')),
    'envelopes', jsonb_build_array(
      jsonb_build_object(
        'recipient_user_id', '00000000-0000-4000-8000-000000000001',
        'recipient_device_id', '40000000-0000-4000-8000-000000000001',
        'ephemeral_public_key', encode(convert_to(repeat('E', 32), 'UTF8'), 'base64'),
        'salt', encode(convert_to(repeat('S', 16), 'UTF8'), 'base64'),
        'nonce', encode(convert_to(repeat('N', 12), 'UTF8'), 'base64'),
        'ciphertext', encode(convert_to(repeat('K', 32), 'UTF8'), 'base64'),
        'mac', encode(convert_to(repeat('M', 16), 'UTF8'), 'base64')),
      jsonb_build_object(
        'recipient_user_id', '00000000-0000-4000-8000-000000000002',
        'recipient_device_id', '40000000-0000-4000-8000-000000000002',
        'ephemeral_public_key', encode(convert_to(repeat('E', 32), 'UTF8'), 'base64'),
        'salt', encode(convert_to(repeat('S', 16), 'UTF8'), 'base64'),
        'nonce', encode(convert_to(repeat('N', 12), 'UTF8'), 'base64'),
        'ciphertext', encode(convert_to(repeat('K', 32), 'UTF8'), 'base64'),
        'mac', encode(convert_to(repeat('M', 16), 'UTF8'), 'base64'))));
  v_result := public.publish_card_message(
    current_setting('test.squad_id')::uuid, 'activity',
    '{"activity_type":"hike","date":"2026-10-08","distance_m":8000,"duration_s":3600,"pace_s_per_km":450}'::jsonb,
    'run-classic', 1, '10000000-0000-4000-8000-000000000003'::uuid,
    '30000000-0000-4000-8000-000000000002'::uuid, v_bundle);
  IF v_result ->> 'card_id' IS DISTINCT FROM '30000000-0000-4000-8000-000000000002' THEN
    RAISE EXCEPTION 'encrypted route card was not published atomically';
  END IF;
  IF (SELECT count(*) FROM public.card_route_envelopes
      WHERE card_id = '30000000-0000-4000-8000-000000000002') <> 1 THEN
    RAISE EXCEPTION 'author must only read own key envelope';
  END IF;
END;
$$;

RESET ROLE;

DO $$
BEGIN
  IF has_column_privilege('authenticated', 'public.profiles', 'email', 'SELECT')
     OR has_column_privilege('authenticated', 'public.profiles', 'phone', 'SELECT') THEN
    RAISE EXCEPTION 'contact columns are readable by API roles';
  END IF;
END;
$$;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT (public.create_squad('跑步小队', NULL) ->> 'id') AS squad_id \gset
SELECT set_config('test.squad_id', :'squad_id', false) \gset

DO $$
BEGIN
  IF (SELECT status FROM public.squads WHERE id = current_setting('test.squad_id')::uuid)
     IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'first captain did not create a pending squad';
  END IF;
  IF (SELECT count(*) FROM public.squad_members
      WHERE squad_id = current_setting('test.squad_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'pending squad must have exactly one captain';
  END IF;
END;
$$;

SELECT (public.issue_invitation(:'squad_id'::uuid) ->> 'code') AS invite_code \gset
SELECT (public.issue_invitation(:'squad_id'::uuid) ->> 'link_token') AS link_token \gset
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT public.redeem_invitation(:'invite_code') \gset

DO $$
BEGIN
  IF (SELECT status FROM public.squads WHERE id = current_setting('test.squad_id')::uuid)
     IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'second account did not activate squad';
  END IF;
  IF (SELECT count(*) FROM public.squad_members
      WHERE squad_id = current_setting('test.squad_id')::uuid) <> 2 THEN
    RAISE EXCEPTION 'invite code did not add exactly one member';
  END IF;
  IF (SELECT nickname FROM public.profiles
      WHERE id = '00000000-0000-4000-8000-000000000001') IS DISTINCT FROM '甲' THEN
    RAISE EXCEPTION 'member cannot see teammate nickname';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.squads WHERE id = current_setting('test.squad_id')::uuid)
     OR EXISTS (SELECT 1 FROM public.squad_members WHERE squad_id = current_setting('test.squad_id')::uuid)
     OR EXISTS (SELECT 1 FROM public.profiles
        WHERE id = '00000000-0000-4000-8000-000000000001') THEN
    RAISE EXCEPTION 'stranger can enumerate squad or member profile';
  END IF;
END;
$$;

RESET ROLE;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT (public.send_text_message(
  :'squad_id'::uuid, '明早跑步？', '10000000-0000-4000-8000-000000000001'::uuid,
  NULL) ->> 'id') AS first_message_id \gset
SELECT set_config('test.first_message_id', :'first_message_id', false) \gset

DO $$
DECLARE v_row jsonb;
BEGIN
  SELECT * INTO v_row FROM public.page_squad_timeline(
    current_setting('test.squad_id')::uuid, NULL, NULL, NULL, NULL, 50);
  IF v_row ->> 'id' IS DISTINCT FROM current_setting('test.first_message_id')
     OR v_row -> 'author' ->> 'nickname' IS DISTINCT FROM '甲' THEN
    RAISE EXCEPTION 'timeline did not return the persisted author and message';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.send_text_message(
    current_setting('test.squad_id')::uuid, '到！',
    '20000000-0000-4000-8000-000000000001'::uuid,
    current_setting('test.first_message_id')::uuid);
  IF v_result ->> 'reply_to_message_id' IS DISTINCT FROM
     current_setting('test.first_message_id') THEN
    RAISE EXCEPTION 'explicit reply relation was not persisted';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT (public.publish_card_message(
  :'squad_id'::uuid, 'activity',
  '{"activity_type":"run","date":"2026-10-08","distance_m":5000,"duration_s":1800,"pace_s_per_km":360,"title":"晨跑"}'::jsonb,
  'run-classic', 1, '10000000-0000-4000-8000-000000000002'::uuid,
  '30000000-0000-4000-8000-000000000001'::uuid, NULL) ->> 'card_id') AS card_id \gset
SELECT set_config('test.card_id', :'card_id', false) \gset

DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.publish_card_message(
    current_setting('test.squad_id')::uuid, 'activity',
    '{"activity_type":"run","date":"2026-10-08","distance_m":5000,"duration_s":1800,"pace_s_per_km":360,"title":"晨跑"}'::jsonb,
    'run-classic', 1, '10000000-0000-4000-8000-000000000002'::uuid,
    '30000000-0000-4000-8000-000000000001'::uuid, NULL);
  IF v_result ->> 'card_id' IS DISTINCT FROM current_setting('test.card_id') THEN
    RAISE EXCEPTION 'retry created a different card';
  END IF;
END;
$$;

RESET ROLE;
