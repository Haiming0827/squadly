-- One monotonic cursor per current membership and conversation thread.
-- Only message authors receive per-message projections; raw positions stay
-- private to their owner and no message content is returned by these RPCs.
ALTER TABLE public.squad_members
  ADD CONSTRAINT squad_members_id_squad_unique UNIQUE (id, squad_id);

CREATE TABLE public.conversation_read_cursors (
  membership_id uuid NOT NULL,
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  plan_id uuid,
  thread_key text GENERATED ALWAYS AS (coalesce(plan_id::text, 'general')) STORED,
  read_message_created_at timestamptz NOT NULL,
  read_message_id uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (membership_id, thread_key),
  FOREIGN KEY (membership_id, squad_id)
    REFERENCES public.squad_members(id, squad_id) ON DELETE CASCADE,
  FOREIGN KEY (plan_id, squad_id)
    REFERENCES public.squad_plans(id, squad_id) ON DELETE CASCADE
);
-- The message position deliberately has no FK: deleting a message must not
-- move a member's already acknowledged boundary backwards.
ALTER TABLE public.conversation_read_cursors ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.conversation_read_cursors FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.conversation_read_cursors TO authenticated;
CREATE POLICY conversation_read_cursors_owner_select
  ON public.conversation_read_cursors FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.squad_members m
      WHERE m.id = membership_id AND m.squad_id = conversation_read_cursors.squad_id
        AND m.user_id = auth.uid()
    )
    AND (plan_id IS NULL OR public.can_read_plan_discussion(plan_id, squad_id))
  );

CREATE FUNCTION public.advance_conversation_read_cursor(
  p_squad_id uuid, p_message_id uuid, p_plan_id uuid DEFAULT NULL
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_membership_id uuid;
  v_created_at timestamptz;
BEGIN
  SELECT m.id INTO v_membership_id FROM public.squad_members m
  WHERE m.squad_id = p_squad_id AND m.user_id = auth.uid()
  FOR KEY SHARE;
  IF v_membership_id IS NULL OR
      (p_plan_id IS NOT NULL AND NOT public.can_read_plan_discussion(p_plan_id, p_squad_id)) THEN
    RAISE EXCEPTION 'conversation_read_forbidden' USING ERRCODE = '42501';
  END IF;
  SELECT msg.created_at INTO v_created_at FROM public.squad_messages msg
  WHERE msg.id = p_message_id AND msg.squad_id = p_squad_id
    AND msg.plan_id IS NOT DISTINCT FROM p_plan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'conversation_read_forbidden' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.conversation_read_cursors (
    membership_id, squad_id, plan_id, read_message_created_at, read_message_id
  ) VALUES (v_membership_id, p_squad_id, p_plan_id, v_created_at, p_message_id)
  ON CONFLICT (membership_id, thread_key) DO UPDATE SET
    read_message_created_at = EXCLUDED.read_message_created_at,
    read_message_id = EXCLUDED.read_message_id,
    updated_at = now()
  WHERE (conversation_read_cursors.read_message_created_at, conversation_read_cursors.read_message_id)
      < (EXCLUDED.read_message_created_at, EXCLUDED.read_message_id);
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.advance_conversation_read_cursor(uuid, uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.advance_conversation_read_cursor(uuid, uuid, uuid)
  TO authenticated;

CREATE FUNCTION public.get_message_read_receipts(
  p_squad_id uuid, p_message_ids uuid[], p_plan_id uuid DEFAULT NULL
) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT public.is_squad_member(p_squad_id) OR
      (p_plan_id IS NOT NULL AND NOT public.can_read_plan_discussion(p_plan_id, p_squad_id)) THEN
    RAISE EXCEPTION 'conversation_read_forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_message_ids IS NULL OR cardinality(p_message_ids) NOT BETWEEN 1 AND 50
      OR array_position(p_message_ids, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'invalid_read_batch' USING ERRCODE = '22023';
  END IF;
  SELECT count(DISTINCT id) INTO v_count FROM unnest(p_message_ids) AS id;
  IF v_count <> cardinality(p_message_ids) THEN
    RAISE EXCEPTION 'invalid_read_batch' USING ERRCODE = '22023';
  END IF;
  SELECT count(*) INTO v_count FROM public.squad_messages msg
  WHERE msg.id = ANY(p_message_ids) AND msg.squad_id = p_squad_id
    AND msg.plan_id IS NOT DISTINCT FROM p_plan_id AND msg.sender_id = auth.uid();
  IF v_count <> cardinality(p_message_ids) THEN
    RAISE EXCEPTION 'conversation_read_forbidden' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT jsonb_build_object('message_id', msg.id, 'members', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'membership_id', m.id,
      'user_id', m.user_id,
      'nickname', p.nickname,
      'status', CASE
        WHEN m.joined_at > msg.created_at THEN 'not_applicable'
        WHEN (c.read_message_created_at, c.read_message_id) >= (msg.created_at, msg.id) THEN 'read'
        ELSE 'unread' END
    ) ORDER BY m.joined_at, m.id), '[]'::jsonb)
    FROM public.squad_members m
    JOIN public.profiles p ON p.id = m.user_id
    LEFT JOIN public.conversation_read_cursors c
      ON c.membership_id = m.id AND c.squad_id = p_squad_id
      AND c.plan_id IS NOT DISTINCT FROM p_plan_id
    WHERE m.squad_id = p_squad_id AND m.user_id <> msg.sender_id
      AND (p_plan_id IS NULL OR EXISTS (
        SELECT 1 FROM public.squad_plans plan
        WHERE plan.id = p_plan_id AND plan.squad_id = p_squad_id AND plan.visibility = 'squad'
      ))
  ))
  FROM unnest(p_message_ids) WITH ORDINALITY requested(id, ordinal)
  JOIN public.squad_messages msg ON msg.id = requested.id
  ORDER BY requested.ordinal;
END;
$$;
REVOKE ALL ON FUNCTION public.get_message_read_receipts(uuid, uuid[], uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_message_read_receipts(uuid, uuid[], uuid)
  TO authenticated;
