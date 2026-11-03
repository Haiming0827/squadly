-- Coalesced privacy invalidations, not a second message/photo fact source.
-- Kept separate from message deliveries because former members need this hint.
DO $migration$
BEGIN
CREATE TABLE public.photo_sync_deliveries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 squad_id uuid NOT NULL, -- Intentionally survives Squad deletion.
 user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 device_id uuid NOT NULL,
 provider text NOT NULL DEFAULT 'apns' CHECK(provider='apns'),
 generation bigint NOT NULL DEFAULT 1 CHECK(generation>0),
 lease_generation bigint,
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','leased','sent','dead','cancelled')),
 attempt_count int NOT NULL DEFAULT 0 CHECK(attempt_count>=0),
 available_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '24 hours',
 updated_at timestamptz NOT NULL DEFAULT now(),
 lease_id uuid,
 lease_until timestamptz,
 last_error_code text,
 UNIQUE(squad_id,user_id,device_id,provider)
);
ALTER TABLE public.photo_sync_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.photo_sync_deliveries FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.photo_sync_deliveries TO service_role;
CREATE INDEX photo_sync_deliveries_ready_idx ON public.photo_sync_deliveries(available_at,id)
 WHERE status IN ('pending','leased');

CREATE FUNCTION public.enqueue_photo_sync(p_squad_id uuid,p_former_user text DEFAULT NULL)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.photo_sync_deliveries(squad_id,user_id,device_id,provider)
 SELECT p_squad_id,t.user_id,t.device_id,t.provider
 FROM public.device_push_tokens t
 WHERE t.active AND t.provider='apns' AND (t.user_id=p_former_user OR EXISTS(
  SELECT 1 FROM public.squad_members m WHERE m.squad_id=p_squad_id AND m.user_id=t.user_id))
 ORDER BY t.user_id,t.device_id
 ON CONFLICT(squad_id,user_id,device_id,provider) DO UPDATE SET
  generation=public.photo_sync_deliveries.generation+1,
  status=CASE WHEN public.photo_sync_deliveries.status='leased' THEN 'leased' ELSE 'pending' END,
  attempt_count=0,available_at=now(),expires_at=now()+interval '24 hours',updated_at=now(),
  last_error_code=NULL;
$$;

CREATE FUNCTION public.enqueue_photo_visibility_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.state='published' AND NEW.state='revoked' THEN
  PERFORM public.enqueue_photo_sync(OLD.squad_id);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER photo_revoked_sync AFTER UPDATE OF state ON public.photo_media
 FOR EACH ROW EXECUTE FUNCTION public.enqueue_photo_visibility_sync();

CREATE FUNCTION public.enqueue_deleted_photo_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.kind='photo' THEN PERFORM public.enqueue_photo_sync(OLD.squad_id); END IF;
 RETURN OLD;
END $$;
CREATE TRIGGER photo_message_deleted_sync AFTER DELETE ON public.squad_messages
 FOR EACH ROW EXECUTE FUNCTION public.enqueue_deleted_photo_sync();

CREATE FUNCTION public.enqueue_member_photo_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF (OLD.squad_id,OLD.user_id) IS NOT DISTINCT FROM (NEW.squad_id,NEW.user_id) THEN RETURN NEW; END IF;
  PERFORM public.enqueue_photo_sync(NEW.squad_id);
 END IF;
 PERFORM public.enqueue_photo_sync(OLD.squad_id,OLD.user_id);
 RETURN NULL;
END $$;
CREATE TRIGGER member_removed_photo_sync AFTER DELETE OR UPDATE ON public.squad_members
 FOR EACH ROW EXECUTE FUNCTION public.enqueue_member_photo_sync();

CREATE FUNCTION public.enqueue_squad_photo_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  PERFORM public.enqueue_photo_sync(OLD.id);
  RETURN OLD;
 END IF;
 IF OLD.status='active' AND NEW.status IS DISTINCT FROM OLD.status THEN
  PERFORM public.enqueue_photo_sync(OLD.id);
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER squad_inactive_photo_sync AFTER UPDATE OF status ON public.squads
 FOR EACH ROW EXECUTE FUNCTION public.enqueue_squad_photo_sync();
CREATE TRIGGER squad_deleted_photo_sync BEFORE DELETE ON public.squads
 FOR EACH ROW EXECUTE FUNCTION public.enqueue_squad_photo_sync();

