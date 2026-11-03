BEGIN;
CREATE FUNCTION pg_temp.check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',label; END IF; END $$;
GRANT EXECUTE ON FUNCTION pg_temp.check(boolean,text) TO anon,authenticated,service_role;
INSERT INTO auth.users(id) VALUES
 ('92000000-0000-4000-8000-000000000001'),('92000000-0000-4000-8000-000000000002'),
 ('92000000-0000-4000-8000-000000000003');
INSERT INTO public.squads(id,name,created_by,status) VALUES
 ('92000000-0000-4000-8000-000000000010','Revocation test','92000000-0000-4000-8000-000000000001','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('92000000-0000-4000-8000-000000000010','92000000-0000-4000-8000-000000000001','captain'),
 ('92000000-0000-4000-8000-000000000010','92000000-0000-4000-8000-000000000002','member');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"92000000-0000-4000-8000-000000000001"}',true);
SELECT public.register_push_token('92000000-0000-4000-8000-000000000020','apns',repeat('cd',32));
SELECT public.register_push_token('92000000-0000-4000-8000-000000000020','mipush','synthetic-revocation-mi');
SELECT set_config('request.jwt.claims','{"sub":"92000000-0000-4000-8000-000000000002"}',true);
SELECT public.register_push_token('92000000-0000-4000-8000-000000000021','apns',repeat('ef',32));
DO $$ BEGIN
 BEGIN PERFORM public.claim_push_work(); RAISE EXCEPTION 'Member claimed server work';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM public.enqueue_photo_sync('92000000-0000-4000-8000-000000000010');
 RAISE EXCEPTION 'Member enqueued work'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN PERFORM count(*) FROM public.photo_sync_deliveries;
 RAISE EXCEPTION 'Member read private queue'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT pg_temp.check(NOT has_function_privilege('anon','public.claim_push_work(integer,text)','EXECUTE'),'Anonymous claim access');
