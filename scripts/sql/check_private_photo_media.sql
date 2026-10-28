BEGIN;
CREATE FUNCTION pg_temp.assert_true(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION '%',label; END IF; END $$;
GRANT EXECUTE ON FUNCTION pg_temp.assert_true(boolean,text) TO authenticated,anon,service_role;
INSERT INTO auth.users(id) VALUES
 ('90000000-0000-4000-8000-000000000001'),('90000000-0000-4000-8000-000000000002'),
 ('90000000-0000-4000-8000-000000000003');
INSERT INTO public.squads(id,name,created_by,status) VALUES
 ('90000000-0000-4000-8000-000000000010','Photo team','90000000-0000-4000-8000-000000000001','active'),
 ('90000000-0000-4000-8000-000000000011','Other team','90000000-0000-4000-8000-000000000003','active');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('90000000-0000-4000-8000-000000000010','90000000-0000-4000-8000-000000000001','captain'),
 ('90000000-0000-4000-8000-000000000010','90000000-0000-4000-8000-000000000002','member'),
 ('90000000-0000-4000-8000-000000000011','90000000-0000-4000-8000-000000000003','captain');
CREATE POLICY broad_legacy_objects ON storage.objects FOR ALL TO anon,authenticated USING(true) WITH CHECK(true);
CREATE POLICY broad_legacy_buckets ON storage.buckets FOR ALL TO anon,authenticated USING(true) WITH CHECK(true);
INSERT INTO storage.objects(bucket_id,name) VALUES('squadly-photos','secret.jpg');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000001"}',true);
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010') =
 '{"revision":"0","photo":null}'::jsonb,'New team photo head is not empty version zero');
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='squadly-photos')
  OR EXISTS(SELECT 1 FROM storage.buckets WHERE id='squadly-photos')
 THEN RAISE EXCEPTION 'Private bucket bypasses restrictive RLS'; END IF;
 BEGIN
  INSERT INTO storage.objects(bucket_id,name) VALUES('squadly-photos','bypass.jpg');
  RAISE EXCEPTION 'Client uploaded directly';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM public.complete_photo_upload(gen_random_uuid(),gen_random_uuid(),repeat('a',64),4,3,500);
  RAISE EXCEPTION 'Client certified own photo';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN
  PERFORM * FROM public.photo_media;
  RAISE EXCEPTION 'Client read internal metadata';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SELECT public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000020',repeat('a',64),NULL) AS reserved \gset
SELECT :'reserved'::jsonb->>'media_id' AS media_id, :'reserved'::jsonb->>'attempt_id' AS attempt_id \gset
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->>'revision'='0','Preparing upload changed head');
SELECT pg_temp.assert_true(public.authorize_photo_upload_attempt(:'media_id',:'attempt_id')->>'authorized'='true','Original caller cannot reauthorize');
SELECT pg_temp.assert_true(public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000020',repeat('b',64),NULL)->>'error'='nonce_conflict','Changed content reused nonce');
SELECT pg_temp.assert_true(public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000020',repeat('a',64),NULL)->>'error'='upload_busy','Parallel upload not serialized');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true(public.complete_photo_upload(:'media_id',:'attempt_id',repeat('c',64),0,3,500)->>'error'='invalid_photo','Invalid dimensions accepted');
SELECT public.complete_photo_upload(:'media_id',:'attempt_id',repeat('c',64),4,3,500) AS published \gset
SELECT :'published'::jsonb->>'message_id' AS message_id \gset
SELECT pg_temp.assert_true(public.complete_photo_upload(:'media_id',:'attempt_id',repeat('c',64),4,3,500)=:'published'::jsonb,'Completion not idempotent');
RESET ROLE;
UPDATE public.photo_upload_attempts SET expires_at=now()-interval '1 hour' WHERE id=:'attempt_id';
SELECT pg_temp.assert_true((SELECT count(*) FROM public.squad_messages WHERE photo_id=:'media_id')=1,'Retry duplicated message');
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.claim_photo_cleanup(20)),'Cleanup claimed live published object');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000002"}',true);
SELECT pg_temp.assert_true(public.authorize_photo_read('90000000-0000-4000-8000-000000000010',:'message_id')->>'sha256'=repeat('c',64),'Member cannot read');
SELECT e AS timeline FROM public.page_squad_timeline('90000000-0000-4000-8000-000000000010') e
 WHERE e->>'id'=:'message_id' \gset
