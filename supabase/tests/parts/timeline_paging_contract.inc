-- A resumed app must not skip messages when more than one page arrived offline.
INSERT INTO public.squad_messages
  (squad_id, sender_id, kind, body, client_nonce, created_at)
SELECT s.id, '00000000-0000-4000-8000-000000000001'::uuid,
       'text', 'page-test-' || n, gen_random_uuid(),
       '2030-01-01 00:00:00+00'::timestamptz + n * interval '1 second'
FROM public.squads s CROSS JOIN generate_series(1, 121) AS n
WHERE s.name = '跑步小队';

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';

DO $$
DECLARE
  v_squad uuid;
  v_cursor_id uuid;
  v_cursor_at timestamptz;
  v_page jsonb[];
  v_last_id uuid;
  v_last_at timestamptz;
BEGIN
  SELECT id INTO v_squad FROM public.squads WHERE name = '跑步小队';
  SELECT id, created_at INTO v_cursor_id, v_cursor_at
    FROM public.squad_messages
    WHERE squad_id = v_squad AND body = 'page-test-1';

  SELECT array_agg(entry) INTO v_page FROM public.page_squad_timeline(
    v_squad, v_cursor_at, v_cursor_id, NULL, NULL, 50) AS entry;
  IF array_length(v_page, 1) <> 50
     OR v_page[1] ->> 'body' IS DISTINCT FROM 'page-test-2'
     OR v_page[50] ->> 'body' IS DISTINCT FROM 'page-test-51' THEN
    RAISE EXCEPTION 'first catch-up page skipped or reordered messages';
  END IF;

  v_last_id := (v_page[50] ->> 'id')::uuid;
  v_last_at := (v_page[50] ->> 'created_at')::timestamptz;
  SELECT array_agg(entry) INTO v_page FROM public.page_squad_timeline(
    v_squad, v_last_at, v_last_id, NULL, NULL, 50) AS entry;
  IF array_length(v_page, 1) <> 50
     OR v_page[1] ->> 'body' IS DISTINCT FROM 'page-test-52'
     OR v_page[50] ->> 'body' IS DISTINCT FROM 'page-test-101' THEN
    RAISE EXCEPTION 'second catch-up page skipped or reordered messages';
  END IF;
END;
$$;

RESET ROLE;
