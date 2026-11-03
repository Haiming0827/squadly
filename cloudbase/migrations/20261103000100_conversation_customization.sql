DO $migration$
BEGIN
CREATE TABLE public.conversation_preferences (
 membership_id uuid PRIMARY KEY REFERENCES public.squad_members(id) ON DELETE CASCADE,
 remark text NOT NULL DEFAULT '' CHECK (char_length(remark)<=40),
 pinned_at timestamptz,
 last_opened_at timestamptz
);
CREATE TABLE public.conversation_open_days (
 membership_id uuid NOT NULL REFERENCES public.squad_members(id) ON DELETE CASCADE,
 opened_day date NOT NULL,
 open_count integer NOT NULL CHECK (open_count BETWEEN 1 AND 100),
 PRIMARY KEY(membership_id,opened_day)
);
ALTER TABLE public.conversation_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_open_days ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.conversation_preferences,public.conversation_open_days FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.conversation_preferences,public.conversation_open_days TO authenticated;
GRANT ALL ON public.conversation_preferences,public.conversation_open_days TO service_role;
CREATE POLICY preferences_owner ON public.conversation_preferences FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.squad_members m WHERE m.id=membership_id AND m.user_id=auth.uid()));
CREATE POLICY open_days_owner ON public.conversation_open_days FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.squad_members m WHERE m.id=membership_id AND m.user_id=auth.uid()));

CREATE FUNCTION public.get_conversation_preferences() RETURNS SETOF jsonb
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('squad_id',m.squad_id,'remark',coalesce(p.remark,''),
 'pinned_at',p.pinned_at,'last_opened_at',p.last_opened_at,'recent_open_count',
 coalesce((SELECT sum(d.open_count) FROM public.conversation_open_days d
 WHERE d.membership_id=m.id AND d.opened_day BETWEEN (now() AT TIME ZONE 'Asia/Shanghai')::date-6 AND (now() AT TIME ZONE 'Asia/Shanghai')::date),0))
 FROM public.squad_members m LEFT JOIN public.conversation_preferences p ON p.membership_id=m.id
 WHERE m.user_id=auth.uid();
$$;
CREATE FUNCTION public.save_conversation_preference(p_squad_id uuid,p_remark text,p_pinned boolean)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_member uuid;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 SELECT id INTO v_member FROM public.squad_members WHERE squad_id=p_squad_id AND user_id=auth.uid() FOR KEY SHARE;
 IF v_member IS NULL THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 IF p_remark IS NULL OR char_length(btrim(p_remark))>40 OR p_pinned IS NULL THEN RETURN jsonb_build_object('error','invalid'); END IF;
 INSERT INTO public.conversation_preferences(membership_id,remark,pinned_at)
 VALUES(v_member,btrim(p_remark),CASE WHEN p_pinned THEN now() END)
 ON CONFLICT(membership_id) DO UPDATE SET remark=excluded.remark,
 pinned_at=CASE WHEN p_pinned THEN coalesce(public.conversation_preferences.pinned_at,now()) ELSE NULL END;
 RETURN jsonb_build_object('saved',true);
END $$;
CREATE FUNCTION public.record_conversation_open(p_squad_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_member uuid; v_day date:=(now() AT TIME ZONE 'Asia/Shanghai')::date;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 SELECT id INTO v_member FROM public.squad_members WHERE squad_id=p_squad_id AND user_id=auth.uid() FOR KEY SHARE;
 IF v_member IS NULL THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 INSERT INTO public.conversation_preferences(membership_id,last_opened_at) VALUES(v_member,now())
 ON CONFLICT(membership_id) DO UPDATE SET last_opened_at=excluded.last_opened_at;
 INSERT INTO public.conversation_open_days(membership_id,opened_day,open_count) VALUES(v_member,v_day,1)
 ON CONFLICT(membership_id,opened_day) DO UPDATE SET open_count=least(100,public.conversation_open_days.open_count+1);
 DELETE FROM public.conversation_open_days WHERE membership_id=v_member AND opened_day<v_day-6;
 RETURN jsonb_build_object('saved',true);
END $$;

CREATE FUNCTION public.update_squad_profile(p_squad_id uuid,p_name text,p_description text,p_avatar text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_bytes bytea;
BEGIN
 IF auth.uid() IS NULL THEN RETURN jsonb_build_object('error','unauthenticated'); END IF;
 -- Match existing membership mutations' Squad-first lock order.
 PERFORM 1 FROM public.squads WHERE id=p_squad_id FOR UPDATE;
 PERFORM 1 FROM public.squad_members WHERE squad_id=p_squad_id AND user_id=auth.uid() AND role='captain' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('error','forbidden'); END IF;
 IF p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 1 AND 40 OR p_description IS NULL OR char_length(p_description)>200 THEN
 RETURN jsonb_build_object('error','invalid'); END IF;
 IF p_avatar IS NOT NULL THEN
  IF length(p_avatar)>65558 OR left(p_avatar,22)<>'data:image/png;base64,' THEN RETURN jsonb_build_object('error','invalid_avatar'); END IF;
  BEGIN v_bytes:=decode(substr(p_avatar,23),'base64'); EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('error','invalid_avatar'); END;
  IF octet_length(v_bytes) NOT BETWEEN 33 AND 49152 OR encode(substring(v_bytes FROM 1 FOR 24),'hex')<>'89504e470d0a1a0a0000000d494844520000006000000060' THEN
   RETURN jsonb_build_object('error','invalid_avatar'); END IF;
 END IF;
 UPDATE public.squads SET name=btrim(p_name),description=nullif(btrim(p_description),''),avatar_url=p_avatar WHERE id=p_squad_id;
 RETURN jsonb_build_object('saved',true);
END $$;
REVOKE ALL ON FUNCTION public.get_conversation_preferences(),public.save_conversation_preference(uuid,text,boolean),public.record_conversation_open(uuid),public.update_squad_profile(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.get_conversation_preferences(),public.save_conversation_preference(uuid,text,boolean),public.record_conversation_open(uuid),public.update_squad_profile(uuid,text,text,text) TO authenticated;
END
$migration$;