SELECT pg_temp.assert_true(:'timeline'::jsonb->>'kind'='photo' AND :'timeline' NOT LIKE '%object_key%' AND :'timeline' NOT LIKE '%sha256%','Unsafe timeline projection');
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010') =
 jsonb_build_object('revision','1','photo',:'timeline'::jsonb),'Atomic head or idempotent publication stamp diverged');
SELECT pg_temp.assert_true(public.revoke_photo_message('90000000-0000-4000-8000-000000000010',:'message_id')->>'error'='not_found','Non-author revoked photo');

SELECT pg_temp.assert_true((SELECT count(*) FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010',NULL,NULL,1))=1,'Latest photo missing');
SELECT pg_temp.assert_true(public.get_squad_photo('90000000-0000-4000-8000-000000000010',:'message_id')=:'timeline'::jsonb,'Photo lookup diverges from timeline');
SELECT pg_temp.assert_true(public.get_squad_photo('90000000-0000-4000-8000-000000000011',:'message_id') IS NULL,'Lookup crossed squad');
SELECT public.send_text_message('90000000-0000-4000-8000-000000000010','synthetic text',gen_random_uuid(),NULL) FROM generate_series(1,60);
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->>'revision'='1','Text changed photo head');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010',NULL,NULL,1))=1,'Recent text hid latest photo');
SELECT pg_temp.assert_true(NOT has_function_privilege('anon','public.page_squad_photos(uuid,timestamp with time zone,uuid,integer)','EXECUTE'),'Anonymous photo query granted');

SELECT public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000021',repeat('d',64),:'message_id') AS reply_reserved \gset
SELECT :'reply_reserved'::jsonb->>'media_id' AS reply_media, :'reply_reserved'::jsonb->>'attempt_id' AS reply_attempt \gset
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000003"}',true);
SELECT pg_temp.assert_true(public.authorize_photo_read('90000000-0000-4000-8000-000000000010',:'message_id')->>'error'='not_found','Outsider read photo');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010')),'Outsider queried photos');
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010') IS NULL,'Outsider read version or photo');
SELECT pg_temp.assert_true(public.reserve_photo_upload('90000000-0000-4000-8000-000000000011',
 '90000000-0000-4000-8000-000000000022',repeat('a',64),:'message_id')->>'error'='invalid_reply','Cross-squad reply accepted');
RESET ROLE;
SET LOCAL ROLE service_role;
SELECT public.complete_photo_upload(:'reply_media',:'reply_attempt',repeat('e',64),4,3,500) AS reply_published \gset
SELECT pg_temp.assert_true(:'reply_published'::jsonb->>'reply_to_message_id'=:'message_id','Different author photo reply lost parent');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000002"}',true);
-- Both timestamps and IDs participate in the photo-only cursor.
SELECT e->>'id' AS cursor_id,e->>'created_at' AS cursor_time
 FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010',NULL,NULL,1) e \gset
SELECT pg_temp.assert_true((SELECT count(*) FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010',:'cursor_time',:'cursor_id',50))=1,'Photo cursor skipped or repeated an entry');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010',:'cursor_time',:'cursor_id',50) e WHERE e->>'id'=:'cursor_id'),'Photo cursor repeated its boundary');
DO $$ BEGIN
 BEGIN
  PERFORM public.page_squad_photos('90000000-0000-4000-8000-000000000010',now(),NULL,1);
  RAISE EXCEPTION 'Accepted half cursor';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM <> 'invalid_cursor' THEN RAISE; END IF;
 END;
