-- Per-device leases prevent one APNs failure from resending already accepted
-- notifications to other devices. This table contains no message/card content.
CREATE TABLE public.message_push_deliveries (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  message_id uuid NOT NULL REFERENCES public.squad_messages(id) ON DELETE CASCADE,
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id uuid NOT NULL,
  provider text NOT NULL CHECK (provider IN ('apns', 'mipush')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'leased', 'sent', 'dead', 'cancelled')),
  attempt_count int NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  available_at timestamptz NOT NULL DEFAULT now(),
  lease_until timestamptz,
  lease_id uuid,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id, device_id, provider)
);
ALTER TABLE public.message_push_deliveries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.message_push_deliveries FROM PUBLIC, anon, authenticated;
CREATE INDEX message_push_deliveries_ready_idx
  ON public.message_push_deliveries(available_at, id)
  WHERE status IN ('pending', 'leased');

CREATE FUNCTION public.enqueue_push_deliveries()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.message_push_deliveries
    (message_id, squad_id, user_id, device_id, provider)
  SELECT NEW.message_id, NEW.squad_id, members.user_id,
         tokens.device_id, tokens.provider
  FROM public.squad_messages messages
  JOIN public.squad_members members ON members.squad_id = messages.squad_id
  JOIN public.device_push_tokens tokens
    ON tokens.user_id = members.user_id AND tokens.active
  WHERE messages.id = NEW.message_id AND members.user_id <> messages.sender_id;

  IF NOT FOUND THEN
    UPDATE public.message_outbox SET status = 'sent' WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enqueue_push_deliveries() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER message_outbox_push_deliveries
  AFTER INSERT ON public.message_outbox
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_push_deliveries();

-- Return a token only to the server's service role. Recheck both current
-- membership and token activity immediately before dispatch.
CREATE FUNCTION public.claim_push_deliveries(
  p_limit int DEFAULT 20, p_provider text DEFAULT 'apns'
)
RETURNS TABLE (
  delivery_id bigint,
  claim_id uuid,
  message_id uuid,
  squad_id uuid,
  provider text,
  token text
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'invalid_limit';
  END IF;
  IF p_provider IS NULL OR p_provider NOT IN ('apns', 'mipush') THEN
    RAISE EXCEPTION 'invalid_provider';
  END IF;

  UPDATE public.message_push_deliveries d SET status = 'cancelled',
      lease_id = NULL, lease_until = NULL
  WHERE d.status IN ('pending', 'leased')
    AND NOT EXISTS (
      SELECT 1 FROM public.squad_members m
      JOIN public.device_push_tokens t ON t.user_id = m.user_id
      WHERE m.squad_id = d.squad_id AND m.user_id = d.user_id
        AND t.device_id = d.device_id AND t.provider = d.provider AND t.active
    );

  UPDATE public.message_outbox o SET status =
    CASE WHEN EXISTS (SELECT 1 FROM public.message_push_deliveries d
      WHERE d.message_id = o.message_id AND d.status = 'dead')
    THEN 'dead' ELSE 'sent' END
  WHERE o.status = 'pending'
    AND NOT EXISTS (SELECT 1 FROM public.message_push_deliveries d
      WHERE d.message_id = o.message_id AND d.status IN ('pending', 'leased'));

  RETURN QUERY
  WITH ready AS (
    SELECT d.id, t.token AS current_token
    FROM public.message_push_deliveries d
    JOIN public.device_push_tokens t ON t.user_id = d.user_id
      AND t.device_id = d.device_id AND t.provider = d.provider AND t.active
    WHERE ((d.status = 'pending' AND d.available_at <= now())
        OR (d.status = 'leased' AND d.lease_until <= now()))
      AND d.provider = p_provider
    ORDER BY d.available_at, d.id
    FOR UPDATE OF d SKIP LOCKED
    LIMIT p_limit
  ), claimed AS (
    UPDATE public.message_push_deliveries d SET
      status = 'leased', attempt_count = d.attempt_count + 1,
      lease_id = gen_random_uuid(), lease_until = now() + interval '2 minutes'
    FROM ready r WHERE d.id = r.id
    RETURNING d.id, d.lease_id, d.message_id, d.squad_id, d.provider, r.current_token
  )
  SELECT c.id, c.lease_id, c.message_id, c.squad_id,
         c.provider, c.current_token FROM claimed c;
END;
$$;

CREATE FUNCTION public.complete_push_delivery(
  p_delivery_id bigint, p_claim_id uuid, p_outcome text,
  p_error_code text DEFAULT NULL, p_token text DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_delivery public.message_push_deliveries%ROWTYPE;
BEGIN
  IF p_outcome IS NULL OR p_outcome NOT IN ('sent', 'retry', 'dead')
     OR length(coalesce(p_error_code, '')) > 100 THEN
    RAISE EXCEPTION 'invalid_outcome';
  END IF;
  SELECT * INTO v_delivery FROM public.message_push_deliveries
    WHERE id = p_delivery_id AND status = 'leased' AND lease_id = p_claim_id
    FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;

  IF p_outcome = 'dead' AND p_error_code IN
      ('BadDeviceToken', 'Unregistered', 'InvalidRegId') THEN
    UPDATE public.device_push_tokens SET active = false, updated_at = now()
    WHERE user_id = v_delivery.user_id AND device_id = v_delivery.device_id
      AND provider = v_delivery.provider AND token = p_token;
  END IF;
  UPDATE public.message_push_deliveries SET
    status = CASE WHEN p_outcome = 'retry' AND v_delivery.attempt_count < 8
                  THEN 'pending'
                  WHEN p_outcome = 'retry' THEN 'dead'
                  ELSE p_outcome END,
    available_at = CASE WHEN p_outcome = 'retry'
      THEN now() + make_interval(secs => least(3600, power(2, least(v_delivery.attempt_count, 10))::int))
      ELSE available_at END,
    lease_id = NULL, lease_until = NULL, last_error_code = p_error_code
  WHERE id = p_delivery_id;

  IF NOT EXISTS (SELECT 1 FROM public.message_push_deliveries
      WHERE message_id = v_delivery.message_id AND status IN ('pending', 'leased')) THEN
    UPDATE public.message_outbox SET status =
      CASE WHEN EXISTS (SELECT 1 FROM public.message_push_deliveries
        WHERE message_id = v_delivery.message_id AND status = 'dead')
      THEN 'dead' ELSE 'sent' END
    WHERE message_id = v_delivery.message_id;
  END IF;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_push_deliveries(int,text),
  public.complete_push_delivery(bigint,uuid,text,text,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_push_deliveries(int,text),
  public.complete_push_delivery(bigint,uuid,text,text,text) TO service_role;
