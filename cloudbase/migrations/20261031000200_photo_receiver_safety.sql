DO $migration$
BEGIN
CREATE TABLE public.hidden_photos (
 user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
 message_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,message_id),
 FOREIGN KEY(message_id,squad_id) REFERENCES public.squad_messages(id,squad_id) ON DELETE CASCADE
);
CREATE TABLE public.photo_visibility_heads (
 user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
 revision bigint NOT NULL CHECK(revision>0),
 PRIMARY KEY(user_id,squad_id)
);
CREATE TABLE public.photo_reports (
 reporter_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
 message_id uuid NOT NULL,
 reason text NOT NULL CHECK(reason IN ('spam','harassment','privacy','other')),
 status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(reporter_id,message_id),
 FOREIGN KEY(message_id,squad_id) REFERENCES public.squad_messages(id,squad_id) ON DELETE CASCADE
);
ALTER TABLE public.hidden_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_visibility_heads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.hidden_photos,public.photo_visibility_heads,public.photo_reports FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.hidden_photos,public.photo_visibility_heads,public.photo_reports TO service_role;
CREATE INDEX photo_reports_open_idx ON public.photo_reports(created_at) WHERE status='open';

CREATE FUNCTION public.is_photo_hidden(p_squad_id uuid,p_message_id uuid,p_user_id text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.hidden_photos h
  WHERE h.squad_id=p_squad_id AND h.message_id=p_message_id AND h.user_id=p_user_id);
