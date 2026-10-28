-- Private imported materials and immutable, explicitly published Squad snapshots.
-- Data items never become visible to Squad members; publication copies values
-- into a separate row and stores no source-item identifier.

CREATE TABLE IF NOT EXISTS public.external_data_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('apple_health', 'mi_fitness', 'huawei_health')),
  display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 1 AND 120),
  mode text NOT NULL CHECK (mode IN ('health_sync', 'file_import')),
  enabled_types text[] NOT NULL DEFAULT '{}',
  connected_at timestamptz,
  last_synced_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);
ALTER TABLE public.external_data_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY external_data_connections_owner_select
  ON public.external_data_connections FOR SELECT TO authenticated
  USING (user_id = auth.uid());
REVOKE ALL ON public.external_data_connections FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.external_data_connections TO authenticated;
GRANT ALL PRIVILEGES ON public.external_data_connections TO service_role;

CREATE TABLE IF NOT EXISTS public.external_data_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (length(trim(source)) BETWEEN 1 AND 80),
  source_label text NOT NULL CHECK (length(trim(source_label)) BETWEEN 1 AND 120),
  category text NOT NULL CHECK (length(trim(category)) BETWEEN 1 AND 80),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 160),
  summary text NOT NULL DEFAULT '',
  metric_value text NOT NULL CHECK (length(metric_value) <= 80),
  metric_unit text NOT NULL DEFAULT '' CHECK (length(metric_unit) <= 40),
  range_start timestamptz NOT NULL,
  range_end timestamptz NOT NULL,
  imported_at timestamptz NOT NULL DEFAULT now(),
  trend jsonb NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(trend) = 'array' AND jsonb_array_length(trend) <= 180),
  CHECK (range_end >= range_start)
);
ALTER TABLE public.external_data_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY external_data_items_owner_select
  ON public.external_data_items FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY external_data_items_owner_insert
  ON public.external_data_items FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY external_data_items_owner_delete
  ON public.external_data_items FOR DELETE TO authenticated
  USING (user_id = auth.uid());
REVOKE ALL ON public.external_data_items FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.external_data_items TO authenticated;
CREATE INDEX external_data_items_owner_imported_idx
  ON public.external_data_items(user_id, imported_at DESC, id);

CREATE TABLE IF NOT EXISTS public.social_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id uuid NOT NULL REFERENCES public.squads(id) ON DELETE CASCADE,
  author_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  author_name text NOT NULL CHECK (length(trim(author_name)) BETWEEN 1 AND 80),
  title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 160),
  body text NOT NULL DEFAULT '' CHECK (length(body) <= 2000),
  template text NOT NULL CHECK (length(trim(template)) BETWEEN 1 AND 80),
  visibility text NOT NULL CHECK (visibility IN ('squad', 'selected')),
  visible_to_user_ids text[] NOT NULL DEFAULT '{}',
  source_label text NOT NULL CHECK (length(trim(source_label)) BETWEEN 1 AND 120),
  metric_value text NOT NULL CHECK (length(metric_value) <= 80),
  metric_unit text NOT NULL DEFAULT '' CHECK (length(metric_unit) <= 40),
  range_start timestamptz NOT NULL,
  range_end timestamptz NOT NULL,
  trend jsonb NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(trend) = 'array' AND jsonb_array_length(trend) <= 180),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, squad_id),
  CHECK (range_end >= range_start),
  CHECK (
    (visibility = 'squad' AND cardinality(visible_to_user_ids) = 0)
    OR (visibility = 'selected' AND cardinality(visible_to_user_ids) > 0)
  )
);
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY social_posts_audience_select
  ON public.social_posts FOR SELECT TO authenticated
  USING (
    public.is_squad_member(squad_id)
    AND (
      visibility = 'squad'
      OR author_id = auth.uid()
      OR auth.uid() = ANY(visible_to_user_ids)
    )
  );
REVOKE ALL ON public.social_posts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.social_posts TO authenticated;
CREATE INDEX social_posts_squad_created_idx
  ON public.social_posts(squad_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.social_post_reactions (
  post_id uuid NOT NULL,
  squad_id uuid NOT NULL,
  user_id text NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id),
  FOREIGN KEY (post_id, squad_id)
    REFERENCES public.social_posts(id, squad_id) ON DELETE CASCADE
);
ALTER TABLE public.social_post_reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY social_post_reactions_visible_select
  ON public.social_post_reactions FOR SELECT TO authenticated
  USING (
    public.is_squad_member(squad_id)
    AND EXISTS (
      SELECT 1 FROM public.social_posts post
      WHERE post.id = post_id AND post.squad_id = squad_id
        AND (
          post.visibility = 'squad'
          OR post.author_id = auth.uid()
          OR auth.uid() = ANY(post.visible_to_user_ids)
        )
    )
  );
