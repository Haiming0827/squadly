-- CloudBase PG adaptation of 004_notification_outbox.sql; see backend_cloudbase migration inventory.
-- Notification storage only. Delivery workers and platform credentials are
-- server-side; no message body, health value, card payload or route enters it.

CREATE TABLE public.device_push_tokens (
  user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id uuid NOT NULL,
  provider text NOT NULL CHECK (provider IN ('apns', 'mipush')),
  token text NOT NULL CHECK (length(token) BETWEEN 8 AND 4096),
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id, provider),
  UNIQUE (provider, token)
);
ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY device_push_tokens_owner_select ON public.device_push_tokens
  FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE ALL ON public.device_push_tokens FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.device_push_tokens TO authenticated;

CREATE TABLE public.message_outbox (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message_id uuid NOT NULL UNIQUE REFERENCES public.squad_messages(id) ON DELETE CASCADE,
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'dead')),
  attempt_count int NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  available_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.message_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.message_outbox FROM PUBLIC, anon, authenticated;
CREATE INDEX message_outbox_pending_idx
  ON public.message_outbox(available_at, id) WHERE status = 'pending';

CREATE FUNCTION public.enqueue_squad_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.message_outbox(message_id, squad_id)
  VALUES (NEW.id, NEW.squad_id);
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enqueue_squad_message() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER squad_messages_outbox
  AFTER INSERT ON public.squad_messages
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_squad_message();

CREATE FUNCTION public.register_push_token(
  p_device_id uuid, p_provider text, p_token text
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF p_device_id IS NULL OR p_provider NOT IN ('apns', 'mipush')
     OR p_token IS NULL OR length(p_token) NOT BETWEEN 8 AND 4096 THEN
    RETURN jsonb_build_object('error', 'invalid_push_token');
  END IF;
  -- A platform token follows the physical device across account switches and
  -- reinstallations (which can create a new local device ID for one account).
  DELETE FROM public.device_push_tokens
    WHERE provider = p_provider AND token = p_token
      AND (user_id, device_id) IS DISTINCT FROM (auth.uid(), p_device_id);
  INSERT INTO public.device_push_tokens(user_id, device_id, provider, token)
  VALUES (auth.uid(), p_device_id, p_provider, p_token)
  ON CONFLICT (user_id, device_id, provider)
    DO UPDATE SET token = excluded.token, active = true, updated_at = now();
  RETURN jsonb_build_object('device_id', p_device_id, 'provider', p_provider);
END;
$$;

CREATE FUNCTION public.unregister_push_token(p_device_id uuid, p_provider text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501'; END IF;
  UPDATE public.device_push_tokens SET active = false, updated_at = now()
    WHERE user_id = auth.uid() AND device_id = p_device_id AND provider = p_provider;
END;
$$;

REVOKE ALL ON FUNCTION public.register_push_token(uuid,text,text),
  public.unregister_push_token(uuid,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_push_token(uuid,text,text),
  public.unregister_push_token(uuid,text) TO authenticated;
