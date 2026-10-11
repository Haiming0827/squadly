-- Registration foundation: forward-only privacy and account repair.
-- Apply after 001 and 002. Existing profile contact columns are retained for
-- old rows, but API roles cannot read or write them; auth.users is canonical.

CREATE OR REPLACE FUNCTION public.is_squad_member(p_squad_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_squad_captain(p_squad_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid() AND role = 'captain'
  );
$$;

CREATE FUNCTION public.can_view_profile(p_profile_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT p_profile_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.squad_members mine
    JOIN public.squad_members peer ON peer.squad_id = mine.squad_id
    WHERE mine.user_id = auth.uid() AND peer.user_id = p_profile_id
  );
$$;

REVOKE ALL ON FUNCTION public.is_squad_member(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_squad_captain(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.can_view_profile(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_squad_member(uuid), public.is_squad_captain(uuid)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_profile(uuid) TO authenticated;

DROP POLICY IF EXISTS profiles_select ON public.profiles;
DROP POLICY IF EXISTS profiles_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_select ON public.profiles FOR SELECT TO authenticated
  USING (public.can_view_profile(id));
CREATE POLICY profiles_update ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

REVOKE ALL ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT (id, nickname, avatar_url, created_at, updated_at)
  ON public.profiles TO authenticated;
GRANT UPDATE (nickname, avatar_url) ON public.profiles TO authenticated;

CREATE FUNCTION public.provision_profile_from_auth()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.profiles (id, nickname)
  VALUES (
    NEW.id,
    left(coalesce(nullif(btrim(NEW.raw_user_meta_data ->> 'nickname'), ''), '新队员'), 60)
  ) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.provision_profile_from_auth() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER on_auth_user_created_squadly
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.provision_profile_from_auth();

INSERT INTO public.profiles (id, nickname)
SELECT id,
       left(coalesce(nullif(btrim(raw_user_meta_data ->> 'nickname'), ''), '新队员'), 60)
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- Health snapshots in 002 contain raw weight and were team-readable. Keep
-- historical rows for controlled retention/migration, but close the API path.
DROP POLICY IF EXISTS health_snapshots_select ON public.health_snapshots;
DROP POLICY IF EXISTS health_snapshots_insert ON public.health_snapshots;
DROP POLICY IF EXISTS health_snapshots_update ON public.health_snapshots;
REVOKE ALL ON public.health_snapshots FROM PUBLIC, anon, authenticated;

-- Invitation-only membership. The old plaintext invite_code on squads is no
-- longer a credential; existing squads must issue fresh controlled invites.
ALTER TABLE public.squads DROP COLUMN invite_code;
ALTER TABLE public.squads ADD COLUMN status text NOT NULL DEFAULT 'pending'
  CHECK (status IN ('pending', 'active'));
UPDATE public.squads s SET status = 'active'
WHERE (SELECT count(*) FROM public.squad_members m WHERE m.squad_id = s.id) >= 2;

DROP POLICY IF EXISTS squads_select ON public.squads;
DROP POLICY IF EXISTS squads_insert ON public.squads;
DROP POLICY IF EXISTS squads_update ON public.squads;
DROP POLICY IF EXISTS squads_delete ON public.squads;
CREATE POLICY squads_select ON public.squads FOR SELECT TO authenticated
  USING (public.is_squad_member(id));

DROP POLICY IF EXISTS squad_members_select ON public.squad_members;
DROP POLICY IF EXISTS squad_members_insert ON public.squad_members;
DROP POLICY IF EXISTS squad_members_update ON public.squad_members;
DROP POLICY IF EXISTS squad_members_delete ON public.squad_members;
CREATE POLICY squad_members_select ON public.squad_members FOR SELECT TO authenticated
  USING (public.is_squad_member(squad_id));

REVOKE ALL ON public.squads, public.squad_members FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.squads, public.squad_members TO authenticated;
CREATE UNIQUE INDEX squad_one_captain ON public.squad_members (squad_id)
  WHERE role = 'captain';

DROP FUNCTION IF EXISTS public.generate_invite_code();
CREATE OR REPLACE FUNCTION public.get_squad_member_count(p_squad_id uuid)
RETURNS int LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT CASE WHEN public.is_squad_member(p_squad_id)
    THEN (SELECT count(*)::int FROM public.squad_members WHERE squad_id = p_squad_id)
    ELSE 0 END;
$$;
REVOKE ALL ON FUNCTION public.get_squad_member_count(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_squad_member_count(uuid) TO authenticated;

CREATE TABLE public.squad_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  issued_by uuid NOT NULL REFERENCES public.profiles(id),
  code_hash bytea NOT NULL UNIQUE,
  link_hash bytea NOT NULL UNIQUE,
  max_uses int NOT NULL DEFAULT 1 CHECK (max_uses BETWEEN 1 AND 9),
  used_count int NOT NULL DEFAULT 0 CHECK (used_count >= 0 AND used_count <= max_uses),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.squad_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.squad_invitations FROM PUBLIC, anon, authenticated;
CREATE INDEX squad_invitations_squad_id_idx ON public.squad_invitations(squad_id);

CREATE TABLE public.squad_invitation_attempts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.squad_invitation_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.squad_invitation_attempts FROM PUBLIC, anon, authenticated;
CREATE INDEX squad_invitation_attempts_recent_idx
  ON public.squad_invitation_attempts(user_id, attempted_at DESC);

CREATE FUNCTION public.create_squad(p_name text, p_description text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user uuid := auth.uid();
  v_squad public.squads%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 1 AND 60
     OR length(coalesce(p_description, '')) > 500 THEN
    RETURN jsonb_build_object('error', 'invalid_squad');
  END IF;
  INSERT INTO public.squads (name, description, created_by, status)
  VALUES (btrim(p_name), nullif(btrim(p_description), ''), v_user, 'pending')
  RETURNING * INTO v_squad;
  INSERT INTO public.squad_members(squad_id, user_id, role)
  VALUES (v_squad.id, v_user, 'captain');
  RETURN to_jsonb(v_squad);
END;
$$;

CREATE FUNCTION public.issue_invitation(p_squad_id uuid, p_max_uses int DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_squad public.squads%ROWTYPE;
  v_code text;
  v_token text;
  v_invitation public.squad_invitations%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF p_max_uses IS NULL OR p_max_uses NOT BETWEEN 1 AND 9 THEN
    RETURN jsonb_build_object('error', 'invalid_uses');
  END IF;
  SELECT * INTO v_squad FROM public.squads WHERE id = p_squad_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'not_found'); END IF;
  IF NOT public.is_squad_captain(p_squad_id) THEN
    RETURN jsonb_build_object('error', 'not_captain');
  END IF;
  LOOP
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    v_token := replace(gen_random_uuid()::text, '-', '') ||
               replace(gen_random_uuid()::text, '-', '');
    INSERT INTO public.squad_invitations
      (squad_id, issued_by, code_hash, link_hash, max_uses, expires_at)
    VALUES (p_squad_id, auth.uid(), sha256(convert_to(v_code, 'UTF8')),
            sha256(convert_to(v_token, 'UTF8')), p_max_uses, now() + interval '7 days')
    ON CONFLICT DO NOTHING RETURNING * INTO v_invitation;
    EXIT WHEN FOUND;
  END LOOP;
  RETURN jsonb_build_object(
    'invitation_id', v_invitation.id,
    'code', v_code,
    'link_token', v_token,
    'expires_at', v_invitation.expires_at,
    'max_uses', v_invitation.max_uses
  );
END;
$$;

CREATE FUNCTION public.redeem_invitation(p_credential text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user uuid := auth.uid();
  v_invitation public.squad_invitations%ROWTYPE;
  v_squad public.squads%ROWTYPE;
  v_count int;
  v_attempts int;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  -- Failed attempts must commit, so expected failures return stable codes rather
  -- than raising exceptions that would roll the rate-limit record back.
  INSERT INTO public.squad_invitation_attempts(user_id) VALUES (v_user);
  SELECT count(*) INTO v_attempts FROM public.squad_invitation_attempts
    WHERE user_id = v_user AND attempted_at > now() - interval '15 minutes';
  IF v_attempts > 10 THEN RETURN jsonb_build_object('error', 'rate_limited'); END IF;
  IF p_credential IS NULL OR length(btrim(p_credential)) NOT IN (10, 64) THEN
    RETURN jsonb_build_object('error', 'invalid_invitation');
  END IF;
  SELECT * INTO v_invitation FROM public.squad_invitations
  WHERE code_hash = sha256(convert_to(upper(btrim(p_credential)), 'UTF8'))
     OR link_hash = sha256(convert_to(lower(btrim(p_credential)), 'UTF8'))
  FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'invalid_invitation'); END IF;
  IF v_invitation.revoked_at IS NOT NULL OR v_invitation.expires_at <= now()
     OR v_invitation.used_count >= v_invitation.max_uses THEN
    RETURN jsonb_build_object('error', 'invalid_invitation');
  END IF;
  SELECT * INTO v_squad FROM public.squads WHERE id = v_invitation.squad_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'invalid_invitation'); END IF;
  IF EXISTS (SELECT 1 FROM public.squad_members
             WHERE squad_id = v_squad.id AND user_id = v_user) THEN
    RETURN jsonb_build_object('error', 'already_member');
  END IF;
  SELECT count(*) INTO v_count FROM public.squad_members WHERE squad_id = v_squad.id;
  IF v_count >= v_squad.max_members THEN
    RETURN jsonb_build_object('error', 'squad_full');
  END IF;
  INSERT INTO public.squad_members(squad_id, user_id, role)
  VALUES (v_squad.id, v_user, 'member');
  UPDATE public.squad_invitations SET used_count = used_count + 1
  WHERE id = v_invitation.id;
  IF v_count + 1 >= 2 AND v_squad.status = 'pending' THEN
    UPDATE public.squads SET status = 'active' WHERE id = v_squad.id
    RETURNING * INTO v_squad;
  END IF;
  RETURN to_jsonb(v_squad);
END;
$$;

CREATE FUNCTION public.revoke_invitation(p_invitation_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_squad_id uuid;
BEGIN
  SELECT squad_id INTO v_squad_id FROM public.squad_invitations
    WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND OR NOT public.is_squad_captain(v_squad_id) THEN
    RAISE EXCEPTION 'not_captain' USING ERRCODE = '42501';
  END IF;
  UPDATE public.squad_invitations SET revoked_at = now()
    WHERE id = p_invitation_id AND revoked_at IS NULL;
END;
$$;

CREATE FUNCTION public.remove_squad_member(p_squad_id uuid, p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count int;
BEGIN
  PERFORM 1 FROM public.squads WHERE id = p_squad_id FOR UPDATE;
  IF NOT FOUND OR NOT public.is_squad_captain(p_squad_id) THEN
    RAISE EXCEPTION 'not_captain' USING ERRCODE = '42501';
  END IF;
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'captain_must_transfer'; END IF;
  SELECT count(*) INTO v_count FROM public.squad_members WHERE squad_id = p_squad_id;
  IF v_count <= 2 THEN RAISE EXCEPTION 'squad_minimum_two'; END IF;
  DELETE FROM public.squad_members
    WHERE squad_id = p_squad_id AND user_id = p_user_id AND role = 'member';
  IF NOT FOUND THEN RAISE EXCEPTION 'member_not_found'; END IF;
END;
$$;

CREATE FUNCTION public.leave_squad(p_squad_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count int; v_role text;
BEGIN
  PERFORM 1 FROM public.squads WHERE id = p_squad_id FOR UPDATE;
  SELECT role INTO v_role FROM public.squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid();
  IF v_role IS NULL THEN RAISE EXCEPTION 'not_member' USING ERRCODE = '42501'; END IF;
  IF v_role = 'captain' THEN RAISE EXCEPTION 'captain_must_transfer'; END IF;
  SELECT count(*) INTO v_count FROM public.squad_members WHERE squad_id = p_squad_id;
  IF v_count <= 2 THEN RAISE EXCEPTION 'squad_minimum_two'; END IF;
  DELETE FROM public.squad_members
    WHERE squad_id = p_squad_id AND user_id = auth.uid();
END;
$$;

CREATE FUNCTION public.transfer_squad_captain(p_squad_id uuid, p_new_captain_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  PERFORM 1 FROM public.squads WHERE id = p_squad_id FOR UPDATE;
  IF NOT FOUND OR NOT public.is_squad_captain(p_squad_id) THEN
    RAISE EXCEPTION 'not_captain' USING ERRCODE = '42501';
  END IF;
  IF p_new_captain_id = auth.uid() OR NOT EXISTS (
    SELECT 1 FROM public.squad_members
      WHERE squad_id = p_squad_id AND user_id = p_new_captain_id
  ) THEN RAISE EXCEPTION 'invalid_new_captain'; END IF;
  UPDATE public.squad_members SET role = 'member'
    WHERE squad_id = p_squad_id AND user_id = auth.uid();
  UPDATE public.squad_members SET role = 'captain'
    WHERE squad_id = p_squad_id AND user_id = p_new_captain_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_squad(text,text),
  public.issue_invitation(uuid,int), public.redeem_invitation(text),
  public.revoke_invitation(uuid), public.remove_squad_member(uuid,uuid),
  public.leave_squad(uuid), public.transfer_squad_captain(uuid,uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_squad(text,text),
  public.issue_invitation(uuid,int), public.redeem_invitation(text),
  public.revoke_invitation(uuid), public.remove_squad_member(uuid,uuid),
  public.leave_squad(uuid), public.transfer_squad_captain(uuid,uuid) TO authenticated;

-- Unified immutable card snapshots and text/card conversation timeline.
CREATE TABLE public.card_snapshots (
  id uuid PRIMARY KEY,
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES public.profiles(id),
  kind text NOT NULL CHECK (kind IN ('activity', 'conversation')),
  snapshot jsonb NOT NULL,
  template_id text NOT NULL,
  template_version int NOT NULL CHECK (template_version BETWEEN 1 AND 100),
  has_encrypted_route boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, squad_id)
);
ALTER TABLE public.card_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY card_snapshots_select ON public.card_snapshots FOR SELECT TO authenticated
  USING (public.is_squad_member(squad_id));
REVOKE ALL ON public.card_snapshots FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.card_snapshots TO authenticated;
CREATE INDEX card_snapshots_squad_created_idx
  ON public.card_snapshots(squad_id, created_at, id);

CREATE TABLE public.squad_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id),
  kind text NOT NULL CHECK (kind IN ('text', 'card')),
  body text,
  card_id uuid,
  reply_to_message_id uuid,
  client_nonce uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, squad_id),
  UNIQUE (squad_id, sender_id, client_nonce),
  UNIQUE (card_id),
  FOREIGN KEY (card_id, squad_id) REFERENCES public.card_snapshots(id, squad_id),
  FOREIGN KEY (reply_to_message_id, squad_id) REFERENCES public.squad_messages(id, squad_id),
  CHECK ((kind = 'text' AND body IS NOT NULL AND card_id IS NULL)
      OR (kind = 'card' AND body IS NULL AND card_id IS NOT NULL))
);
ALTER TABLE public.squad_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY squad_messages_select ON public.squad_messages FOR SELECT TO authenticated
  USING (public.is_squad_member(squad_id));
REVOKE ALL ON public.squad_messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.squad_messages TO authenticated;
CREATE INDEX squad_messages_timeline_idx
  ON public.squad_messages(squad_id, created_at, id);

CREATE FUNCTION public.timeline_entry_json(p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT to_jsonb(m) || jsonb_build_object(
    'author', jsonb_build_object('id', p.id, 'nickname', p.nickname,
                                 'avatar_url', p.avatar_url),
    'card_snapshot', to_jsonb(c))
  FROM public.squad_messages m
  JOIN public.profiles p ON p.id = m.sender_id
  LEFT JOIN public.card_snapshots c ON c.id = m.card_id
  WHERE m.id = p_message_id AND public.is_squad_member(m.squad_id);
$$;
REVOKE ALL ON FUNCTION public.timeline_entry_json(uuid) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.page_squad_timeline(
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
  SELECT public.timeline_entry_json(q.id)
  FROM (
    SELECT m.id, m.created_at FROM public.squad_messages m
    WHERE m.squad_id = p_squad_id
      AND (p_after_id IS NULL OR (m.created_at, m.id) >
           (p_after_created_at, p_after_id))
      AND (p_before_id IS NULL OR (m.created_at, m.id) <
           (p_before_created_at, p_before_id))
    -- A catch-up page must start at the cursor's *nearest* successors;
    -- taking the newest 50 here permanently skips older unseen messages.
    ORDER BY
      CASE WHEN p_after_id IS NOT NULL THEN m.created_at END ASC,
      CASE WHEN p_after_id IS NOT NULL THEN m.id END ASC,
      CASE WHEN p_after_id IS NULL THEN m.created_at END DESC,
      CASE WHEN p_after_id IS NULL THEN m.id END DESC
    LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)
  ) q
  ORDER BY q.created_at, q.id;
END;
$$;

CREATE FUNCTION public.send_text_message(
  p_squad_id uuid,
  p_body text,
  p_client_nonce uuid,
  p_reply_to_message_id uuid DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user uuid := auth.uid();
  v_message public.squad_messages%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF NOT public.is_squad_member(p_squad_id) THEN
    RETURN jsonb_build_object('error', 'not_member');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.squads
                 WHERE id = p_squad_id AND status = 'active') THEN
    RETURN jsonb_build_object('error', 'squad_inactive');
  END IF;
  IF p_client_nonce IS NULL OR p_body IS NULL OR length(btrim(p_body)) NOT BETWEEN 1 AND 4000 THEN
    RETURN jsonb_build_object('error', 'invalid_message');
  END IF;
  IF p_reply_to_message_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.squad_messages
      WHERE id = p_reply_to_message_id AND squad_id = p_squad_id) THEN
    RETURN jsonb_build_object('error', 'invalid_reply');
  END IF;
  -- Per-sender lock serializes retries before checking the unique nonce.
  PERFORM 1 FROM public.profiles WHERE id = v_user FOR UPDATE;
  SELECT * INTO v_message FROM public.squad_messages
    WHERE squad_id = p_squad_id AND sender_id = v_user
      AND client_nonce = p_client_nonce;
  IF FOUND THEN
    IF v_message.kind <> 'text' OR v_message.body IS DISTINCT FROM p_body
       OR v_message.reply_to_message_id IS DISTINCT FROM p_reply_to_message_id THEN
      RETURN jsonb_build_object('error', 'nonce_conflict');
    END IF;
    RETURN public.timeline_entry_json(v_message.id);
  END IF;
  INSERT INTO public.squad_messages
    (squad_id, sender_id, kind, body, reply_to_message_id, client_nonce)
  VALUES (p_squad_id, v_user, 'text', p_body, p_reply_to_message_id, p_client_nonce)
  RETURNING * INTO v_message;
  RETURN public.timeline_entry_json(v_message.id);
END;
$$;

CREATE FUNCTION public.publish_card_message(
  p_squad_id uuid,
  p_kind text,
  p_snapshot jsonb,
  p_template_id text,
  p_template_version int,
  p_client_nonce uuid,
  p_card_id uuid DEFAULT NULL,
  p_route_bundle jsonb DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user uuid := auth.uid();
  v_message public.squad_messages%ROWTYPE;
  v_card public.card_snapshots%ROWTYPE;
  v_sensitive text[];
  v_confirmed text[];
  v_selected_id text;
  v_selected_ids uuid[] := ARRAY[]::uuid[];
  v_route_error text;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF NOT public.is_squad_member(p_squad_id) THEN
    RETURN jsonb_build_object('error', 'not_member');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.squads
                 WHERE id = p_squad_id AND status = 'active') THEN
    RETURN jsonb_build_object('error', 'squad_inactive');
  END IF;
  IF p_client_nonce IS NULL OR p_kind NOT IN ('activity', 'conversation')
     OR p_snapshot IS NULL OR jsonb_typeof(p_snapshot) <> 'object'
     OR length(p_snapshot::text) > 4096
     OR p_template_id IS NULL OR p_template_id !~ '^[a-z0-9][a-z0-9-]{0,39}$'
     OR p_template_version NOT BETWEEN 1 AND 100 THEN
    RETURN jsonb_build_object('error', 'invalid_card');
  END IF;
  IF p_route_bundle IS NOT NULL THEN
    IF p_kind <> 'activity' OR p_card_id IS NULL THEN
      RETURN jsonb_build_object('error', 'invalid_route_bundle');
    END IF;
    v_route_error := public.route_bundle_error(p_squad_id, p_route_bundle);
    IF v_route_error IS NOT NULL THEN
      RETURN jsonb_build_object('error', v_route_error);
    END IF;
  END IF;
  IF p_kind = 'activity' THEN
    IF p_snapshot - ARRAY[
      'activity_type', 'date', 'distance_m', 'duration_s', 'pace_s_per_km',
      'title', 'avg_heart_rate_bpm', 'weight_kg', 'sleep_minutes',
      'confirmed_sensitive_fields'
    ]::text[] <> '{}'::jsonb
       OR NOT (p_snapshot ?& ARRAY[
         'activity_type', 'date', 'distance_m', 'duration_s', 'pace_s_per_km'
       ])
       OR p_snapshot ->> 'activity_type' NOT IN ('run', 'hike')
       OR p_snapshot ->> 'date' !~ '^\d{4}-\d{2}-\d{2}$'
       OR jsonb_typeof(p_snapshot -> 'distance_m') <> 'number'
       OR jsonb_typeof(p_snapshot -> 'duration_s') <> 'number'
       OR jsonb_typeof(p_snapshot -> 'pace_s_per_km') <> 'number' THEN
      RETURN jsonb_build_object('error', 'invalid_snapshot');
    END IF;
    IF (p_snapshot ->> 'distance_m')::numeric NOT BETWEEN 1 AND 1000000
       OR (p_snapshot ->> 'duration_s')::numeric NOT BETWEEN 1 AND 1000000
       OR (p_snapshot ->> 'pace_s_per_km')::numeric NOT BETWEEN 1 AND 36000
       OR (p_snapshot ->> 'duration_s')::numeric <> trunc((p_snapshot ->> 'duration_s')::numeric)
       OR (p_snapshot ->> 'pace_s_per_km')::numeric <> trunc((p_snapshot ->> 'pace_s_per_km')::numeric)
       OR (p_snapshot ? 'title' AND
           (jsonb_typeof(p_snapshot -> 'title') <> 'string'
            OR length(p_snapshot ->> 'title') > 80)) THEN
      RETURN jsonb_build_object('error', 'invalid_snapshot');
    END IF;
    IF (p_snapshot ? 'avg_heart_rate_bpm' AND
        (jsonb_typeof(p_snapshot -> 'avg_heart_rate_bpm') <> 'number'
         OR (p_snapshot ->> 'avg_heart_rate_bpm')::numeric NOT BETWEEN 30 AND 240))
       OR (p_snapshot ? 'weight_kg' AND
        (jsonb_typeof(p_snapshot -> 'weight_kg') <> 'number'
         OR (p_snapshot ->> 'weight_kg')::numeric NOT BETWEEN 20 AND 500))
       OR (p_snapshot ? 'sleep_minutes' AND
        (jsonb_typeof(p_snapshot -> 'sleep_minutes') <> 'number'
         OR (p_snapshot ->> 'sleep_minutes')::numeric NOT BETWEEN 0 AND 1440)) THEN
      RETURN jsonb_build_object('error', 'invalid_snapshot');
    END IF;
    SELECT coalesce(array_agg(key ORDER BY key), ARRAY[]::text[]) INTO v_sensitive
      FROM jsonb_object_keys(p_snapshot) key
      WHERE key IN ('avg_heart_rate_bpm', 'weight_kg', 'sleep_minutes');
    IF p_snapshot ? 'confirmed_sensitive_fields' THEN
      IF jsonb_typeof(p_snapshot -> 'confirmed_sensitive_fields') <> 'array' THEN
        RETURN jsonb_build_object('error', 'sensitive_confirmation_required');
      END IF;
      SELECT coalesce(array_agg(value ORDER BY value), ARRAY[]::text[])
        INTO v_confirmed
        FROM jsonb_array_elements_text(p_snapshot -> 'confirmed_sensitive_fields') value;
    ELSE
      v_confirmed := ARRAY[]::text[];
    END IF;
    IF v_confirmed IS DISTINCT FROM v_sensitive THEN
      RETURN jsonb_build_object('error', 'sensitive_confirmation_required');
    END IF;
  ELSE
    IF p_snapshot - 'selected_message_ids' <> '{}'::jsonb
       OR jsonb_typeof(p_snapshot -> 'selected_message_ids') <> 'array'
       OR jsonb_array_length(p_snapshot -> 'selected_message_ids') NOT BETWEEN 1 AND 6 THEN
      RETURN jsonb_build_object('error', 'invalid_snapshot');
    END IF;
    FOR v_selected_id IN SELECT jsonb_array_elements_text(p_snapshot -> 'selected_message_ids') LOOP
      BEGIN
        IF v_selected_id::uuid = ANY(v_selected_ids) OR NOT EXISTS (
          SELECT 1 FROM public.squad_messages
          WHERE id = v_selected_id::uuid AND squad_id = p_squad_id
            AND sender_id = v_user AND kind = 'text') THEN
          RETURN jsonb_build_object('error', 'invalid_source_message');
        END IF;
        v_selected_ids := array_append(v_selected_ids, v_selected_id::uuid);
      EXCEPTION WHEN invalid_text_representation THEN
        RETURN jsonb_build_object('error', 'invalid_source_message');
      END;
    END LOOP;
  END IF;
  PERFORM 1 FROM public.profiles WHERE id = v_user FOR UPDATE;
  SELECT * INTO v_message FROM public.squad_messages
    WHERE squad_id = p_squad_id AND sender_id = v_user
      AND client_nonce = p_client_nonce;
  IF FOUND THEN
    SELECT * INTO v_card FROM public.card_snapshots WHERE id = v_message.card_id;
    IF v_message.kind <> 'card' OR v_card.kind IS DISTINCT FROM p_kind
       OR v_card.snapshot IS DISTINCT FROM p_snapshot
       OR v_card.template_id IS DISTINCT FROM p_template_id
       OR v_card.template_version IS DISTINCT FROM p_template_version
       OR (p_card_id IS NOT NULL AND v_card.id IS DISTINCT FROM p_card_id)
       OR v_card.has_encrypted_route IS DISTINCT FROM (p_route_bundle IS NOT NULL)
       OR (p_route_bundle IS NOT NULL AND
           (SELECT bundle_hash FROM public.card_route_ciphertexts
              WHERE card_id = v_card.id) IS DISTINCT FROM
           sha256(convert_to(p_route_bundle::text, 'UTF8'))) THEN
      RETURN jsonb_build_object('error', 'nonce_conflict');
    END IF;
    RETURN public.timeline_entry_json(v_message.id);
  END IF;
  INSERT INTO public.card_snapshots
    (id, squad_id, author_id, kind, snapshot, template_id, template_version,
     has_encrypted_route)
  VALUES (coalesce(p_card_id, gen_random_uuid()), p_squad_id, v_user,
          p_kind, p_snapshot, p_template_id, p_template_version,
          p_route_bundle IS NOT NULL)
  RETURNING * INTO v_card;
  IF p_route_bundle IS NOT NULL THEN
    PERFORM public.store_encrypted_route(v_card.id, p_squad_id, p_route_bundle);
  END IF;
  INSERT INTO public.squad_messages
    (squad_id, sender_id, kind, card_id, client_nonce)
  VALUES (p_squad_id, v_user, 'card', v_card.id, p_client_nonce)
  RETURNING * INTO v_message;
  RETURN public.timeline_entry_json(v_message.id);
END;
$$;

REVOKE ALL ON FUNCTION public.page_squad_timeline(uuid,timestamptz,uuid,timestamptz,uuid,int),
  public.send_text_message(uuid,text,uuid,uuid),
  public.publish_card_message(uuid,text,jsonb,text,int,uuid,uuid,jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.page_squad_timeline(uuid,timestamptz,uuid,timestamptz,uuid,int),
  public.send_text_message(uuid,text,uuid,uuid),
  public.publish_card_message(uuid,text,jsonb,text,int,uuid,uuid,jsonb) TO authenticated;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.squad_messages;
  END IF;
END;
$$;

-- Device-specific X25519 public keys; private keys never enter the database.
CREATE TABLE public.route_device_keys (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  device_id uuid NOT NULL,
  public_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  PRIMARY KEY (user_id, device_id)
);
ALTER TABLE public.route_device_keys ENABLE ROW LEVEL SECURITY;
CREATE POLICY route_device_keys_select ON public.route_device_keys
  FOR SELECT TO authenticated USING (public.can_view_profile(user_id));
REVOKE ALL ON public.route_device_keys FROM PUBLIC, anon, authenticated;
GRANT SELECT (user_id, device_id, public_key, created_at, revoked_at)
  ON public.route_device_keys TO authenticated;

CREATE TABLE public.card_route_ciphertexts (
  card_id uuid PRIMARY KEY,
  squad_id uuid NOT NULL,
  algorithm text NOT NULL,
  nonce text NOT NULL,
  ciphertext text NOT NULL,
  mac text NOT NULL,
  bundle_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (card_id, squad_id) REFERENCES public.card_snapshots(id, squad_id)
    ON DELETE CASCADE
);
ALTER TABLE public.card_route_ciphertexts ENABLE ROW LEVEL SECURITY;
CREATE POLICY card_route_ciphertexts_select ON public.card_route_ciphertexts
  FOR SELECT TO authenticated USING (public.is_squad_member(squad_id));
REVOKE ALL ON public.card_route_ciphertexts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.card_route_ciphertexts TO authenticated;

CREATE TABLE public.card_route_envelopes (
  card_id uuid NOT NULL,
  squad_id uuid NOT NULL,
  recipient_user_id uuid NOT NULL,
  recipient_device_id uuid NOT NULL,
  ephemeral_public_key text NOT NULL,
  salt text NOT NULL,
  nonce text NOT NULL,
  ciphertext text NOT NULL,
  mac text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (card_id, recipient_user_id, recipient_device_id),
  FOREIGN KEY (card_id, squad_id) REFERENCES public.card_snapshots(id, squad_id)
    ON DELETE CASCADE,
  FOREIGN KEY (recipient_user_id, recipient_device_id)
    REFERENCES public.route_device_keys(user_id, device_id)
);
ALTER TABLE public.card_route_envelopes ENABLE ROW LEVEL SECURITY;
CREATE POLICY card_route_envelopes_select ON public.card_route_envelopes
  FOR SELECT TO authenticated
  USING (recipient_user_id = auth.uid() AND public.is_squad_member(squad_id));
REVOKE ALL ON public.card_route_envelopes FROM PUBLIC, anon, authenticated;
GRANT SELECT (card_id, squad_id, recipient_user_id, recipient_device_id,
  ephemeral_public_key, salt, nonce, ciphertext, mac, created_at)
  ON public.card_route_envelopes TO authenticated;

CREATE FUNCTION public.route_b64_is_valid(
  p_value text, p_exact_bytes int DEFAULT NULL, p_max_bytes int DEFAULT NULL
)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE v_bytes bytea;
BEGIN
  IF p_value IS NULL OR length(p_value) > 350000
     OR length(p_value) % 4 <> 0
     OR p_value !~ '^[A-Za-z0-9+/]+={0,2}$' THEN RETURN false; END IF;
  BEGIN
    v_bytes := decode(p_value, 'base64');
  EXCEPTION WHEN others THEN
    RETURN false;
  END;
  RETURN (p_exact_bytes IS NULL OR octet_length(v_bytes) = p_exact_bytes)
     AND (p_max_bytes IS NULL OR octet_length(v_bytes) <= p_max_bytes)
     AND replace(encode(v_bytes, 'base64'), E'\n', '') = p_value;
END;
$$;
REVOKE ALL ON FUNCTION public.route_b64_is_valid(text,int,int)
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.register_route_device_key(p_device_id uuid, p_public_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_existing public.route_device_keys%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error', 'unauthenticated'); END IF;
  IF p_device_id IS NULL OR NOT public.route_b64_is_valid(p_public_key, 32, NULL) THEN
    RETURN jsonb_build_object('error', 'invalid_public_key');
  END IF;
  SELECT * INTO v_existing FROM public.route_device_keys
    WHERE user_id = auth.uid() AND device_id = p_device_id FOR UPDATE;
  IF FOUND THEN
    IF v_existing.revoked_at IS NOT NULL OR v_existing.public_key <> p_public_key THEN
      RETURN jsonb_build_object('error', 'device_key_conflict');
    END IF;
    RETURN jsonb_build_object('user_id', auth.uid(), 'device_id', p_device_id);
  END IF;
  INSERT INTO public.route_device_keys(user_id, device_id, public_key)
  VALUES (auth.uid(), p_device_id, p_public_key);
  RETURN jsonb_build_object('user_id', auth.uid(), 'device_id', p_device_id);
END;
$$;

CREATE FUNCTION public.revoke_route_device_key(p_device_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501'; END IF;
  UPDATE public.route_device_keys SET revoked_at = now()
    WHERE user_id = auth.uid() AND device_id = p_device_id AND revoked_at IS NULL;
END;
$$;

CREATE FUNCTION public.list_route_recipients(p_squad_id uuid)
RETURNS TABLE(user_id uuid, device_id uuid, public_key text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_squad_member(p_squad_id) THEN RETURN; END IF;
  RETURN QUERY
  SELECT k.user_id, k.device_id, k.public_key
  FROM public.squad_members m JOIN public.route_device_keys k
    ON k.user_id = m.user_id
  WHERE m.squad_id = p_squad_id AND k.revoked_at IS NULL
  ORDER BY k.user_id, k.device_id;
END;
$$;

CREATE FUNCTION public.route_bundle_error(p_squad_id uuid, p_bundle jsonb)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_route jsonb;
  v_envelope jsonb;
  v_recipient_user uuid;
  v_recipient_device uuid;
  v_seen text[] := ARRAY[]::text[];
  v_expected_count int;
  v_member_count int;
  v_covered_members int;
BEGIN
  IF p_bundle IS NULL OR jsonb_typeof(p_bundle) <> 'object'
     OR length(p_bundle::text) > 500000
     OR p_bundle - ARRAY['version','algorithm','route','envelopes']::text[] <> '{}'::jsonb
     OR NOT (p_bundle ?& ARRAY['version','algorithm','route','envelopes'])
     OR p_bundle -> 'version' <> '1'::jsonb
     OR p_bundle ->> 'algorithm' <> 'X25519-HKDF-SHA256-AES-256-GCM' THEN
    RETURN 'invalid_route_bundle';
  END IF;
  v_route := p_bundle -> 'route';
  IF jsonb_typeof(v_route) <> 'object'
     OR v_route - ARRAY['nonce','ciphertext','mac']::text[] <> '{}'::jsonb
     OR NOT (v_route ?& ARRAY['nonce','ciphertext','mac'])
     OR NOT public.route_b64_is_valid(v_route ->> 'nonce', 12, NULL)
     OR NOT public.route_b64_is_valid(v_route ->> 'ciphertext', NULL, 262144)
     OR NOT public.route_b64_is_valid(v_route ->> 'mac', 16, NULL)
     OR jsonb_typeof(p_bundle -> 'envelopes') <> 'array' THEN
    RETURN 'invalid_route_bundle';
  END IF;
  SELECT count(*) INTO v_member_count FROM public.squad_members
    WHERE squad_id = p_squad_id;
  SELECT count(*), count(DISTINCT k.user_id)
    INTO v_expected_count, v_covered_members
    FROM public.route_device_keys k JOIN public.squad_members m
      ON m.user_id = k.user_id
    WHERE m.squad_id = p_squad_id AND k.revoked_at IS NULL;
  IF v_member_count < 2 OR v_covered_members <> v_member_count THEN
    RETURN 'missing_route_keys';
  END IF;
  IF jsonb_array_length(p_bundle -> 'envelopes') <> v_expected_count
     OR v_expected_count > 36 THEN RETURN 'invalid_route_recipients'; END IF;
  FOR v_envelope IN SELECT value FROM jsonb_array_elements(p_bundle -> 'envelopes') value LOOP
    IF jsonb_typeof(v_envelope) <> 'object'
       OR v_envelope - ARRAY[
         'recipient_user_id','recipient_device_id','ephemeral_public_key',
         'salt','nonce','ciphertext','mac']::text[] <> '{}'::jsonb
       OR NOT (v_envelope ?& ARRAY[
         'recipient_user_id','recipient_device_id','ephemeral_public_key',
         'salt','nonce','ciphertext','mac'])
       OR NOT public.route_b64_is_valid(v_envelope ->> 'ephemeral_public_key', 32, NULL)
       OR NOT public.route_b64_is_valid(v_envelope ->> 'salt', 16, NULL)
       OR NOT public.route_b64_is_valid(v_envelope ->> 'nonce', 12, NULL)
       OR NOT public.route_b64_is_valid(v_envelope ->> 'ciphertext', 32, NULL)
       OR NOT public.route_b64_is_valid(v_envelope ->> 'mac', 16, NULL) THEN
      RETURN 'invalid_route_bundle';
    END IF;
    BEGIN
      v_recipient_user := (v_envelope ->> 'recipient_user_id')::uuid;
      v_recipient_device := (v_envelope ->> 'recipient_device_id')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RETURN 'invalid_route_recipients';
    END;
    IF (v_recipient_user::text || ':' || v_recipient_device::text) = ANY(v_seen)
       OR NOT EXISTS (
         SELECT 1 FROM public.route_device_keys k JOIN public.squad_members m
           ON m.user_id = k.user_id
         WHERE m.squad_id = p_squad_id AND k.revoked_at IS NULL
           AND k.user_id = v_recipient_user AND k.device_id = v_recipient_device
       ) THEN RETURN 'invalid_route_recipients'; END IF;
    v_seen := array_append(v_seen,
      v_recipient_user::text || ':' || v_recipient_device::text);
  END LOOP;
  RETURN NULL;
END;
$$;

CREATE FUNCTION public.store_encrypted_route(
  p_card_id uuid, p_squad_id uuid, p_bundle jsonb
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_envelope jsonb;
BEGIN
  INSERT INTO public.card_route_ciphertexts
    (card_id, squad_id, algorithm, nonce, ciphertext, mac, bundle_hash)
  VALUES (p_card_id, p_squad_id, p_bundle ->> 'algorithm',
    p_bundle -> 'route' ->> 'nonce', p_bundle -> 'route' ->> 'ciphertext',
    p_bundle -> 'route' ->> 'mac', sha256(convert_to(p_bundle::text, 'UTF8')));
  FOR v_envelope IN SELECT value FROM jsonb_array_elements(p_bundle -> 'envelopes') value LOOP
    INSERT INTO public.card_route_envelopes
      (card_id, squad_id, recipient_user_id, recipient_device_id,
       ephemeral_public_key, salt, nonce, ciphertext, mac)
    VALUES (p_card_id, p_squad_id,
      (v_envelope ->> 'recipient_user_id')::uuid,
      (v_envelope ->> 'recipient_device_id')::uuid,
      v_envelope ->> 'ephemeral_public_key', v_envelope ->> 'salt',
      v_envelope ->> 'nonce', v_envelope ->> 'ciphertext', v_envelope ->> 'mac');
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.register_route_device_key(uuid,text),
  public.revoke_route_device_key(uuid), public.list_route_recipients(uuid),
  public.route_bundle_error(uuid,jsonb), public.store_encrypted_route(uuid,uuid,jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_route_device_key(uuid,text),
  public.revoke_route_device_key(uuid), public.list_route_recipients(uuid)
  TO authenticated;
