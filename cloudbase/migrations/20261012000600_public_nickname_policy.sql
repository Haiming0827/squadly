-- CloudBase PG adaptation of 006_public_nickname_policy.sql; see backend_cloudbase migration inventory.
-- Keep the API-side nickname rule enforceable even if a client bypasses Flutter.
-- Validation fails safely if legacy rows violate it; do not silently rename users.
ALTER TABLE public.profiles ADD CONSTRAINT profiles_public_nickname_valid
  CHECK (
    char_length(btrim(nickname)) BETWEEN 1 AND 60
    AND nickname = btrim(nickname)
    AND nickname !~ '[[:cntrl:]]'
  ) NOT VALID;
ALTER TABLE public.profiles VALIDATE CONSTRAINT profiles_public_nickname_valid;
