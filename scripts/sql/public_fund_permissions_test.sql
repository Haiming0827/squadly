BEGIN;
CREATE FUNCTION pg_temp.fund_test_id(i int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $$
  SELECT ('80000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid;
$$;
CREATE FUNCTION pg_temp.expect_fund_denied(statement text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN insufficient_privilege THEN RETURN;
  END;
  RAISE EXCEPTION 'Fund permission guard unexpectedly allowed a write';
END;
$$;
INSERT INTO auth.users(id) SELECT pg_temp.fund_test_id(i) FROM generate_series(1,3) i;
INSERT INTO public.squads(id,name,created_by,status) VALUES
  (pg_temp.fund_test_id(10),'Synthetic fund permissions',pg_temp.fund_test_id(1)::text,'active'),
  (pg_temp.fund_test_id(20),'Other synthetic fund squad',pg_temp.fund_test_id(3)::text,'pending');
INSERT INTO public.squad_members(squad_id,user_id,role) VALUES
  (pg_temp.fund_test_id(10),pg_temp.fund_test_id(1)::text,'captain'),
  (pg_temp.fund_test_id(10),pg_temp.fund_test_id(2)::text,'member'),
  (pg_temp.fund_test_id(20),pg_temp.fund_test_id(3)::text,'captain');

SET ROLE authenticated;
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.fund_test_id(1)::text)::text,false);
INSERT INTO public.public_funds(id,squad_id,name,fund_type,target_amount,created_by)
VALUES (pg_temp.fund_test_id(11),pg_temp.fund_test_id(10),'Synthetic fund','custom',100,pg_temp.fund_test_id(1)::text);
UPDATE public.public_funds SET name='Captain edited',target_amount=200
WHERE id=pg_temp.fund_test_id(11);
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.public_funds WHERE id=pg_temp.fund_test_id(11)
      AND name='Captain edited' AND target_amount=200 AND current_amount=0) THEN
    RAISE EXCEPTION 'Captain create/edit or zero balance default failed';
  END IF;
END $$;
SELECT pg_temp.expect_fund_denied(format('UPDATE public.public_funds SET current_amount=9 WHERE id=%L',pg_temp.fund_test_id(11)));
SELECT pg_temp.expect_fund_denied(format('UPDATE public.public_funds SET squad_id=%L WHERE id=%L',pg_temp.fund_test_id(20),pg_temp.fund_test_id(11)));
SELECT pg_temp.expect_fund_denied(format('UPDATE public.public_funds SET created_by=%L WHERE id=%L',pg_temp.fund_test_id(2)::text,pg_temp.fund_test_id(11)));
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.public_funds(squad_id,name,fund_type,current_amount,created_by) VALUES (%L,''Synthetic'',''custom'',0,%L)',pg_temp.fund_test_id(10),pg_temp.fund_test_id(1)::text));
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.public_funds(squad_id,name,fund_type,created_by) VALUES (%L,''Synthetic'',''custom'',%L)',pg_temp.fund_test_id(10),pg_temp.fund_test_id(2)::text));

SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.fund_test_id(2)::text)::text,false);
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.public_funds(squad_id,name,fund_type,created_by) VALUES (%L,''Synthetic'',''custom'',%L)',pg_temp.fund_test_id(10),pg_temp.fund_test_id(2)::text));
DO $$ DECLARE changed int; BEGIN
  UPDATE public.public_funds SET name='Member edit' WHERE id=pg_temp.fund_test_id(11);
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>0 THEN RAISE EXCEPTION 'Member edited captain-managed metadata'; END IF;
END $$;
SELECT pg_temp.expect_fund_denied(format('UPDATE public.public_funds SET current_amount=9 WHERE id=%L',pg_temp.fund_test_id(11)));
INSERT INTO public.fund_transactions(id,fund_id,user_id,amount,description)
VALUES (pg_temp.fund_test_id(12),pg_temp.fund_test_id(11),pg_temp.fund_test_id(2)::text,25,'Synthetic contribution'),
       (pg_temp.fund_test_id(13),pg_temp.fund_test_id(11),pg_temp.fund_test_id(2)::text,-5,'Synthetic expense');
DO $$ BEGIN
  IF (SELECT current_amount FROM public.public_funds WHERE id=pg_temp.fund_test_id(11))<>20 THEN
    RAISE EXCEPTION 'Member ledger balance trigger failed after column grants';
  END IF;
END $$;
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.fund_transactions(fund_id,user_id,amount) VALUES (%L,%L,1)',pg_temp.fund_test_id(11),pg_temp.fund_test_id(1)::text));
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.fund_transactions(fund_id,user_id,amount,approved_by) VALUES (%L,%L,1,%L)',pg_temp.fund_test_id(11),pg_temp.fund_test_id(2)::text,pg_temp.fund_test_id(1)::text));
INSERT INTO public.private_assets(user_id,asset_type,name,amount)
VALUES (pg_temp.fund_test_id(2)::text,'other','Synthetic private asset',0);

SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.fund_test_id(3)::text)::text,false);
DO $$ DECLARE changed int; BEGIN
  IF EXISTS(SELECT 1 FROM public.public_funds WHERE id=pg_temp.fund_test_id(11)) THEN
    RAISE EXCEPTION 'Nonmember read fund';
  END IF;
  UPDATE public.public_funds SET name='Other captain edit' WHERE id=pg_temp.fund_test_id(11);
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>0 THEN RAISE EXCEPTION 'Other Squad captain edited fund'; END IF;
  IF EXISTS(SELECT 1 FROM public.private_assets WHERE user_id=pg_temp.fund_test_id(2)::text) THEN
    RAISE EXCEPTION 'Private assets leaked';
  END IF;
END $$;
SELECT pg_temp.expect_fund_denied(format('INSERT INTO public.fund_transactions(fund_id,user_id,amount) VALUES (%L,%L,1)',pg_temp.fund_test_id(11),pg_temp.fund_test_id(3)::text));
SELECT set_config('request.jwt.claims',jsonb_build_object('sub',pg_temp.fund_test_id(1)::text)::text,false);
INSERT INTO public.fund_transactions(fund_id,user_id,amount)
VALUES (pg_temp.fund_test_id(11),pg_temp.fund_test_id(1)::text,10);
DO $$ BEGIN
  IF (SELECT current_amount FROM public.public_funds WHERE id=pg_temp.fund_test_id(11))<>30
      OR (SELECT sum(amount) FROM public.fund_transactions WHERE fund_id=pg_temp.fund_test_id(11))<>30 THEN
    RAISE EXCEPTION 'Captain ledger and total balance disagree';
  END IF;
END $$;
RESET ROLE;
ROLLBACK;
