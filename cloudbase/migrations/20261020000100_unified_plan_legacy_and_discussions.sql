-- Preserve legacy fitness/travel plan records in the unified plan surface and
-- give each plan an independent text discussion within its owning squad.

ALTER TABLE public.squad_plans
  ADD COLUMN legacy_source text,
  ADD COLUMN legacy_id uuid,
  ADD COLUMN legacy_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD CONSTRAINT squad_plans_legacy_source_check
    CHECK (legacy_source IS NULL OR legacy_source IN ('workout_plan', 'travel_plan')),
  ADD CONSTRAINT squad_plans_legacy_pair_check
    CHECK ((legacy_source IS NULL) = (legacy_id IS NULL)),
  ADD CONSTRAINT squad_plans_legacy_identity_unique
    UNIQUE (legacy_source, legacy_id);

INSERT INTO public.squad_plans (
  squad_id, title, description, category, visibility, status,
  start_date, end_date, created_by, created_at, updated_at,
  legacy_source, legacy_id, legacy_data
)
SELECT
  plan.squad_id, plan.name, plan.description, 'fitness', 'squad', 'active',
  NULL, NULL, plan.created_by, plan.created_at, plan.created_at,
  'workout_plan', plan.id, to_jsonb(plan)
FROM public.workout_plans AS plan
ON CONFLICT (legacy_source, legacy_id) DO NOTHING;

INSERT INTO public.squad_plans (
  squad_id, title, description, category, visibility, status,
  start_date, end_date, created_by, created_at, updated_at,
  legacy_source, legacy_id, legacy_data
)
SELECT
  plan.squad_id, plan.title, plan.notes, 'travel', 'squad', 'active',
  plan.start_date, plan.end_date, plan.created_by, plan.created_at,
  plan.created_at, 'travel_plan', plan.id, to_jsonb(plan)
FROM public.travel_plans AS plan
ON CONFLICT (legacy_source, legacy_id) DO NOTHING;

CREATE FUNCTION public.sync_legacy_plan_to_unified()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_source text := TG_ARGV[0];
  v_title text;
  v_description text;
  v_category text;
  v_start_date date;
  v_end_date date;
BEGIN
  IF v_source = 'workout_plan' THEN
    v_title := NEW.name;
    v_description := NEW.description;
    v_category := 'fitness';
  ELSE
    v_title := NEW.title;
    v_description := NEW.notes;
    v_category := 'travel';
    v_start_date := NEW.start_date;
    v_end_date := NEW.end_date;
  END IF;

  INSERT INTO public.squad_plans (
    squad_id, title, description, category, visibility, status,
    start_date, end_date, created_by, created_at, updated_at,
    legacy_source, legacy_id, legacy_data
  ) VALUES (
    NEW.squad_id, v_title, v_description, v_category, 'squad', 'active',
    v_start_date, v_end_date, NEW.created_by, NEW.created_at, NEW.created_at,
    v_source, NEW.id, to_jsonb(NEW)
  )
  ON CONFLICT (legacy_source, legacy_id) DO UPDATE SET
    squad_id = EXCLUDED.squad_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    category = EXCLUDED.category,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    legacy_data = EXCLUDED.legacy_data,
    updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER workout_plans_sync_unified
  AFTER INSERT OR UPDATE ON public.workout_plans
  FOR EACH ROW EXECUTE FUNCTION public.sync_legacy_plan_to_unified('workout_plan');
CREATE TRIGGER travel_plans_sync_unified
  AFTER INSERT OR UPDATE ON public.travel_plans
  FOR EACH ROW EXECUTE FUNCTION public.sync_legacy_plan_to_unified('travel_plan');
REVOKE ALL ON FUNCTION public.sync_legacy_plan_to_unified()
  FROM PUBLIC, anon, authenticated;

CREATE INDEX squad_plans_legacy_lookup_idx
  ON public.squad_plans (legacy_source, legacy_id)
  WHERE legacy_source IS NOT NULL;

ALTER TABLE public.squad_messages
  ADD COLUMN plan_id uuid,
  ADD CONSTRAINT squad_messages_plan_squad_fk
    FOREIGN KEY (plan_id, squad_id)
    REFERENCES public.squad_plans (id, squad_id) ON DELETE CASCADE;

