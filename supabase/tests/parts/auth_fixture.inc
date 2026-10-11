-- Minimal Supabase Auth surface for isolated PostgreSQL contract tests.
-- This fixture must never be applied to a real Supabase project.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
END;
$$;

-- The Supabase PostgreSQL image may already provide GoTrue's auth schema.
-- Reuse that empty test schema when present; never drop the live GoTrue schema.
CREATE SCHEMA IF NOT EXISTS auth;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'auth' AND c.relname = 'users' AND c.relkind = 'r'
  ) THEN
    CREATE TABLE auth.users (
      id uuid PRIMARY KEY,
      email text,
      phone text,
      raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb
    );
  END IF;
  IF to_regprocedure('auth.uid()') IS NULL THEN
    EXECUTE $create_uid$
      CREATE FUNCTION auth.uid() RETURNS uuid
      LANGUAGE sql STABLE AS $uid$
        SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
      $uid$
    $create_uid$;
  END IF;
END;
$$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_namespace n
    JOIN pg_roles owner_role ON owner_role.oid = n.nspowner
    WHERE n.nspname = 'auth' AND owner_role.rolname = current_user
  ) OR EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper
  ) THEN
    GRANT USAGE ON SCHEMA auth TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
  END IF;
END;
$$;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Supabase's API roles normally receive table grants through default
-- privileges. Recreate that exposure so the repair migration must revoke it.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated;