END $$;
SELECT public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000024',repeat('d',64),NULL) AS late_reserved \gset
SELECT :'late_reserved'::jsonb->>'media_id' AS late_media, :'late_reserved'::jsonb->>'attempt_id' AS late_attempt \gset
RESET ROLE;
DELETE FROM public.squad_members WHERE squad_id='90000000-0000-4000-8000-000000000010' AND user_id='90000000-0000-4000-8000-000000000002';
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true(public.complete_photo_upload(:'late_media',:'late_attempt',repeat('a',64),4,3,500)->>'error'='not_member','Left during upload but still published');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000002"}',true);
SELECT pg_temp.assert_true(public.authorize_photo_read('90000000-0000-4000-8000-000000000010',:'message_id')->>'error'='not_found','Departed member still reads');
SELECT pg_temp.assert_true(public.get_squad_photo('90000000-0000-4000-8000-000000000010',:'message_id') IS NULL,'Departed member looked up photo');
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010') IS NULL,'Departed member read head');
SELECT pg_temp.assert_true(public.authorize_photo_upload_attempt(:'late_media',:'late_attempt')->>'error'='not_member','Departed caller can certify upload');
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000001"}',true);
SELECT public.revoke_photo_message('90000000-0000-4000-8000-000000000010',:'message_id');
SELECT pg_temp.assert_true(public.authorize_photo_read('90000000-0000-4000-8000-000000000010',:'message_id')->>'error'='not_found','Revoked photo still reads');
SELECT pg_temp.assert_true(public.get_squad_photo('90000000-0000-4000-8000-000000000010',:'message_id') IS NULL,'Revoked parent remained available');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.page_squad_photos('90000000-0000-4000-8000-000000000010') e WHERE e->>'id'=:'message_id'),'Revoked photo remained in photo page');
SELECT pg_temp.assert_true(public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000020',repeat('a',64),NULL)->>'error'='revoked','Retry resurrected revoked photo');
SELECT public.reserve_photo_upload('90000000-0000-4000-8000-000000000010',
 '90000000-0000-4000-8000-000000000023',repeat('f',64),NULL) AS expired_reserved \gset
SELECT :'expired_reserved'::jsonb->>'media_id' AS expired_media, :'expired_reserved'::jsonb->>'attempt_id' AS expired_attempt \gset
RESET ROLE;
UPDATE public.photo_upload_attempts SET expires_at=now()-interval '1 hour' WHERE id=:'expired_attempt';
SET LOCAL ROLE service_role;
SELECT pg_temp.assert_true(public.complete_photo_upload(:'expired_media',:'expired_attempt',repeat('f',64),4,3,500)->>'error'='upload_expired','Expired upload published');
SELECT pg_temp.assert_true((SELECT count(*) FROM public.claim_photo_cleanup(20))=2,'Cleanup failed revoked and orphan candidates');
SELECT pg_temp.assert_true(public.complete_photo_cleanup(:'attempt_id',gen_random_uuid())=false,'Stale cleanup claim accepted');
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
 BEGIN
  PERFORM public.authorize_photo_read(gen_random_uuid(),gen_random_uuid());
  RAISE EXCEPTION 'Anonymous read RPC allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='squadly-photos') THEN RAISE EXCEPTION 'Anonymous storage read allowed'; END IF;
END $$;
RESET ROLE;
-- Runs inside the private-photo fixture transaction, after original revocation.
SELECT pg_temp.assert_true((SELECT relrowsecurity FROM pg_class WHERE oid='public.squad_photo_heads'::regclass),'Head table RLS missing');
SELECT pg_temp.assert_true(NOT has_table_privilege('authenticated','public.squad_photo_heads','SELECT')
 AND NOT has_table_privilege('authenticated','public.squad_photo_heads','INSERT')
 AND NOT has_function_privilege('authenticated','public.bump_squad_photo_head(uuid)','EXECUTE')
 AND NOT has_function_privilege('anon','public.get_squad_photo_head(uuid)','EXECUTE'),'Head GRANT leaked');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
 ('90000000-0000-4000-8000-000000000010','90000000-0000-4000-8000-000000000002','member');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000001"}',true);
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->>'revision'='3','Publish/revoke version count wrong');
SELECT public.revoke_photo_message('90000000-0000-4000-8000-000000000010',:'message_id');
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->>'revision'='3','Repeated revoke changed version');
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->'photo'->>'id'=(:'reply_published'::jsonb->>'message_id'),'Revocation did not expose remaining photo');
SELECT set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000002"}',true);
SELECT public.revoke_photo_message('90000000-0000-4000-8000-000000000010',(:'reply_published'::jsonb->>'message_id')::uuid);
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010') =
 '{"revision":"4","photo":null}'::jsonb,'Revoked last photo lost empty version');
DO $$ BEGIN
 BEGIN
  UPDATE public.squad_photo_heads SET revision=0;
  RAISE EXCEPTION 'Member changed revision';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- bigint must remain a string above JavaScript's exact-integer range.
UPDATE public.squad_photo_heads SET revision=9007199254740993 WHERE squad_id='90000000-0000-4000-8000-000000000010';
SET LOCAL ROLE authenticated;
SELECT pg_temp.assert_true(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->>'revision'='9007199254740993'
 AND jsonb_typeof(public.get_squad_photo_head('90000000-0000-4000-8000-000000000010')->'revision')='string','Version lost bigint precision');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.conversation_read_cursors WHERE squad_id='90000000-0000-4000-8000-000000000010'),'Head advanced read cursor');
RESET ROLE;

ROLLBACK;
