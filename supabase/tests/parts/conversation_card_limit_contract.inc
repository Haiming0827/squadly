-- Run last: this adds seven authored messages to the registration fixture.
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';

DO $$
DECLARE
  v_squad_id uuid;
  v_ids jsonb := '[]'::jsonb;
  v_result jsonb;
  v_index int;
BEGIN
  SELECT id INTO v_squad_id FROM public.squads WHERE name = '跑步小队';
  IF v_squad_id IS NULL THEN RAISE EXCEPTION 'missing test squad'; END IF;

  FOR v_index IN 1..7 LOOP
    v_result := public.send_text_message(
      v_squad_id, '卡片素材 ' || v_index, gen_random_uuid(), NULL);
    v_ids := v_ids || jsonb_build_array(v_result ->> 'id');
  END LOOP;

  v_result := public.publish_card_message(
    v_squad_id, 'conversation',
    jsonb_build_object('selected_message_ids', v_ids - 6),
    'chat-classic', 1, gen_random_uuid());
  IF v_result ->> 'kind' IS DISTINCT FROM 'card' THEN
    RAISE EXCEPTION 'six own messages must be publishable';
  END IF;

  v_result := public.publish_card_message(
    v_squad_id, 'conversation',
    jsonb_build_object('selected_message_ids', v_ids),
    'chat-classic', 1, gen_random_uuid());
  IF v_result ->> 'error' IS DISTINCT FROM 'invalid_snapshot' THEN
    RAISE EXCEPTION 'seven messages bypassed RPC limit';
  END IF;
END;
$$;

RESET ROLE;

DO $$
DECLARE v_squad_id uuid;
BEGIN
  SELECT id INTO v_squad_id FROM public.squads WHERE name = '跑步小队';
  BEGIN
    INSERT INTO public.card_snapshots
      (id, squad_id, author_id, kind, snapshot, template_id, template_version)
    VALUES (
      gen_random_uuid(), v_squad_id,
      '00000000-0000-4000-8000-000000000001', 'conversation',
      jsonb_build_object('selected_message_ids',
        jsonb_build_array(1, 2, 3, 4, 5, 6, 7)),
      'chat-classic', 1);
    RAISE EXCEPTION 'direct insert bypassed card count constraint';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
END;
$$;
