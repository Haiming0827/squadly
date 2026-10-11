-- Run after registration_contract.sql in the same test database.
DO $$
BEGIN
  IF (SELECT count(*) FROM public.message_outbox) < 1 THEN
    RAISE EXCEPTION 'message publish did not create outbox events';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'message_outbox'
        AND column_name IN ('body', 'snapshot', 'route', 'ciphertext', 'token')) THEN
    RAISE EXCEPTION 'outbox includes sensitive payload fields';
  END IF;
END;
$$;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT public.register_push_token(
  '50000000-0000-4000-8000-000000000001'::uuid,
  'apns', 'test-token-A');
-- Reinstalling can assign a new installation ID while APNs keeps its token.
SELECT public.register_push_token(
  '50000000-0000-4000-8000-000000000002'::uuid,
  'apns', 'test-token-A');

DO $$
BEGIN
  IF (SELECT count(*) FROM public.device_push_tokens
      WHERE user_id = auth.uid() AND active) <> 1 THEN
    RAISE EXCEPTION 'owner cannot see own registered push token';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.device_push_tokens
      WHERE user_id = auth.uid()
        AND device_id = '50000000-0000-4000-8000-000000000002'::uuid) THEN
    RAISE EXCEPTION 'APNs token did not follow reinstalled device';
  END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.device_push_tokens
      WHERE user_id = '00000000-0000-4000-8000-000000000001') THEN
    RAISE EXCEPTION 'stranger can see push token';
  END IF;
END;
$$;
RESET ROLE;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.message_outbox', 'SELECT')
     OR has_table_privilege('anon', 'public.message_outbox', 'SELECT') THEN
    RAISE EXCEPTION 'client can read service outbox';
  END IF;
END;
$$;