REVOKE ALL ON public.social_post_reactions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.social_post_reactions TO authenticated;

CREATE OR REPLACE FUNCTION public.publish_social_post(
  p_squad_id uuid,
  p_data_item_id uuid,
  p_title text,
  p_body text,
  p_template text,
  p_visibility text,
  p_visible_to_user_ids text[] DEFAULT '{}',
  p_post_id uuid DEFAULT NULL
) RETURNS public.social_posts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user text := auth.uid();
  v_item public.external_data_items%ROWTYPE;
  v_nickname text;
  v_post public.social_posts%ROWTYPE;
  v_recipients text[] := coalesce(p_visible_to_user_ids, '{}');
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'unauthorized' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_squad_member(p_squad_id) THEN
    RAISE EXCEPTION 'squad_membership_required' USING ERRCODE = '42501';
  END IF;
  IF p_visibility IS NULL OR p_visibility NOT IN ('squad', 'selected') THEN
    RAISE EXCEPTION 'invalid_visibility' USING ERRCODE = '22023';
  END IF;
  IF length(trim(coalesce(p_title, ''))) > 160
     OR length(coalesce(p_body, '')) > 2000
     OR length(trim(coalesce(p_template, ''))) NOT BETWEEN 1 AND 80 THEN
    RAISE EXCEPTION 'invalid_post_content' USING ERRCODE = '22023';
  END IF;
  IF p_visibility = 'squad' THEN
    v_recipients := '{}';
  ELSE
    IF cardinality(v_recipients) = 0
       OR cardinality(v_recipients) <> cardinality(ARRAY(SELECT DISTINCT unnest(v_recipients)))
       OR v_user = ANY(v_recipients)
       OR EXISTS (
         SELECT 1 FROM unnest(v_recipients) recipient_id
         WHERE NOT EXISTS (
           SELECT 1 FROM public.squad_members member
           WHERE member.squad_id = p_squad_id
             AND member.user_id = recipient_id
         )
       ) THEN
      RAISE EXCEPTION 'invalid_share_recipients' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_item
  FROM public.external_data_items
  WHERE id = p_data_item_id AND user_id = v_user;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'owned_data_item_required' USING ERRCODE = '42501';
  END IF;
  SELECT nickname INTO v_nickname
  FROM public.profiles WHERE id = v_user;

  INSERT INTO public.social_posts (
    id, squad_id, author_id, author_name, title, body, template, visibility,
    visible_to_user_ids, source_label, metric_value, metric_unit,
    range_start, range_end, trend
  ) VALUES (
    coalesce(p_post_id, gen_random_uuid()), p_squad_id, v_user,
    coalesce(nullif(trim(v_nickname), ''), '成员'),
    coalesce(nullif(trim(p_title), ''), v_item.title), coalesce(p_body, ''),
    p_template, p_visibility, v_recipients, v_item.source_label,
    v_item.metric_value, v_item.metric_unit, v_item.range_start,
    v_item.range_end, v_item.trend
  ) RETURNING * INTO v_post;
  RETURN v_post;
END;
$$;
REVOKE ALL ON FUNCTION public.publish_social_post(uuid, uuid, text, text, text, text, text[], uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_social_post(uuid, uuid, text, text, text, text, text[], uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.toggle_social_post_reaction(
  p_post_id uuid,
  p_squad_id uuid
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user text := auth.uid();
BEGIN
  IF v_user IS NULL OR NOT public.is_squad_member(p_squad_id) THEN
    RAISE EXCEPTION 'squad_membership_required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.social_posts post
    WHERE post.id = p_post_id AND post.squad_id = p_squad_id
      AND (
        post.visibility = 'squad'
        OR post.author_id = v_user
        OR v_user = ANY(post.visible_to_user_ids)
      )
  ) THEN
    RAISE EXCEPTION 'post_not_visible' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.social_post_reactions
  WHERE post_id = p_post_id AND squad_id = p_squad_id AND user_id = v_user;
  IF FOUND THEN RETURN false; END IF;
  INSERT INTO public.social_post_reactions(post_id, squad_id, user_id)
  VALUES (p_post_id, p_squad_id, v_user);
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.toggle_social_post_reaction(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_social_post_reaction(uuid, uuid)
  TO authenticated;
