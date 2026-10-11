-- Profile edits are own-account only; contact columns stay outside API grants.
DO $$
BEGIN
  IF has_column_privilege('authenticated', 'public.profiles', 'phone', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.profiles', 'email', 'UPDATE') THEN
    RAISE EXCEPTION 'contact fields writable via public profile';
  END IF;
END;
$$;

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
DO $$
DECLARE v_count int;
BEGIN
  UPDATE public.profiles SET nickname = '越权改名'
    WHERE id = '00000000-0000-4000-8000-000000000001';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 0 THEN RAISE EXCEPTION 'teammate edited another profile'; END IF;
END;
$$;

SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
DO $$
DECLARE v_count int;
BEGIN
  UPDATE public.profiles SET nickname = '晨跑阿青'
    WHERE id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 1 THEN RAISE EXCEPTION 'owner could not edit nickname'; END IF;
  BEGIN
    UPDATE public.profiles SET nickname = '' WHERE id = auth.uid();
    RAISE EXCEPTION 'empty nickname passed DB constraint';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE public.profiles SET nickname = repeat('跑', 61)
      WHERE id = auth.uid();
    RAISE EXCEPTION 'overlong nickname passed DB constraint';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$$;
RESET ROLE;
