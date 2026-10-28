-- Same photo message facts for widgets, wall and explicit parent lookup.
-- No storage paths or credentials are returned, and no read cursor advances.
CREATE INDEX squad_messages_photo_page_idx ON public.squad_messages(squad_id,created_at DESC,id DESC)
 WHERE kind='photo' AND plan_id IS NULL;

CREATE FUNCTION public.page_squad_photos(
 p_squad_id uuid,p_before_created_at timestamptz DEFAULT NULL,
 p_before_id uuid DEFAULT NULL,p_limit int DEFAULT 50
) RETURNS SETOF jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_squad_member(p_squad_id) THEN RETURN; END IF;
 IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
  RAISE EXCEPTION 'invalid_cursor';
 END IF;
 RETURN QUERY
 SELECT public.timeline_entry_json(page.id) FROM (
  SELECT m.id,m.created_at FROM public.squad_messages m
  JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
  WHERE m.squad_id=p_squad_id AND m.kind='photo' AND m.plan_id IS NULL AND p.state='published'
   AND (p_before_id IS NULL OR (m.created_at,m.id)<(p_before_created_at,p_before_id))
  ORDER BY m.created_at DESC,m.id DESC
  LIMIT least(greatest(coalesce(p_limit,50),1),50)
 ) page ORDER BY page.created_at,page.id;
END;
$$;
CREATE FUNCTION public.get_squad_photo(p_squad_id uuid,p_message_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.timeline_entry_json(m.id) FROM public.squad_messages m
 JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
 WHERE auth.uid() IS NOT NULL AND public.is_squad_member(p_squad_id)
  AND m.id=p_message_id AND m.squad_id=p_squad_id AND m.kind='photo' AND m.plan_id IS NULL
  AND p.state='published';
$$;
REVOKE ALL ON FUNCTION public.page_squad_photos(uuid,timestamptz,uuid,int),public.get_squad_photo(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.page_squad_photos(uuid,timestamptz,uuid,int),public.get_squad_photo(uuid,uuid) TO authenticated;
