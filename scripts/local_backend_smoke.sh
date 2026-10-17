#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' \
  'This local Supabase smoke script is retired; the CloudBase PG backend has no local Supabase-compatible emulator.' \
  'Create or select a dedicated CloudBase PG staging environment with: bash scripts/setup_cloudbase_staging.sh' \
  'For migration and real-account acceptance steps, see docs/modules/backend_cloudbase/migration-runbook.md.' >&2
exit 2