SELECT pg_temp.check(NOT has_function_privilege('authenticated','public.complete_push_work(text,text,uuid,text,text,text)','EXECUTE'),'Member complete access');
SELECT pg_temp.check((SELECT relrowsecurity FROM pg_class WHERE oid='public.photo_sync_deliveries'::regclass),'Queue RLS disabled');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"92000000-0000-4000-8000-000000000001"}',true);
SELECT public.reserve_photo_upload('92000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('a',64),NULL) AS reserved \gset
SELECT :'reserved'::jsonb->>'media_id' AS media,:'reserved'::jsonb->>'attempt_id' AS attempt \gset
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_photo_upload(:'media',:'attempt',repeat('b',64),4,3,500) AS published \gset
RESET ROLE;
SELECT pg_temp.check((SELECT count(*) FROM public.photo_sync_deliveries)=0,'Publication incorrectly generated quiet revoke hint');
SELECT :'published'::jsonb->>'message_id' AS message \gset
SET LOCAL ROLE authenticated;
SELECT public.revoke_photo_message('92000000-0000-4000-8000-000000000010',:'message');
SELECT public.revoke_photo_message('92000000-0000-4000-8000-000000000010',:'message');
RESET ROLE;
SELECT pg_temp.check((SELECT count(*) FROM public.photo_sync_deliveries)=2,'Revocation missed author or member');
SELECT pg_temp.check((SELECT bool_and(generation=1 AND provider='apns') FROM public.photo_sync_deliveries),'Duplicate revoke increased generation or Mi was enqueued');
SAVEPOINT rollback_event;
UPDATE public.squads SET status='pending' WHERE id='92000000-0000-4000-8000-000000000010';
ROLLBACK TO SAVEPOINT rollback_event;
SELECT pg_temp.check((SELECT bool_and(generation=1) FROM public.photo_sync_deliveries),'Rolled-back change left queued event');

-- Lease and deliver before a second event, and preserve a late generation.
SET LOCAL ROLE service_role;
DO $$ DECLARE c record; n int:=0; BEGIN
 FOR c IN SELECT * FROM public.claim_push_work(2,'apns') LOOP
  n:=n+1;
  IF c.lease_kind='photo_sync' THEN
   IF (SELECT count(*) FROM jsonb_object_keys(to_jsonb(c)))<>6 THEN RAISE EXCEPTION 'Unsafe work projection'; END IF;
   IF public.complete_push_work(c.lease_kind,c.delivery_id,gen_random_uuid(),'sent') THEN RAISE EXCEPTION 'Foreign claim accepted'; END IF;
   IF NOT public.complete_push_work(c.lease_kind,c.delivery_id,c.claim_id,'sent') THEN RAISE EXCEPTION 'Quiet completion failed'; END IF;
   IF public.complete_push_work(c.lease_kind,c.delivery_id,c.claim_id,'sent') THEN RAISE EXCEPTION 'Duplicate completion accepted'; END IF;
  ELSE
   IF c.message_kind<>'photo' THEN RAISE EXCEPTION 'Message share lost'; END IF;
   PERFORM public.complete_push_work(c.lease_kind,c.delivery_id,c.claim_id,'sent');
  END IF;
 END LOOP;
 IF n<>2 THEN RAISE EXCEPTION 'Quota failed to leave message share'; END IF;
END $$;
RESET ROLE;
CREATE TEMP TABLE old_lease AS SELECT * FROM public.claim_photo_sync(1);
SELECT pg_temp.check((SELECT count(*) FROM old_lease)=1,'Second quiet target missing');
-- Still two rows; a new event while leased must survive the old receipt.
UPDATE public.squads SET status='pending' WHERE id='92000000-0000-4000-8000-000000000010';
SELECT public.complete_photo_sync(delivery_id,claim_id,'sent') FROM old_lease;
SELECT pg_temp.check((SELECT bool_and(status='pending' AND generation=2) FROM public.photo_sync_deliveries),'Old success swallowed new invalidation');
UPDATE public.squads SET status='active' WHERE id='92000000-0000-4000-8000-000000000010';
DELETE FROM public.squad_members WHERE user_id='92000000-0000-4000-8000-000000000002';
SELECT pg_temp.check((SELECT bool_and(generation=3) FROM public.photo_sync_deliveries),'2-to-1 removal missed either account');
SET LOCAL ROLE service_role;
DO $$ DECLARE c record; n int:=0; BEGIN
 FOR c IN SELECT * FROM public.claim_photo_sync(10) LOOP
  n:=n+1;
  IF NOT public.complete_photo_sync(c.delivery_id,c.claim_id,'retry','transport_error') THEN RAISE EXCEPTION 'Retry failed'; END IF;
 END LOOP;
 IF n<>2 THEN RAISE EXCEPTION 'Former member excluded from quiet claim'; END IF;
 IF EXISTS(SELECT 1 FROM public.claim_photo_sync(10)) THEN RAISE EXCEPTION 'Backoff ignored'; END IF;
END $$;
RESET ROLE;
-- New event resets retry delay. Account C takes B's exact token; B cannot be claimed.
SELECT public.enqueue_photo_sync('92000000-0000-4000-8000-000000000010','92000000-0000-4000-8000-000000000002');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"92000000-0000-4000-8000-000000000003"}',true);
SELECT public.register_push_token('92000000-0000-4000-8000-000000000022','apns',repeat('ef',32));
RESET ROLE;
CREATE TEMP TABLE current_lease AS SELECT * FROM public.claim_photo_sync(10);
SELECT pg_temp.check((SELECT count(*) FROM current_lease)=1,'Reassigned token leaked former account work');
SELECT pg_temp.check((SELECT status='cancelled' FROM public.photo_sync_deliveries WHERE user_id='92000000-0000-4000-8000-000000000002'),'Old account work not cancelled');
-- Rotating A token protects its new registration from a late Unregistered receipt.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"92000000-0000-4000-8000-000000000001"}',true);
SELECT public.register_push_token('92000000-0000-4000-8000-000000000020','apns',repeat('ab',32));
RESET ROLE;
SELECT public.complete_photo_sync(delivery_id,claim_id,'dead','Unregistered',repeat('cd',32)) FROM current_lease;
SELECT pg_temp.check((SELECT active FROM public.device_push_tokens WHERE user_id='92000000-0000-4000-8000-000000000001' AND provider='apns'),'Late old token receipt deactivated new token');
SELECT public.enqueue_photo_sync('92000000-0000-4000-8000-000000000010');
-- An expired lease is reclaimed with a new UUID; its old receipt is rejected.
CREATE TEMP TABLE expired_lease AS SELECT * FROM public.claim_photo_sync(10);
UPDATE public.photo_sync_deliveries SET lease_until=now()-interval '1 second' WHERE status='leased';
CREATE TEMP TABLE reclaimed_lease AS SELECT * FROM public.claim_photo_sync(10);
SELECT pg_temp.check((SELECT count(*) FROM reclaimed_lease)=1,'Expired lease not reclaimed');
SELECT pg_temp.check((SELECT a.claim_id<>b.claim_id FROM expired_lease a JOIN reclaimed_lease b USING(delivery_id)),'Reclaimed lease reused claim identity');
SELECT pg_temp.check(NOT public.complete_photo_sync(delivery_id,claim_id,'sent'),'Expired old lease accepted') FROM expired_lease;
SELECT public.complete_photo_sync(delivery_id,claim_id,'sent') FROM reclaimed_lease;
SELECT public.enqueue_photo_sync('92000000-0000-4000-8000-000000000010');
UPDATE public.photo_sync_deliveries SET attempt_count=7,available_at=now() WHERE status='pending';
CREATE TEMP TABLE exhausted_lease AS SELECT * FROM public.claim_photo_sync(10);
SELECT public.complete_photo_sync(delivery_id,claim_id,'retry') FROM exhausted_lease;
SELECT pg_temp.check((SELECT status='dead' AND attempt_count=8 FROM public.photo_sync_deliveries WHERE user_id='92000000-0000-4000-8000-000000000001'),'Retry bound exceeded');
SELECT public.enqueue_photo_sync('92000000-0000-4000-8000-000000000010');
SELECT pg_temp.check((SELECT status='pending' AND attempt_count=0 FROM public.photo_sync_deliveries WHERE user_id='92000000-0000-4000-8000-000000000001'),'New event did not reset exhausted attempts');
UPDATE public.photo_sync_deliveries SET expires_at=now()-interval '1 second';
SELECT pg_temp.check(NOT EXISTS(SELECT 1 FROM public.claim_photo_sync(10)),'Expired event was claimed');
SELECT pg_temp.check((SELECT bool_and(status='cancelled') FROM public.photo_sync_deliveries),'Expired work not cancelled');
UPDATE public.photo_sync_deliveries SET updated_at=now()-interval '8 days';
SELECT count(*) FROM public.claim_photo_sync(10);
SELECT pg_temp.check((SELECT count(*) FROM public.photo_sync_deliveries)=0,'Terminal retention failed');

-- Queue survives actual Squad deletion; member triggers can coalesce more than once.
INSERT INTO public.squads(id,name,created_by,status) VALUES
 ('92000000-0000-4000-8000-000000000011','Delete test','92000000-0000-4000-8000-000000000001','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('92000000-0000-4000-8000-000000000011','92000000-0000-4000-8000-000000000001','captain');
DELETE FROM public.squads WHERE id='92000000-0000-4000-8000-000000000011';
SELECT pg_temp.check((SELECT count(*) FROM public.photo_sync_deliveries)=1,'Squad cascade lost clearing hint');
SELECT pg_temp.check((SELECT count(*) FROM public.claim_photo_sync(10))=1,'Deleted Squad work cannot be claimed');
ROLLBACK;