$$;
REVOKE ALL ON FUNCTION public.is_photo_hidden(uuid,uuid,text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.hide_photo_message(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user text:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 PERFORM 1 FROM public.squad_members WHERE squad_id=p_squad_id AND user_id=v_user FOR KEY SHARE;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_user FOR UPDATE;
 IF NOT EXISTS(SELECT 1 FROM public.squad_messages WHERE id=p_message_id
  AND squad_id=p_squad_id AND kind='photo' AND plan_id IS NULL)
 THEN RETURN jsonb_build_object('error','not_found'); END IF;
 INSERT INTO public.hidden_photos(user_id,squad_id,message_id) VALUES(v_user,p_squad_id,p_message_id)
 ON CONFLICT(user_id,message_id) DO NOTHING;
 IF FOUND THEN
  INSERT INTO public.photo_visibility_heads(user_id,squad_id,revision) VALUES(v_user,p_squad_id,1)
  ON CONFLICT(user_id,squad_id) DO UPDATE SET revision=public.photo_visibility_heads.revision+1;
  -- Only this account's devices: do not broadcast private hiding to teammates.
  INSERT INTO public.photo_sync_deliveries(squad_id,user_id,device_id,provider)
  SELECT p_squad_id,t.user_id,t.device_id,t.provider FROM public.device_push_tokens t
  WHERE t.user_id=v_user AND t.active AND t.provider='apns' ORDER BY t.device_id
  ON CONFLICT(squad_id,user_id,device_id,provider) DO UPDATE SET
   generation=public.photo_sync_deliveries.generation+1,
   status=CASE WHEN public.photo_sync_deliveries.status='leased' THEN 'leased' ELSE 'pending' END,
   attempt_count=0,available_at=now(),expires_at=now()+interval '24 hours',updated_at=now(),last_error_code=NULL;
 END IF;
 RETURN jsonb_build_object('hidden',true);
END $$;

CREATE FUNCTION public.report_photo_message(p_squad_id uuid,p_message_id uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_hidden jsonb; v_user text:=auth.uid();
BEGIN
 IF v_user IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 IF p_reason IS NULL OR p_reason NOT IN ('spam','harassment','privacy','other')
 THEN RETURN jsonb_build_object('error','invalid_report'); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.squad_messages WHERE id=p_message_id AND squad_id=p_squad_id
  AND kind='photo' AND sender_id<>v_user)
 THEN RETURN jsonb_build_object('error','not_found'); END IF;
 v_hidden:=public.hide_photo_message(p_squad_id,p_message_id);
 IF v_hidden ? 'error' THEN RETURN v_hidden; END IF;
 INSERT INTO public.photo_reports(reporter_id,squad_id,message_id,reason)
 VALUES(v_user,p_squad_id,p_message_id,p_reason) ON CONFLICT(reporter_id,message_id) DO NOTHING;
 RETURN jsonb_build_object('reported',true,'hidden',true);
END $$;
REVOKE ALL ON FUNCTION public.hide_photo_message(uuid,uuid),public.report_photo_message(uuid,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.hide_photo_message(uuid,uuid),public.report_photo_message(uuid,uuid,text) TO authenticated;

-- Preserve the original five-field projection except for this user's tombstone.
CREATE OR REPLACE FUNCTION public.timeline_entry_json(p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT to_jsonb(message)||jsonb_build_object(
  'author',jsonb_build_object('id',profile.id,'nickname',profile.nickname,'avatar_url',profile.avatar_url),
  'card_snapshot',to_jsonb(card),
  'photo',CASE WHEN photo.id IS NULL THEN NULL ELSE jsonb_build_object(
   'id',photo.id,'width',photo.width,'height',photo.height,'byte_length',photo.byte_length,'revoked',photo.state='revoked')
   ||CASE WHEN public.is_photo_hidden(message.squad_id,message.id,auth.uid()) THEN '{"hidden":true}'::jsonb ELSE '{}'::jsonb END END)
 FROM public.squad_messages message JOIN public.profiles profile ON profile.id=message.sender_id
 LEFT JOIN public.card_snapshots card ON card.id=message.card_id
 LEFT JOIN public.photo_media photo ON photo.id=message.photo_id
 WHERE message.id=p_message_id AND public.is_squad_member(message.squad_id)
  AND (message.plan_id IS NULL OR public.can_read_plan_discussion(message.plan_id,message.squad_id));
$$;

CREATE OR REPLACE FUNCTION public.get_squad_photo_head(p_squad_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('revision',(
  coalesce((SELECT revision FROM public.squad_photo_heads WHERE squad_id=p_squad_id),0)
  +coalesce((SELECT revision FROM public.photo_visibility_heads WHERE squad_id=p_squad_id AND user_id=auth.uid()),0))::text,
  'photo',(SELECT public.timeline_entry_json(m.id) FROM public.squad_messages m
   JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
   WHERE m.squad_id=p_squad_id AND m.kind='photo' AND m.plan_id IS NULL AND p.state='published'
    AND NOT public.is_photo_hidden(p_squad_id,m.id,auth.uid()) ORDER BY m.created_at DESC,m.id DESC LIMIT 1))
 WHERE auth.uid() IS NOT NULL AND public.is_squad_member(p_squad_id);
$$;

CREATE OR REPLACE FUNCTION public.page_squad_photos(p_squad_id uuid,p_before_created_at timestamptz DEFAULT NULL,
 p_before_id uuid DEFAULT NULL,p_limit int DEFAULT 50)
RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_squad_member(p_squad_id) THEN RETURN; END IF;
 IF (p_before_created_at IS NULL)<>(p_before_id IS NULL) THEN RAISE EXCEPTION 'invalid_cursor'; END IF;
 RETURN QUERY SELECT public.timeline_entry_json(page.id) FROM (
  SELECT m.id,m.created_at FROM public.squad_messages m JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
  WHERE m.squad_id=p_squad_id AND m.kind='photo' AND m.plan_id IS NULL AND p.state='published'
   AND NOT public.is_photo_hidden(p_squad_id,m.id,auth.uid())
   AND (p_before_id IS NULL OR (m.created_at,m.id)<(p_before_created_at,p_before_id))
  ORDER BY m.created_at DESC,m.id DESC LIMIT least(greatest(coalesce(p_limit,50),1),50)) page ORDER BY page.created_at,page.id;
END $$;
CREATE OR REPLACE FUNCTION public.get_squad_photo(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.timeline_entry_json(m.id) FROM public.squad_messages m JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
 WHERE auth.uid() IS NOT NULL AND public.is_squad_member(p_squad_id) AND m.id=p_message_id AND m.squad_id=p_squad_id
  AND m.kind='photo' AND m.plan_id IS NULL AND p.state='published' AND NOT public.is_photo_hidden(p_squad_id,m.id,auth.uid());
$$;
CREATE OR REPLACE FUNCTION public.authorize_photo_read(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_media public.photo_media%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_squad_member(p_squad_id) OR public.is_photo_hidden(p_squad_id,p_message_id,auth.uid())
 THEN RETURN jsonb_build_object('error','not_found'); END IF;
 SELECT p.* INTO v_media FROM public.photo_media p JOIN public.squad_messages m ON m.photo_id=p.id
 WHERE m.id=p_message_id AND m.squad_id=p_squad_id AND m.plan_id IS NULL AND p.state='published';
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
 RETURN jsonb_build_object('media_id',v_media.id,'object_key',
  (SELECT object_key FROM public.photo_upload_attempts WHERE id=v_media.active_attempt_id AND state='published'),
  'sha256',v_media.sha256,'width',v_media.width,'height',v_media.height,'byte_length',v_media.byte_length);
END $$;

-- Recheck hidden parents at reserve, after upload, and final certification.
CREATE OR REPLACE FUNCTION public.reserve_photo_upload(
 p_squad_id uuid,p_client_nonce uuid,p_source_sha256 text,p_reply_to_message_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
 v_user text := auth.uid(); v_media public.photo_media%ROWTYPE;
 v_attempt public.photo_upload_attempts%ROWTYPE; v_id uuid := gen_random_uuid();
BEGIN
 IF v_user IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 IF NOT public.is_squad_member(p_squad_id) THEN RETURN jsonb_build_object('error','not_member'); END IF;
 IF NOT EXISTS (SELECT 1 FROM public.squads WHERE id = p_squad_id AND status = 'active')
 THEN RETURN jsonb_build_object('error','squad_inactive'); END IF;
 IF p_client_nonce IS NULL OR p_source_sha256 IS NULL OR p_source_sha256 !~ '^[a-f0-9]{64}$'
 THEN RETURN jsonb_build_object('error','invalid_photo'); END IF;
 PERFORM 1 FROM public.profiles WHERE id = v_user FOR UPDATE;
 IF EXISTS (SELECT 1 FROM public.squad_messages WHERE squad_id = p_squad_id
  AND sender_id = v_user AND client_nonce = p_client_nonce AND kind <> 'photo')
 THEN RETURN jsonb_build_object('error','nonce_conflict'); END IF;
 SELECT * INTO v_media FROM public.photo_media WHERE squad_id = p_squad_id
  AND author_id = v_user AND client_nonce = p_client_nonce FOR UPDATE;
 IF FOUND THEN
  IF v_media.source_sha256 IS DISTINCT FROM p_source_sha256
   OR v_media.reply_to_message_id IS DISTINCT FROM p_reply_to_message_id
  THEN RETURN jsonb_build_object('error','nonce_conflict'); END IF;
  IF v_media.state = 'revoked' THEN RETURN jsonb_build_object('error','revoked'); END IF;
  IF v_media.state = 'published' THEN
   RETURN jsonb_build_object('published',public.published_photo_result(v_media.id)); END IF;
 END IF;
 IF p_reply_to_message_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM public.squad_messages m JOIN public.photo_media p ON p.id = m.photo_id
   WHERE m.id = p_reply_to_message_id AND m.squad_id = p_squad_id
    AND m.plan_id IS NULL AND p.state = 'published'
    AND NOT public.is_photo_hidden(p_squad_id,m.id,v_user))
 THEN RETURN jsonb_build_object('error','invalid_reply'); END IF;
 IF v_media.id IS NULL THEN
  IF (SELECT count(*) FROM public.photo_media WHERE author_id=v_user AND created_at>now()-interval '1 hour') >= 60
  THEN RETURN jsonb_build_object('error','rate_limited'); END IF;
  INSERT INTO public.photo_media(squad_id,author_id,client_nonce,source_sha256,reply_to_message_id)
  VALUES(p_squad_id,v_user,p_client_nonce,p_source_sha256,p_reply_to_message_id)
  RETURNING * INTO v_media;
 END IF;
 IF EXISTS (SELECT 1 FROM public.photo_upload_attempts WHERE media_id = v_media.id
  AND state = 'uploading' AND expires_at > now())
 THEN RETURN jsonb_build_object('error','upload_busy'); END IF;
 IF (SELECT count(*) FROM public.photo_upload_attempts a JOIN public.photo_media p ON p.id=a.media_id
  WHERE p.author_id=v_user AND a.created_at>now()-interval '1 hour') >= 120
 THEN RETURN jsonb_build_object('error','rate_limited'); END IF;
 INSERT INTO public.photo_upload_attempts(id,media_id,object_key)
 VALUES(v_id,v_media.id,v_media.id::text || '/' || v_id::text || '.jpg') RETURNING * INTO v_attempt;
 RETURN jsonb_build_object('media_id',v_media.id,'attempt_id',v_attempt.id,
  'object_key',v_attempt.object_key,'expires_at',v_attempt.expires_at);
END;
$$;
CREATE OR REPLACE FUNCTION public.authorize_photo_upload_attempt(p_media_id uuid,p_attempt_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.photo_media p JOIN public.photo_upload_attempts a ON a.media_id=p.id
   JOIN public.squads s ON s.id=p.squad_id
  WHERE p.id=p_media_id AND a.id=p_attempt_id AND p.author_id=auth.uid()
   AND p.state='preparing' AND a.state='uploading' AND a.expires_at>now()
   AND s.status='active' AND public.is_squad_member(p.squad_id)
   AND (p.reply_to_message_id IS NULL OR NOT public.is_photo_hidden(p.squad_id,p.reply_to_message_id,p.author_id)))
 THEN RETURN jsonb_build_object('error','not_member'); END IF;
 RETURN jsonb_build_object('authorized',true);
END;
$$;
CREATE OR REPLACE FUNCTION public.complete_photo_upload(
 p_media_id uuid,p_attempt_id uuid,p_sha256 text,p_width int,p_height int,p_byte_length int
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_media public.photo_media%ROWTYPE; v_attempt public.photo_upload_attempts%ROWTYPE;
BEGIN
 IF p_sha256 IS NULL OR p_sha256 !~ '^[a-f0-9]{64}$' OR p_width IS NULL OR p_height IS NULL
  OR p_byte_length IS NULL OR p_width NOT BETWEEN 1 AND 1600 OR p_height NOT BETWEEN 1 AND 1600
  OR p_byte_length NOT BETWEEN 1 AND 2097152
 THEN RETURN jsonb_build_object('error','invalid_photo'); END IF;
 -- Same order as reservation: author lock, then media and attempt.
 PERFORM 1 FROM public.profiles WHERE id = (SELECT author_id FROM public.photo_media WHERE id=p_media_id) FOR UPDATE;
 SELECT * INTO v_media FROM public.photo_media WHERE id=p_media_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
 IF v_media.state = 'revoked' THEN RETURN jsonb_build_object('error','revoked'); END IF;
 IF v_media.state = 'published' THEN
  IF v_media.active_attempt_id <> p_attempt_id THEN RETURN jsonb_build_object('error','nonce_conflict'); END IF;
  RETURN public.published_photo_result(v_media.id);
 END IF;
 PERFORM 1 FROM public.squad_members WHERE squad_id=v_media.squad_id AND user_id=v_media.author_id FOR KEY SHARE;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_member'); END IF;
 IF NOT EXISTS (SELECT 1 FROM public.squads WHERE id=v_media.squad_id AND status='active')
 THEN RETURN jsonb_build_object('error','squad_inactive'); END IF;
 SELECT * INTO v_attempt FROM public.photo_upload_attempts
  WHERE id=p_attempt_id AND media_id=p_media_id FOR UPDATE;
 IF NOT FOUND OR v_attempt.state <> 'uploading' OR v_attempt.expires_at <= now()
 THEN RETURN jsonb_build_object('error','upload_expired'); END IF;
 IF v_media.reply_to_message_id IS NOT NULL THEN
  PERFORM 1 FROM public.photo_media p JOIN public.squad_messages m ON m.photo_id=p.id
   WHERE m.id=v_media.reply_to_message_id AND m.squad_id=v_media.squad_id AND m.plan_id IS NULL
    AND p.state='published' AND NOT public.is_photo_hidden(v_media.squad_id,m.id,v_media.author_id) FOR SHARE OF p;
  IF NOT FOUND THEN RETURN jsonb_build_object('error','invalid_reply'); END IF;
 END IF;
 UPDATE public.photo_media SET state='published',active_attempt_id=p_attempt_id,sha256=p_sha256,
  width=p_width,height=p_height,byte_length=p_byte_length,published_at=now() WHERE id=p_media_id;
 UPDATE public.photo_upload_attempts SET state='published' WHERE id=p_attempt_id;
 INSERT INTO public.squad_messages(squad_id,sender_id,kind,photo_id,reply_to_message_id,client_nonce)
 VALUES(v_media.squad_id,v_media.author_id,'photo',p_media_id,v_media.reply_to_message_id,v_media.client_nonce);
 RETURN public.published_photo_result(p_media_id);
END;
$$;
END
$migration$;
