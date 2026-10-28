-- Atomic installation also fences publication during backfill.
DO $migration$
BEGIN
LOCK TABLE public.photo_media,public.squad_messages IN SHARE ROW EXCLUSIVE MODE;
-- A revision is coordination metadata, never another photo/message source.
CREATE TABLE public.squad_photo_heads (
 squad_id uuid PRIMARY KEY REFERENCES public.squads(id) ON DELETE CASCADE,
 revision bigint NOT NULL CHECK (revision >= 0)
);
ALTER TABLE public.squad_photo_heads ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.squad_photo_heads FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.squad_photo_heads TO service_role;

-- One initial stamp for existing message facts, including revoked photographs.
INSERT INTO public.squad_photo_heads(squad_id,revision)
 SELECT DISTINCT squad_id,1 FROM public.squad_messages WHERE kind='photo';

CREATE FUNCTION public.bump_squad_photo_head(p_squad_id uuid)
RETURNS void LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path='' AS $$
 INSERT INTO public.squad_photo_heads(squad_id,revision) VALUES(p_squad_id,1)
 ON CONFLICT(squad_id) DO UPDATE SET revision=public.squad_photo_heads.revision+1;
$$;
CREATE FUNCTION public.stamp_squad_photo_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='DELETE' THEN
  IF OLD.kind='photo' THEN PERFORM public.bump_squad_photo_head(OLD.squad_id); END IF;
  RETURN OLD;
 END IF;
 IF NEW.kind='photo' THEN PERFORM public.bump_squad_photo_head(NEW.squad_id); END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER stamp_squad_photo_message AFTER INSERT OR DELETE ON public.squad_messages
 FOR EACH ROW EXECUTE FUNCTION public.stamp_squad_photo_message();

CREATE FUNCTION public.stamp_squad_photo_visibility()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 -- Publication first updates media, then inserts the message. Only that insert
 -- stamps publication, so retries and preparing uploads never increment twice.
 IF EXISTS(SELECT 1 FROM public.squad_messages WHERE photo_id=NEW.id AND kind='photo') THEN
  PERFORM public.bump_squad_photo_head(NEW.squad_id);
 END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER stamp_squad_photo_visibility AFTER UPDATE OF state ON public.photo_media
 FOR EACH ROW WHEN (OLD.state IS DISTINCT FROM NEW.state)
 EXECUTE FUNCTION public.stamp_squad_photo_visibility();

CREATE FUNCTION public.get_squad_photo_head(p_squad_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object(
  'revision',coalesce((SELECT h.revision FROM public.squad_photo_heads h WHERE h.squad_id=p_squad_id),0)::text,
  'photo',(SELECT public.timeline_entry_json(m.id) FROM public.squad_messages m
    JOIN public.photo_media p ON p.id=m.photo_id AND p.squad_id=m.squad_id
    WHERE m.squad_id=p_squad_id AND m.kind='photo' AND m.plan_id IS NULL AND p.state='published'
    ORDER BY m.created_at DESC,m.id DESC LIMIT 1)
 ) WHERE auth.uid() IS NOT NULL AND public.is_squad_member(p_squad_id);
$$;
REVOKE ALL ON FUNCTION public.bump_squad_photo_head(uuid),public.stamp_squad_photo_message(),
 public.stamp_squad_photo_visibility() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bump_squad_photo_head(uuid),public.stamp_squad_photo_message(),
 public.stamp_squad_photo_visibility() TO service_role;
REVOKE ALL ON FUNCTION public.get_squad_photo_head(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_squad_photo_head(uuid) TO authenticated;

END;
$migration$;
