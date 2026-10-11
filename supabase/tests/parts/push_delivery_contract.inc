-- Server-only per-device delivery and idempotent claim completion.
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT public.register_push_token(
  '50000000-0000-4000-8000-000000000003'::uuid,
  'apns', 'test-token-B');
SELECT public.register_push_token(
  '50000000-0000-4000-8000-000000000003'::uuid,
  'mipush', 'mi-test-registration-id-B');
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT public.send_text_message(
  (SELECT id FROM public.squads WHERE name = '跑步小队'),
  '派送契约测试', '10000000-0000-4000-8000-000000000099'::uuid,
  NULL);
RESET ROLE;

DO $$
BEGIN
  IF has_function_privilege('authenticated', 'public.claim_push_deliveries(integer,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.complete_push_delivery(bigint,uuid,text,text,text)', 'EXECUTE')
     OR has_table_privilege('authenticated', 'public.message_push_deliveries', 'SELECT') THEN
    RAISE EXCEPTION 'push delivery secret exposed to client';
  END IF;
  IF (SELECT count(*) FROM public.message_push_deliveries d
      JOIN public.squad_messages m ON m.id = d.message_id
      WHERE m.body = '派送契约测试') <> 2 THEN
    RAISE EXCEPTION 'message did not enqueue both APNs and Mi Push teammate devices';
  END IF;
END;
$$;

SET ROLE service_role;
DO $$
DECLARE
  v_claim record;
BEGIN
  SELECT * INTO v_claim FROM public.claim_push_deliveries(10, 'apns');
  IF NOT FOUND OR v_claim.provider IS DISTINCT FROM 'apns'
     OR v_claim.token IS DISTINCT FROM 'test-token-B' THEN
    RAISE EXCEPTION 'server did not claim the intended device token';
  END IF;
  IF (SELECT count(*) FROM public.claim_push_deliveries(10, 'apns')) <> 0 THEN
    RAISE EXCEPTION 'leased delivery was claimed twice';
  END IF;
  IF NOT public.complete_push_delivery(
      v_claim.delivery_id, v_claim.claim_id, 'sent', NULL, NULL) THEN
    RAISE EXCEPTION 'valid delivery completion failed';
  END IF;
  IF public.complete_push_delivery(
      v_claim.delivery_id, v_claim.claim_id, 'sent', NULL, NULL) THEN
    RAISE EXCEPTION 'delivery completed twice';
  END IF;
  SELECT * INTO v_claim FROM public.claim_push_deliveries(10, 'mipush');
  IF NOT FOUND OR v_claim.provider IS DISTINCT FROM 'mipush'
     OR v_claim.token IS DISTINCT FROM 'mi-test-registration-id-B' THEN
    RAISE EXCEPTION 'server did not claim the intended Mi Push registration ID';
  END IF;
  IF NOT public.complete_push_delivery(
      v_claim.delivery_id, v_claim.claim_id, 'sent', NULL, NULL) THEN
    RAISE EXCEPTION 'Mi Push delivery completion failed';
  END IF;
END;
$$;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SELECT public.send_text_message(
  (SELECT id FROM public.squads WHERE name = '跑步小队'),
  '失效MiPush令牌契约测试', '10000000-0000-4000-8000-000000000097'::uuid,
  NULL);
RESET ROLE;

SET ROLE service_role;
DO $$
DECLARE v_claim record;
BEGIN
  SELECT * INTO v_claim FROM public.claim_push_deliveries(10, 'apns');
  IF NOT FOUND THEN RAISE EXCEPTION 'APNs companion delivery was not claimed'; END IF;
  PERFORM public.complete_push_delivery(
    v_claim.delivery_id, v_claim.claim_id, 'sent', NULL, NULL);

  SELECT * INTO v_claim FROM public.claim_push_deliveries(10, 'mipush');
  IF NOT FOUND OR v_claim.token IS DISTINCT FROM 'mi-test-registration-id-B' THEN
    RAISE EXCEPTION 'invalid Mi Push registration ID was not claimed';
  END IF;
  IF NOT public.complete_push_delivery(
      v_claim.delivery_id, v_claim.claim_id, 'dead',
      'InvalidRegId', v_claim.token) THEN
    RAISE EXCEPTION 'invalid Mi Push registration ID result not recorded';
  END IF;
END;
$$;
RESET ROLE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.device_push_tokens
      WHERE provider = 'mipush' AND token = 'mi-test-registration-id-B' AND active) THEN
    RAISE EXCEPTION 'invalid Mi Push registration ID stayed active';
  END IF;
  IF (SELECT o.status FROM public.message_outbox o
      JOIN public.squad_messages m ON m.id = o.message_id
      WHERE m.body = '失效MiPush令牌契约测试') IS DISTINCT FROM 'dead' THEN
    RAISE EXCEPTION 'Mi Push failure not reflected in outbox';
  END IF;
END;
$$;
RESET ROLE;

DO $$
BEGIN
  IF (SELECT o.status FROM public.message_outbox o
      JOIN public.squad_messages m ON m.id = o.message_id
      WHERE m.body = '派送契约测试') IS DISTINCT FROM 'sent' THEN
    RAISE EXCEPTION 'outbox not settled after device delivery';
  END IF;
END;
$$;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
SELECT public.send_text_message(
  (SELECT id FROM public.squads WHERE name = '跑步小队'),
  '失效令牌契约测试', '10000000-0000-4000-8000-000000000098'::uuid,
  NULL);
RESET ROLE;

SET ROLE service_role;
DO $$
DECLARE v_claim record;
BEGIN
  SELECT * INTO v_claim FROM public.claim_push_deliveries(10, 'apns');
  IF NOT FOUND OR v_claim.token IS DISTINCT FROM 'test-token-A' THEN
    RAISE EXCEPTION 'wrong APNs token claimed for reverse message';
  END IF;
  IF NOT public.complete_push_delivery(
      v_claim.delivery_id, v_claim.claim_id, 'dead',
      'BadDeviceToken', v_claim.token) THEN
    RAISE EXCEPTION 'invalid APNs token result not recorded';
  END IF;
END;
$$;
RESET ROLE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.device_push_tokens
      WHERE provider = 'apns' AND token = 'test-token-A' AND active) THEN
    RAISE EXCEPTION 'invalid APNs token stayed active';
  END IF;
  IF (SELECT o.status FROM public.message_outbox o
      JOIN public.squad_messages m ON m.id = o.message_id
      WHERE m.body = '失效令牌契约测试') IS DISTINCT FROM 'dead' THEN
    RAISE EXCEPTION 'failed delivery not reflected in outbox';
  END IF;
END;
$$;
