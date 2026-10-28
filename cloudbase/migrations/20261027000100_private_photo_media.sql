-- Ordinary photos are separate from local-only activity/card PNGs.
-- Byte access is exclusively through the authenticated photos worker. Never
-- remove storage rows with SQL: the cleanup worker uses the Storage API.
CREATE TABLE public.photo_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id),
  author_id text NOT NULL REFERENCES public.profiles(id),
  client_nonce uuid NOT NULL,
  source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[a-f0-9]{64}$'),
  reply_to_message_id uuid,
  state text NOT NULL DEFAULT 'preparing' CHECK (state IN ('preparing','published','revoked')),
  active_attempt_id uuid,
  sha256 text CHECK (sha256 ~ '^[a-f0-9]{64}$'),
  width int CHECK (width BETWEEN 1 AND 1600),
  height int CHECK (height BETWEEN 1 AND 1600),
  byte_length int CHECK (byte_length BETWEEN 1 AND 2097152),
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  revoked_at timestamptz,
  UNIQUE (id, squad_id),
  UNIQUE (squad_id, author_id, client_nonce),
  FOREIGN KEY (reply_to_message_id, squad_id) REFERENCES public.squad_messages(id, squad_id),
  CHECK (state = 'preparing' OR (active_attempt_id IS NOT NULL AND sha256 IS NOT NULL
    AND width IS NOT NULL AND height IS NOT NULL AND byte_length IS NOT NULL
    AND published_at IS NOT NULL)),
  CHECK ((state = 'revoked') = (revoked_at IS NOT NULL))
);
CREATE TABLE public.photo_upload_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id uuid NOT NULL REFERENCES public.photo_media(id),
  object_key text NOT NULL UNIQUE,
  state text NOT NULL DEFAULT 'uploading' CHECK (state IN ('uploading','published','deleting','deleted')),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '10 minutes',
  cleanup_claim_id uuid,
  cleanup_claimed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, media_id),
  CHECK (object_key = media_id::text || '/' || id::text || '.jpg')
);
ALTER TABLE public.photo_media ADD FOREIGN KEY (active_attempt_id, id)
  REFERENCES public.photo_upload_attempts(id, media_id);
ALTER TABLE public.photo_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.photo_upload_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.photo_media, public.photo_upload_attempts FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.photo_media, public.photo_upload_attempts TO service_role;
CREATE INDEX photo_media_author_created_idx ON public.photo_media(author_id,created_at);

