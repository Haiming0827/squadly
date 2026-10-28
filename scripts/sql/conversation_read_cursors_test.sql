-- Synthetic isolated identities; assertions never print message contents.
BEGIN;
CREATE FUNCTION pg_temp.read_test_id(i int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT ('70000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid;
$$;
CREATE FUNCTION pg_temp.expect_read_error(statement text, expected_state text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = expected_state THEN RETURN; END IF;
    RAISE;
  END;
  RAISE EXCEPTION 'Read cursor guard unexpectedly allowed operation';
END;
$$;
INSERT INTO auth.users(id) SELECT pg_temp.read_test_id(i) FROM generate_series(1,4) i;
UPDATE public.profiles SET nickname = 'Read test member' WHERE id LIKE '70000000-%';
INSERT INTO public.squads(id,name,created_by,status) VALUES
  (pg_temp.read_test_id(10),'Read test squad',pg_temp.read_test_id(1)::text,'active'),
  (pg_temp.read_test_id(20),'Other read test squad',pg_temp.read_test_id(4)::text,'active');
INSERT INTO public.squad_members(id,squad_id,user_id,role,joined_at) VALUES
  (pg_temp.read_test_id(31),pg_temp.read_test_id(10),pg_temp.read_test_id(1)::text,'captain','2026-10-01'),
  (pg_temp.read_test_id(32),pg_temp.read_test_id(10),pg_temp.read_test_id(2)::text,'member','2026-10-01'),
  (pg_temp.read_test_id(33),pg_temp.read_test_id(10),pg_temp.read_test_id(3)::text,'member','2026-10-03'),
  (pg_temp.read_test_id(34),pg_temp.read_test_id(20),pg_temp.read_test_id(4)::text,'captain','2026-10-01');
INSERT INTO public.squad_plans(id,squad_id,title,category,visibility,created_by) VALUES
  (pg_temp.read_test_id(11),pg_temp.read_test_id(10),'Shared read plan','custom','squad',pg_temp.read_test_id(1)::text),
  (pg_temp.read_test_id(12),pg_temp.read_test_id(10),'Private read plan','custom','private',pg_temp.read_test_id(1)::text);
INSERT INTO public.squad_messages(id,squad_id,sender_id,kind,body,client_nonce,created_at,plan_id)
SELECT pg_temp.read_test_id(msg.id),pg_temp.read_test_id(msg.squad),pg_temp.read_test_id(msg.sender)::text,
  'text','Synthetic read test',pg_temp.read_test_id(msg.id+1000),msg.created::timestamptz,
  CASE WHEN msg.plan IS NULL THEN NULL ELSE pg_temp.read_test_id(msg.plan) END
FROM (VALUES
  (101,10,1,'2026-10-02 10:00:00+00',NULL::int),
  (102,10,1,'2026-10-02 10:00:00+00',NULL::int),
  (103,10,2,'2026-10-02 10:01:00+00',NULL::int),
  (104,10,1,'2026-10-05 10:00:00+00',NULL::int),
  (111,10,1,'2026-10-02 10:00:00+00',11),
  (112,10,1,'2026-10-02 10:00:00+00',12),
  (121,20,4,'2026-10-02 10:00:00+00',NULL::int)
) AS msg(id,squad,sender,created,plan);

SET ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.read_test_id(2)::text)::text,false);
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(102));
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(101));
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(102));
DO $$
BEGIN
  IF (SELECT read_message_id FROM public.conversation_read_cursors) <> pg_temp.read_test_id(102) THEN
    RAISE EXCEPTION 'Cursor regressed or timestamp tie skipped';
  END IF;
END $$;
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(111),pg_temp.read_test_id(11));
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(111)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(101),pg_temp.read_test_id(11)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(112),pg_temp.read_test_id(12)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(121)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L]::uuid[])',pg_temp.read_test_id(10),pg_temp.read_test_id(101)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L]::uuid[],%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(112),pg_temp.read_test_id(12)),'42501');
SELECT pg_temp.expect_read_error('UPDATE public.conversation_read_cursors SET read_message_id = read_message_id','42501');
SELECT pg_temp.expect_read_error('DELETE FROM public.conversation_read_cursors','42501');
SELECT pg_temp.expect_read_error(format('INSERT INTO public.conversation_read_cursors(membership_id,squad_id,read_message_created_at,read_message_id) VALUES (%L,%L,now(),%L)',pg_temp.read_test_id(31),pg_temp.read_test_id(10),pg_temp.read_test_id(104)),'42501');

SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.read_test_id(1)::text)::text,false);
DO $$
DECLARE r jsonb; member jsonb;
BEGIN
  IF EXISTS(SELECT 1 FROM public.conversation_read_cursors) THEN
    RAISE EXCEPTION 'Author could read another member raw cursor';
  END IF;
  FOR r IN SELECT * FROM public.get_message_read_receipts(pg_temp.read_test_id(10),ARRAY[pg_temp.read_test_id(101),pg_temp.read_test_id(102)]) LOOP
    IF (SELECT count(*) FROM jsonb_object_keys(r)) <> 2 OR jsonb_array_length(r->'members') <> 2 THEN
      RAISE EXCEPTION 'Receipt leaked fields or omitted current members';
    END IF;
    FOR member IN SELECT * FROM jsonb_array_elements(r->'members') LOOP
      IF member->>'user_id' = pg_temp.read_test_id(2)::text AND member->>'status' <> 'read' THEN
        RAISE EXCEPTION 'Read cursor did not cover older/equal message';
      END IF;
      IF member->>'user_id' = pg_temp.read_test_id(3)::text AND member->>'status' <> 'not_applicable' THEN
        RAISE EXCEPTION 'New member counted against pre-join message';
      END IF;
      IF (SELECT count(*) FROM jsonb_object_keys(member)) <> 4 THEN RAISE EXCEPTION 'Raw cursor exposed'; END IF;
    END LOOP;
  END LOOP;
  SELECT x INTO r FROM public.get_message_read_receipts(pg_temp.read_test_id(10),ARRAY[pg_temp.read_test_id(112)],pg_temp.read_test_id(12)) x;
  IF r->'members' <> '[]'::jsonb THEN RAISE EXCEPTION 'Private plan disclosed other members'; END IF;
END $$;
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L,%L]::uuid[])',pg_temp.read_test_id(10),pg_temp.read_test_id(101),pg_temp.read_test_id(103)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L,%L]::uuid[])',pg_temp.read_test_id(10),pg_temp.read_test_id(101),pg_temp.read_test_id(101)),'22023');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[]::uuid[])',pg_temp.read_test_id(10)),'22023');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY(SELECT pg_temp.read_test_id(i) FROM generate_series(100,150)i))',pg_temp.read_test_id(10)),'22023');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[NULL]::uuid[])',pg_temp.read_test_id(10)),'22023');
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(102));
SELECT public.advance_conversation_read_cursor(pg_temp.read_test_id(10),pg_temp.read_test_id(111),pg_temp.read_test_id(11));

SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.read_test_id(4)::text)::text,false);
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(101)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L]::uuid[])',pg_temp.read_test_id(10),pg_temp.read_test_id(101)),'42501');
RESET ROLE;
DELETE FROM public.squad_members WHERE id = pg_temp.read_test_id(32);
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM public.conversation_read_cursors WHERE membership_id=pg_temp.read_test_id(32)) THEN
    RAISE EXCEPTION 'Removed member retained cursors';
  END IF;
END $$;
INSERT INTO public.squad_members(id,squad_id,user_id,role,joined_at) VALUES
  (pg_temp.read_test_id(42),pg_temp.read_test_id(10),pg_temp.read_test_id(2)::text,'member','2026-10-04');
DELETE FROM public.squad_messages WHERE id=pg_temp.read_test_id(102);
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.conversation_read_cursors WHERE membership_id=pg_temp.read_test_id(31) AND read_message_id=pg_temp.read_test_id(102)) THEN
    RAISE EXCEPTION 'Deleting a message removed acknowledged cursor';
  END IF;
END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.read_test_id(1)::text)::text,false);
DO $$ DECLARE r jsonb; BEGIN
  SELECT x INTO r FROM public.get_message_read_receipts(pg_temp.read_test_id(10),ARRAY[pg_temp.read_test_id(101)]) x;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'members') m WHERE m->>'membership_id'=pg_temp.read_test_id(42)::text AND m->>'status'='not_applicable') THEN
    RAISE EXCEPTION 'Rejoin inherited old receipts';
  END IF;
  SELECT x INTO r FROM public.get_message_read_receipts(pg_temp.read_test_id(10),ARRAY[pg_temp.read_test_id(104)]) x;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r->'members') m WHERE m->>'user_id'=pg_temp.read_test_id(2)::text AND m->>'status'='unread') THEN
    RAISE EXCEPTION 'New membership falsely read new messages';
  END IF;
END $$;
SET ROLE anon;
SELECT pg_temp.expect_read_error('SELECT * FROM public.conversation_read_cursors','42501');
SELECT pg_temp.expect_read_error(format('SELECT public.advance_conversation_read_cursor(%L,%L)',pg_temp.read_test_id(10),pg_temp.read_test_id(101)),'42501');
SELECT pg_temp.expect_read_error(format('SELECT * FROM public.get_message_read_receipts(%L,ARRAY[%L]::uuid[])',pg_temp.read_test_id(10),pg_temp.read_test_id(101)),'42501');
RESET ROLE;
DELETE FROM public.squad_plans WHERE id=pg_temp.read_test_id(11);
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM public.conversation_read_cursors WHERE plan_id=pg_temp.read_test_id(11)) THEN
    RAISE EXCEPTION 'Deleted plan retained cursors';
  END IF;
END $$;
ROLLBACK;
