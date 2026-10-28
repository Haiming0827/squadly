BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',label; END IF; END $$;
GRANT EXECUTE ON FUNCTION pg_temp.assert_true(boolean,text) TO authenticated,anon,service_role;
INSERT INTO auth.users(id) VALUES
 ('91000000-0000-4000-8000-000000000001'),('91000000-0000-4000-8000-000000000002');
INSERT INTO public.squads(id,name,created_by,status) VALUES
 ('91000000-0000-4000-8000-000000000010','Push fixture','91000000-0000-4000-8000-000000000001','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('91000000-0000-4000-8000-000000000010','91000000-0000-4000-8000-000000000001','captain'),
 ('91000000-0000-4000-8000-000000000010','91000000-0000-4000-8000-000000000002','member');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000002"}',true);
SELECT public.register_push_token('91000000-0000-4000-8000-000000000020','apns',repeat('ab',32));
SELECT public.register_push_token('91000000-0000-4000-8000-000000000020','mipush','synthetic-mi-registration');
DO $$ BEGIN
 BEGIN
  PERFORM public.claim_push_deliveries_v2(20,'apns');
  RAISE EXCEPTION 'Member read server-only token claims';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.claim_push_deliveries_v2(integer,text)','EXECUTE'),'Anonymous V2 access granted');
SELECT set_config('request.jwt.claims','{"sub":"91000000-0000-4000-8000-000000000001"}',true);
SELECT public.send_text_message('91000000-0000-4000-8000-000000000010','Not in push projection',gen_random_uuid(),NULL);
SELECT public.reserve_photo_upload('91000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('a',64),NULL) AS reserved \gset
SELECT :'reserved'::jsonb->>'media_id' AS media,:'reserved'::jsonb->>'attempt_id' AS attempt \gset
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_photo_upload(:'media',:'attempt',repeat('b',64),4,3,500);
DO $$
DECLARE c record; n int:=0; kinds text[]:='{}'; projection jsonb;
BEGIN
 FOR c IN SELECT * FROM public.claim_push_deliveries_v2(20,'apns') LOOP
  n:=n+1;kinds:=array_append(kinds,c.message_kind);projection:=to_jsonb(c);
  IF (SELECT count(*) FROM jsonb_object_keys(projection))<>7
    OR projection ?| ARRAY['body','card','photo','url','bytes','author','nickname']
    OR c.token<>repeat('ab',32) OR c.provider<>'apns' THEN
   RAISE EXCEPTION 'Unsafe or incorrect V2 projection';
  END IF;
  IF public.complete_push_delivery(c.delivery_id,gen_random_uuid(),'sent',NULL,NULL) THEN
   RAISE EXCEPTION 'Foreign lease completed a delivery';
  END IF;
  IF NOT public.complete_push_delivery(c.delivery_id,c.claim_id,
    CASE WHEN c.message_kind='photo' THEN 'retry' ELSE 'sent' END,NULL,NULL) THEN
   RAISE EXCEPTION 'V2 lease incompatible with completion';
  END IF;
  IF public.complete_push_delivery(c.delivery_id,c.claim_id,'sent',NULL,NULL) THEN
   RAISE EXCEPTION 'Delivery completed twice';
  END IF;
 END LOOP;
 IF n<>2 OR NOT kinds @> ARRAY['text','photo'] THEN RAISE EXCEPTION 'Wrong APNs message kinds'; END IF;
 IF EXISTS(SELECT 1 FROM public.claim_push_deliveries_v2(20,'apns')) THEN
  RAISE EXCEPTION 'Retry skipped backoff';
 END IF;
 n:=0;
 FOR c IN SELECT * FROM public.claim_push_deliveries_v2(20,'mipush') LOOP
  n:=n+1;
  IF c.token<>'synthetic-mi-registration' THEN RAISE EXCEPTION 'Wrong Mi token'; END IF;
  IF NOT public.complete_push_delivery(c.delivery_id,c.claim_id,'sent',NULL,NULL) THEN
   RAISE EXCEPTION 'Mi completion failed';
  END IF;
 END LOOP;
 IF n<>2 THEN RAISE EXCEPTION 'APNs retry blocked the Mi channel'; END IF;
END $$;
RESET ROLE;
DELETE FROM public.squad_members WHERE squad_id='91000000-0000-4000-8000-000000000010'
 AND user_id='91000000-0000-4000-8000-000000000002';
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.claim_push_deliveries_v2(20,'apns')),'Departed member claimed push');
RESET ROLE;
SELECT pg_temp.assert_true((SELECT count(*) FROM public.message_push_deliveries
 WHERE squad_id='91000000-0000-4000-8000-000000000010' AND status='cancelled')=1,'Departed member retry not cancelled');
ROLLBACK;