-- CloudBase initializes these storage tables; fail if the target is not PG
-- Storage, rather than silently installing metadata without byte protection.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('squadly-photos','squadly-photos',false,2097152,ARRAY['image/jpeg'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/jpeg'];
-- A restrictive policy also closes access in environments with a broad older
-- permissive policy. Other buckets retain their existing rules.
CREATE POLICY squadly_photos_gateway_only ON storage.objects AS RESTRICTIVE
  FOR ALL TO anon, authenticated
  USING (bucket_id <> 'squadly-photos') WITH CHECK (bucket_id <> 'squadly-photos');
CREATE POLICY squadly_photos_bucket_gateway_only ON storage.buckets AS RESTRICTIVE
  FOR ALL TO anon, authenticated
  USING (id <> 'squadly-photos') WITH CHECK (id <> 'squadly-photos');

ALTER TABLE public.squad_messages DROP CONSTRAINT squad_messages_kind_check;
ALTER TABLE public.squad_messages DROP CONSTRAINT squad_messages_check;
ALTER TABLE public.squad_messages ADD COLUMN photo_id uuid;
ALTER TABLE public.squad_messages ADD CONSTRAINT squad_messages_kind_check
  CHECK (kind IN ('text','card','photo'));
ALTER TABLE public.squad_messages ADD CONSTRAINT squad_messages_check CHECK (
  (kind = 'text' AND body IS NOT NULL AND card_id IS NULL AND photo_id IS NULL)
  OR (kind = 'card' AND body IS NULL AND card_id IS NOT NULL AND photo_id IS NULL)
  OR (kind = 'photo' AND body IS NULL AND card_id IS NULL AND photo_id IS NOT NULL AND plan_id IS NULL)
);
ALTER TABLE public.squad_messages ADD UNIQUE (photo_id);
ALTER TABLE public.squad_messages ADD FOREIGN KEY (photo_id,squad_id)
  REFERENCES public.photo_media(id,squad_id);

CREATE OR REPLACE FUNCTION public.timeline_entry_json(p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_jsonb(message) || jsonb_build_object(
    'author', jsonb_build_object('id',profile.id,'nickname',profile.nickname,'avatar_url',profile.avatar_url),
    'card_snapshot', to_jsonb(card),
    'photo', CASE WHEN photo.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id',photo.id,'width',photo.width,'height',photo.height,'byte_length',photo.byte_length,
      'revoked',photo.state = 'revoked') END
  )
  FROM public.squad_messages AS message
  JOIN public.profiles AS profile ON profile.id = message.sender_id
  LEFT JOIN public.card_snapshots AS card ON card.id = message.card_id
  LEFT JOIN public.photo_media AS photo ON photo.id = message.photo_id
  WHERE message.id = p_message_id AND public.is_squad_member(message.squad_id)
    AND (message.plan_id IS NULL OR public.can_read_plan_discussion(message.plan_id,message.squad_id));
$$;

-- Internal safe response: no object path, digest or source metadata.
CREATE FUNCTION public.published_photo_result(p_media_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT jsonb_build_object('message_id',m.id,'media_id',p.id,'squad_id',p.squad_id,
  'author_id',p.author_id,'client_nonce',p.client_nonce,'published_at',p.published_at,
  'reply_to_message_id',p.reply_to_message_id)
 FROM public.photo_media p JOIN public.squad_messages m ON m.photo_id = p.id
 WHERE p.id = p_media_id AND p.state = 'published';
$$;
REVOKE ALL ON FUNCTION public.published_photo_result(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.reserve_photo_upload(
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
    AND m.plan_id IS NULL AND p.state = 'published')
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

-- Revalidate the caller JWT after decode/upload, before service certification.
CREATE FUNCTION public.authorize_photo_upload_attempt(p_media_id uuid,p_attempt_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS (
  SELECT 1 FROM public.photo_media p JOIN public.photo_upload_attempts a ON a.media_id=p.id
   JOIN public.squads s ON s.id=p.squad_id
  WHERE p.id=p_media_id AND a.id=p_attempt_id AND p.author_id=auth.uid()
   AND p.state='preparing' AND a.state='uploading' AND a.expires_at>now()
   AND s.status='active' AND public.is_squad_member(p.squad_id))
 THEN RETURN jsonb_build_object('error','not_member'); END IF;
 RETURN jsonb_build_object('authorized',true);
END;
$$;

CREATE FUNCTION public.complete_photo_upload(
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
    AND p.state='published' FOR SHARE OF p;
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

CREATE FUNCTION public.authorize_photo_read(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_media public.photo_media%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_squad_member(p_squad_id)
 THEN RETURN jsonb_build_object('error','not_found'); END IF;
 SELECT p.* INTO v_media FROM public.photo_media p JOIN public.squad_messages m ON m.photo_id=p.id
  WHERE m.id=p_message_id AND m.squad_id=p_squad_id AND m.plan_id IS NULL AND p.state='published';
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
 RETURN jsonb_build_object('media_id',v_media.id,'object_key',
  (SELECT object_key FROM public.photo_upload_attempts WHERE id=v_media.active_attempt_id AND state='published'),
  'sha256',v_media.sha256,'width',v_media.width,'height',v_media.height,'byte_length',v_media.byte_length);
END;
$$;

CREATE FUNCTION public.revoke_photo_message(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_squad_member(p_squad_id)
 THEN RETURN jsonb_build_object('error','not_found'); END IF;
 SELECT p.id INTO v_id FROM public.photo_media p JOIN public.squad_messages m ON m.photo_id=p.id
  WHERE m.id=p_message_id AND m.squad_id=p_squad_id AND p.author_id=auth.uid() FOR UPDATE OF p;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','not_found'); END IF;
 UPDATE public.photo_media SET state='revoked',revoked_at=coalesce(revoked_at,now()) WHERE id=v_id;
 RETURN jsonb_build_object('revoked',true);
END;
$$;

CREATE FUNCTION public.claim_photo_cleanup(p_limit int DEFAULT 20)
RETURNS SETOF jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
 RETURN QUERY WITH candidates AS (
  SELECT a.id FROM public.photo_upload_attempts a JOIN public.photo_media p ON p.id=a.media_id
  WHERE (a.state='uploading' AND a.expires_at < now())
   OR (a.state='published' AND p.state='revoked')
   OR (a.state='deleting' AND a.cleanup_claimed_at < now()-interval '5 minutes')
  ORDER BY a.created_at,a.id FOR UPDATE OF a SKIP LOCKED LIMIT p_limit
 ), claimed AS (
  UPDATE public.photo_upload_attempts a SET state='deleting',cleanup_claim_id=gen_random_uuid(),cleanup_claimed_at=now()
  FROM candidates c WHERE a.id=c.id RETURNING a.*
 ) SELECT jsonb_build_object('attempt_id',id,'object_key',object_key,'claim_id',cleanup_claim_id) FROM claimed;
END;
$$;
CREATE FUNCTION public.complete_photo_cleanup(p_attempt_id uuid,p_claim_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 UPDATE public.photo_upload_attempts SET state='deleted'
 WHERE id=p_attempt_id AND state='deleting' AND cleanup_claim_id=p_claim_id;
 RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_photo_upload(uuid,uuid,text,uuid),
 public.authorize_photo_upload_attempt(uuid,uuid),
 public.complete_photo_upload(uuid,uuid,text,int,int,int),public.authorize_photo_read(uuid,uuid),
 public.revoke_photo_message(uuid,uuid),public.claim_photo_cleanup(int),public.complete_photo_cleanup(uuid,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_photo_upload(uuid,uuid,text,uuid),
 public.authorize_photo_upload_attempt(uuid,uuid),
 public.authorize_photo_read(uuid,uuid),public.revoke_photo_message(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_photo_upload(uuid,uuid,text,int,int,int),
 public.claim_photo_cleanup(int),public.complete_photo_cleanup(uuid,uuid) TO service_role;