CREATE INDEX squad_messages_plan_timeline_idx
  ON public.squad_messages (squad_id, plan_id, created_at, id);

CREATE OR REPLACE FUNCTION public.can_read_plan_discussion(
  p_plan_id uuid,
  p_squad_id uuid
)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT public.is_squad_member(p_squad_id)
    AND EXISTS (
      SELECT 1 FROM public.squad_plans plan
      WHERE plan.id = p_plan_id
        AND plan.squad_id = p_squad_id
        AND (plan.visibility = 'squad' OR plan.created_by = auth.uid())
    );
$$;
REVOKE ALL ON FUNCTION public.can_read_plan_discussion(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_read_plan_discussion(uuid, uuid)
  TO authenticated;

DROP POLICY IF EXISTS squad_messages_select ON public.squad_messages;
CREATE POLICY squad_messages_select ON public.squad_messages
  FOR SELECT TO authenticated
  USING (
    public.is_squad_member(squad_id)
    AND (plan_id IS NULL OR public.can_read_plan_discussion(plan_id, squad_id))
  );

CREATE OR REPLACE FUNCTION public.enforce_same_thread_reply()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_reply_plan_id uuid;
BEGIN
  IF NEW.reply_to_message_id IS NULL THEN RETURN NEW; END IF;
  SELECT message.plan_id INTO v_reply_plan_id
  FROM public.squad_messages AS message
  WHERE message.id = NEW.reply_to_message_id
    AND message.squad_id = NEW.squad_id;
  IF NOT FOUND OR v_reply_plan_id IS DISTINCT FROM NEW.plan_id THEN
    RAISE EXCEPTION 'reply_must_be_in_same_conversation';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS squad_messages_same_thread_reply
  ON public.squad_messages;
CREATE TRIGGER squad_messages_same_thread_reply
  BEFORE INSERT OR UPDATE OF reply_to_message_id, plan_id, squad_id
  ON public.squad_messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_same_thread_reply();
REVOKE ALL ON FUNCTION public.enforce_same_thread_reply()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.timeline_entry_json(p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_jsonb(message) || jsonb_build_object(
    'author', jsonb_build_object(
      'id', profile.id,
      'nickname', profile.nickname,
      'avatar_url', profile.avatar_url
    ),
    'card_snapshot', to_jsonb(card)
  )
  FROM public.squad_messages AS message
  JOIN public.profiles AS profile ON profile.id = message.sender_id
  LEFT JOIN public.card_snapshots AS card ON card.id = message.card_id
  WHERE message.id = p_message_id
    AND public.is_squad_member(message.squad_id)
    AND (
      message.plan_id IS NULL
      OR public.can_read_plan_discussion(message.plan_id, message.squad_id)
    );
$$;

CREATE OR REPLACE FUNCTION public.page_squad_timeline(
  p_squad_id uuid,
  p_after_created_at timestamptz DEFAULT NULL,
  p_after_id uuid DEFAULT NULL,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_squad_member(p_squad_id) THEN RETURN; END IF;
  IF (p_after_created_at IS NULL) <> (p_after_id IS NULL)
     OR (p_before_created_at IS NULL) <> (p_before_id IS NULL)
     OR (p_after_id IS NOT NULL AND p_before_id IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_cursor';
  END IF;
  RETURN QUERY
  SELECT public.timeline_entry_json(page.id)
  FROM (
    SELECT message.id, message.created_at
    FROM public.squad_messages AS message
    WHERE message.squad_id = p_squad_id
      AND message.plan_id IS NULL
      AND (p_after_id IS NULL OR (message.created_at, message.id) >
           (p_after_created_at, p_after_id))
      AND (p_before_id IS NULL OR (message.created_at, message.id) <
           (p_before_created_at, p_before_id))
    ORDER BY
      CASE WHEN p_after_id IS NOT NULL THEN message.created_at END ASC,
      CASE WHEN p_after_id IS NOT NULL THEN message.id END ASC,
      CASE WHEN p_after_id IS NULL THEN message.created_at END DESC,
      CASE WHEN p_after_id IS NULL THEN message.id END DESC
    LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)
  ) AS page
  ORDER BY page.created_at, page.id;
END;
$$;

CREATE FUNCTION public.page_squad_plan_discussion(
  p_squad_id uuid,
  p_plan_id uuid,
  p_after_created_at timestamptz DEFAULT NULL,
  p_after_id uuid DEFAULT NULL,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.can_read_plan_discussion(p_plan_id, p_squad_id) THEN RETURN; END IF;
  IF (p_after_created_at IS NULL) <> (p_after_id IS NULL)
     OR (p_before_created_at IS NULL) <> (p_before_id IS NULL)
     OR (p_after_id IS NOT NULL AND p_before_id IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_cursor';
  END IF;
  RETURN QUERY
  SELECT public.timeline_entry_json(page.id)
  FROM (
    SELECT message.id, message.created_at
    FROM public.squad_messages AS message
    WHERE message.squad_id = p_squad_id
      AND message.plan_id = p_plan_id
      AND (p_after_id IS NULL OR (message.created_at, message.id) >
           (p_after_created_at, p_after_id))
      AND (p_before_id IS NULL OR (message.created_at, message.id) <
           (p_before_created_at, p_before_id))
    ORDER BY
      CASE WHEN p_after_id IS NOT NULL THEN message.created_at END ASC,
      CASE WHEN p_after_id IS NOT NULL THEN message.id END ASC,
      CASE WHEN p_after_id IS NULL THEN message.created_at END DESC,
      CASE WHEN p_after_id IS NULL THEN message.id END DESC
    LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)
  ) AS page
  ORDER BY page.created_at, page.id;
END;
$$;

CREATE FUNCTION public.send_squad_plan_message(
  p_squad_id uuid,
  p_plan_id uuid,
  p_body text,
  p_client_nonce uuid,
  p_reply_to_message_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user text := auth.uid();
  v_message public.squad_messages%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF NOT public.can_read_plan_discussion(p_plan_id, p_squad_id) THEN
    RETURN jsonb_build_object('error', 'not_allowed');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.squads
                 WHERE id = p_squad_id AND status = 'active') THEN
    RETURN jsonb_build_object('error', 'squad_inactive');
  END IF;
  IF p_client_nonce IS NULL OR p_body IS NULL
     OR length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RETURN jsonb_build_object('error', 'invalid_message');
  END IF;
  IF p_reply_to_message_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.squad_messages
    WHERE id = p_reply_to_message_id
      AND squad_id = p_squad_id
      AND plan_id = p_plan_id
  ) THEN
    RETURN jsonb_build_object('error', 'invalid_reply');
  END IF;
  PERFORM 1 FROM public.profiles WHERE id = v_user FOR UPDATE;
  SELECT * INTO v_message FROM public.squad_messages
  WHERE squad_id = p_squad_id
    AND sender_id = v_user
    AND client_nonce = p_client_nonce;
  IF FOUND THEN
    IF v_message.plan_id IS DISTINCT FROM p_plan_id
       OR v_message.kind <> 'text'
       OR v_message.body IS DISTINCT FROM p_body
       OR v_message.reply_to_message_id IS DISTINCT FROM p_reply_to_message_id THEN
      RETURN jsonb_build_object('error', 'nonce_conflict');
    END IF;
    RETURN public.timeline_entry_json(v_message.id);
  END IF;
  INSERT INTO public.squad_messages (
    squad_id, plan_id, sender_id, kind, body,
    reply_to_message_id, client_nonce
  ) VALUES (
    p_squad_id, p_plan_id, v_user, 'text', p_body,
    p_reply_to_message_id, p_client_nonce
  )
  RETURNING * INTO v_message;
  RETURN public.timeline_entry_json(v_message.id);
END;
$$;

REVOKE ALL ON FUNCTION public.page_squad_plan_discussion(
  uuid, uuid, timestamptz, uuid, timestamptz, uuid, int
), public.send_squad_plan_message(uuid, uuid, text, uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.page_squad_plan_discussion(
  uuid, uuid, timestamptz, uuid, timestamptz, uuid, int
), public.send_squad_plan_message(uuid, uuid, text, uuid, uuid)
  TO authenticated;