CREATE FUNCTION public.claim_photo_sync(p_limit int DEFAULT 10)
RETURNS TABLE(delivery_id uuid,claim_id uuid,provider text,token text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
 DELETE FROM public.photo_sync_deliveries d
 WHERE d.status IN ('sent','dead','cancelled') AND d.updated_at<now()-interval '7 days';
 UPDATE public.photo_sync_deliveries d SET status='cancelled',lease_id=NULL,lease_until=NULL,
  lease_generation=NULL,updated_at=now()
 WHERE d.status IN ('pending','leased') AND (d.expires_at<=now() OR NOT EXISTS(
  SELECT 1 FROM public.device_push_tokens t WHERE t.user_id=d.user_id
   AND t.device_id=d.device_id AND t.provider=d.provider AND t.active));
 RETURN QUERY WITH ready AS (
  SELECT d.id,t.token AS current_token FROM public.photo_sync_deliveries d
  JOIN public.device_push_tokens t ON t.user_id=d.user_id AND t.device_id=d.device_id
   AND t.provider=d.provider AND t.active
  WHERE d.expires_at>now() AND ((d.status='pending' AND d.available_at<=now())
   OR (d.status='leased' AND d.lease_until<=now()))
  ORDER BY d.available_at,d.id FOR UPDATE OF d SKIP LOCKED LIMIT p_limit
 ), claimed AS (
  UPDATE public.photo_sync_deliveries d SET status='leased',attempt_count=d.attempt_count+1,
   lease_id=gen_random_uuid(),lease_until=now()+interval '2 minutes',lease_generation=d.generation
  FROM ready r WHERE d.id=r.id RETURNING d.id,d.lease_id,d.provider,r.current_token
 ) SELECT c.id,c.lease_id,c.provider,c.current_token FROM claimed c;
END $$;

CREATE FUNCTION public.complete_photo_sync(p_delivery_id uuid,p_claim_id uuid,p_outcome text,
 p_error_code text DEFAULT NULL,p_token text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v public.photo_sync_deliveries%ROWTYPE;
BEGIN
 IF p_outcome IS NULL OR p_outcome NOT IN ('sent','retry','dead')
  OR length(coalesce(p_error_code,''))>100 THEN RAISE EXCEPTION 'invalid_outcome'; END IF;
 SELECT * INTO v FROM public.photo_sync_deliveries WHERE id=p_delivery_id
  AND status='leased' AND lease_id=p_claim_id FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF p_outcome='dead' AND p_error_code IN ('BadDeviceToken','Unregistered','DeviceTokenNotForTopic') THEN
  UPDATE public.device_push_tokens SET active=false,updated_at=now()
  WHERE user_id=v.user_id AND device_id=v.device_id AND provider=v.provider AND token=p_token;
 END IF;
 UPDATE public.photo_sync_deliveries SET
  status=CASE WHEN v.expires_at<=now() THEN 'cancelled'
   WHEN v.generation<>v.lease_generation THEN 'pending'
   WHEN p_outcome='retry' AND v.attempt_count<8 THEN 'pending'
   WHEN p_outcome='retry' THEN 'dead' ELSE p_outcome END,
  available_at=CASE WHEN v.generation<>v.lease_generation THEN now()
   WHEN p_outcome='retry' THEN now()+make_interval(secs=>least(3600,power(2,least(v.attempt_count,10))::int))
   ELSE available_at END,
  lease_id=NULL,lease_until=NULL,lease_generation=NULL,last_error_code=p_error_code,updated_at=now()
 WHERE id=p_delivery_id;
 RETURN true;
END $$;

CREATE FUNCTION public.claim_push_work(p_limit int DEFAULT 20,p_provider text DEFAULT 'apns')
RETURNS TABLE(lease_kind text,delivery_id text,claim_id uuid,provider text,token text,message_kind text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_privacy_count int:=0;
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'invalid_limit'; END IF;
 IF p_provider IS NULL OR p_provider NOT IN ('apns','mipush') THEN RAISE EXCEPTION 'invalid_provider'; END IF;
 IF p_provider='apns' THEN
  RETURN QUERY SELECT 'photo_sync'::text,c.delivery_id::text,c.claim_id,c.provider,c.token,'photo_sync'::text
   FROM public.claim_photo_sync(greatest(1,p_limit/2)) c;
  GET DIAGNOSTICS v_privacy_count=ROW_COUNT;
 END IF;
 IF v_privacy_count<p_limit THEN
  RETURN QUERY SELECT 'message'::text,c.delivery_id::text,c.claim_id,c.provider,c.token,c.message_kind
   FROM public.claim_push_deliveries_v2(p_limit-v_privacy_count,p_provider) c;
 END IF;
END $$;

CREATE FUNCTION public.complete_push_work(p_lease_kind text,p_delivery_id text,p_claim_id uuid,
 p_outcome text,p_error_code text DEFAULT NULL,p_token text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_lease_kind='photo_sync' THEN
  RETURN public.complete_photo_sync(p_delivery_id::uuid,p_claim_id,p_outcome,p_error_code,p_token);
 ELSIF p_lease_kind='message' AND p_delivery_id ~ '^[1-9][0-9]{0,18}$' THEN
  RETURN public.complete_push_delivery(p_delivery_id::bigint,p_claim_id,p_outcome,p_error_code,p_token);
 END IF;
 RAISE EXCEPTION 'invalid_lease';
END $$;

REVOKE ALL ON FUNCTION public.enqueue_photo_sync(uuid,text),public.enqueue_photo_visibility_sync(),
 public.enqueue_deleted_photo_sync(),public.enqueue_member_photo_sync(),public.enqueue_squad_photo_sync(),
 public.claim_photo_sync(int),public.complete_photo_sync(uuid,uuid,text,text,text),
 public.claim_push_work(int,text),public.complete_push_work(text,text,uuid,text,text,text)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_photo_sync(int),public.complete_photo_sync(uuid,uuid,text,text,text),
 public.claim_push_work(int,text),public.complete_push_work(text,text,uuid,text,text,text) TO service_role;
END
$migration$;
