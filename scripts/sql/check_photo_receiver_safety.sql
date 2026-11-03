BEGIN;
CREATE FUNCTION pg_temp.check(ok boolean,label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',label; END IF; END $$;
GRANT EXECUTE ON FUNCTION pg_temp.check(boolean,text) TO authenticated,anon,service_role;
INSERT INTO auth.users(id) VALUES('95000000-0000-4000-8000-000000000001'),('95000000-0000-4000-8000-000000000002'),('95000000-0000-4000-8000-000000000003');
INSERT INTO public.squads(id,name,created_by,status) VALUES('95000000-0000-4000-8000-000000000010','Safety fixture','95000000-0000-4000-8000-000000000001','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000001','captain'),
 ('95000000-0000-4000-8000-000000000010','95000000-0000-4000-8000-000000000002','member');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"95000000-0000-4000-8000-000000000002"}',true);
SELECT public.register_push_token('95000000-0000-4000-8000-000000000020','apns',repeat('95',32));
SELECT set_config('request.jwt.claims','{"sub":"95000000-0000-4000-8000-000000000001"}',true);
SELECT public.register_push_token('95000000-0000-4000-8000-000000000021','apns',repeat('96',32));
SELECT public.reserve_photo_upload('95000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('a',64),NULL) AS r1 \gset
SELECT public.reserve_photo_upload('95000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('b',64),NULL) AS r2 \gset
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_photo_upload((:'r1'::jsonb->>'media_id')::uuid,(:'r1'::jsonb->>'attempt_id')::uuid,repeat('c',64),4,3,500) AS p1 \gset
SELECT public.complete_photo_upload((:'r2'::jsonb->>'media_id')::uuid,(:'r2'::jsonb->>'attempt_id')::uuid,repeat('d',64),4,3,500) AS p2 \gset
RESET ROLE;
-- Deterministic latest photo independent of transaction-stable now().
UPDATE public.squad_messages SET created_at=now()-interval '1 second' WHERE id=(:'p1'::jsonb->>'message_id')::uuid;
SELECT :'p1'::jsonb->>'message_id' AS first,:'p2'::jsonb->>'message_id' AS latest \gset
SET LOCAL ROLE authenticated;
SELECT pg_temp.check((public.get_squad_photo_head('95000000-0000-4000-8000-000000000010')->>'revision')='2','Initial public version wrong');
SELECT pg_temp.check((public.report_photo_message('95000000-0000-4000-8000-000000000010',:'latest','privacy')->>'error')='not_found','Author reported self');
SELECT set_config('request.jwt.claims','{"sub":"95000000-0000-4000-8000-000000000002"}',true);
-- Prepare reply before hiding its parent; final certification must still reject.
SELECT public.reserve_photo_upload('95000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('e',64),:'latest') AS reply \gset
SELECT pg_temp.check((public.hide_photo_message('95000000-0000-4000-8000-000000000010',:'latest')->>'hidden')::boolean,'Hide not confirmed');
SELECT public.hide_photo_message('95000000-0000-4000-8000-000000000010',:'latest');
SELECT pg_temp.check((public.get_squad_photo_head('95000000-0000-4000-8000-000000000010')->>'revision')='3','Private version not monotonic/idempotent');
SELECT pg_temp.check(public.get_squad_photo_head('95000000-0000-4000-8000-000000000010')->'photo'->>'id'=:'first','Hidden latest not replaced by previous photo');
SELECT pg_temp.check((SELECT e->'photo' FROM public.page_squad_timeline('95000000-0000-4000-8000-000000000010') e WHERE e->>'id'=:'latest')->>'hidden'='true','Timeline lost hidden tombstone');
SELECT pg_temp.check(public.get_squad_photo('95000000-0000-4000-8000-000000000010',:'latest') IS NULL,'Hidden photo deep link visible');
SELECT pg_temp.check((SELECT count(*) FROM public.page_squad_photos('95000000-0000-4000-8000-000000000010'))=1,'Hidden photo in wall');
SELECT pg_temp.check(public.authorize_photo_read('95000000-0000-4000-8000-000000000010',:'latest')->>'error'='not_found','Hidden bytes readable');
SELECT pg_temp.check(public.reserve_photo_upload('95000000-0000-4000-8000-000000000010',gen_random_uuid(),repeat('f',64),:'latest')->>'error'='invalid_reply','New reply accepted hidden parent');
SELECT pg_temp.check(public.report_photo_message('95000000-0000-4000-8000-000000000010',:'latest','free-form-secret')->>'error'='invalid_report','Arbitrary report reason accepted');
SELECT pg_temp.check((public.report_photo_message('95000000-0000-4000-8000-000000000010',:'latest','privacy')->>'reported')::boolean,'Report missing');
SELECT public.report_photo_message('95000000-0000-4000-8000-000000000010',:'latest','spam');
DO $$ BEGIN
 BEGIN PERFORM count(*) FROM public.photo_reports;RAISE EXCEPTION 'Member read reports';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN PERFORM count(*) FROM public.hidden_photos;RAISE EXCEPTION 'Member read hidden preferences';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;
SELECT pg_temp.check((SELECT count(*) FROM public.photo_reports)=1,'Duplicate report recorded');
SELECT pg_temp.check((SELECT reason='privacy' FROM public.photo_reports),'Retry rewrote original report');
SELECT pg_temp.check((SELECT count(*)=1 AND bool_and(user_id='95000000-0000-4000-8000-000000000002') FROM public.photo_sync_deliveries WHERE squad_id='95000000-0000-4000-8000-000000000010'),'Private hide broadcast to author');
SET LOCAL ROLE service_role;
SELECT pg_temp.check(public.complete_photo_upload((:'reply'::jsonb->>'media_id')::uuid,(:'reply'::jsonb->>'attempt_id')::uuid,repeat('f',64),4,3,500)->>'error'='invalid_reply','In-flight reply resurrected hidden parent');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"95000000-0000-4000-8000-000000000001"}',true);
SELECT pg_temp.check(public.get_squad_photo_head('95000000-0000-4000-8000-000000000010')->>'revision'='2','Private hide changed author version');
SELECT pg_temp.check(public.get_squad_photo_head('95000000-0000-4000-8000-000000000010')->'photo'->>'id'=:'latest','Author lost original view');
SELECT pg_temp.check(NOT ((SELECT e->'photo' FROM public.page_squad_timeline('95000000-0000-4000-8000-000000000010') e WHERE e->>'id'=:'latest') ? 'hidden'),'Author saw private hide flag');
SELECT pg_temp.check((SELECT count(*) FROM public.page_squad_photos('95000000-0000-4000-8000-000000000010'))=2,'Author wall changed');
SELECT pg_temp.check(public.authorize_photo_read('95000000-0000-4000-8000-000000000010',:'latest') ? 'object_key','Author lost byte access');
SELECT set_config('request.jwt.claims','{"sub":"95000000-0000-4000-8000-000000000003"}',true);
SELECT pg_temp.check(public.hide_photo_message('95000000-0000-4000-8000-000000000010',:'latest')->>'error'='not_found','Nonmember hid photo');
SELECT pg_temp.check(public.report_photo_message('95000000-0000-4000-8000-000000000010',:'latest','privacy')->>'error'='not_found','Nonmember reported photo');
RESET ROLE;
SELECT pg_temp.check(NOT has_function_privilege('anon','public.hide_photo_message(uuid,uuid)','EXECUTE'),'Anonymous hide grant');
SELECT pg_temp.check(NOT has_function_privilege('anon','public.report_photo_message(uuid,uuid,text)','EXECUTE'),'Anonymous report grant');
ROLLBACK;
