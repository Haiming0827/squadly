#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s start|status|stop\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

action="$1"
if [[ "$action" != start && "$action" != status && "$action" != stop ]]; then
  usage
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! command -v tailscale >/dev/null 2>&1; then
  printf 'Tailscale CLI is not installed. Install and sign in to Tailscale on this Mac first.\n' >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  printf 'jq and curl are required.\n' >&2
  exit 2
fi

tailnet_status="$(tailscale status --json 2>/dev/null)" || {
  printf 'Tailscale is not connected. Sign in to the same private tailnet on this Mac and both test phones.\n' >&2
  exit 1
}
if [[ "$(jq -r '.BackendState // ""' <<<"$tailnet_status")" != "Running" ]]; then
  printf 'Tailscale is not connected. Sign in to the same private tailnet on this Mac and both test phones.\n' >&2
  exit 1
fi

tailnet_dns="$(jq -r '.Self.DNSName // "" | rtrimstr(".")' <<<"$tailnet_status")"
if [[ -z "$tailnet_dns" || "$tailnet_dns" != *.ts.net ]]; then
  printf 'Could not determine this Mac\x27s Tailscale MagicDNS hostname.\n' >&2
  exit 1
fi

local_config="$project_root/config/local-backend.tailscale.json"
local_api='http://127.0.0.1:54321'
secure_api="https://${tailnet_dns}:8443"
serve_status="$(tailscale serve status 2>&1 || true)"

case "$action" in
  status)
    printf '%s\n' "$serve_status"
    if curl --silent --show-error --fail --max-time 8 \
      "$secure_api/auth/v1/health" >/dev/null; then
      printf 'Local Supabase is reachable over private HTTPS: %s\n' "$secure_api"
    else
      printf 'Local Supabase is not reachable over private HTTPS at %s\n' "$secure_api"
      exit 1
    fi
    ;;
  start)
    if ! curl --silent --show-error --fail --max-time 5 \
      "$local_api/auth/v1/health" >/dev/null; then
      printf 'Local Supabase is not running. Start it with: npx --yes supabase@latest start\n' >&2
      exit 1
    fi
    if printf '%s\n' "$serve_status" | rg -q '(:8443)([ /]|$)'; then
      printf 'Tailscale Serve port 8443 is already configured. Nothing was changed; inspect it with "tailscale serve status".\n' >&2
      exit 1
    fi

    printf 'Starting Tailscale Serve on private HTTPS port 8443...\n'
    tailscale serve --bg --https=8443 127.0.0.1:54321

    reachable=false
    for attempt in {1..15}; do
      if curl --silent --show-error --fail --max-time 3 \
        "$secure_api/auth/v1/health" >/dev/null 2>&1; then
        reachable=true
        break
      fi
      sleep 2
    done
    if [[ "$reachable" != true ]]; then
      printf 'HTTPS endpoint did not become healthy. Check that HTTPS certificates are enabled for this tailnet and inspect "tailscale serve status".\n' >&2
      exit 1
    fi

    status_env="$(npx --yes supabase@latest status -o env)"
    anon_key="$(sed -n 's/^ANON_KEY="\([^"]*\)"$/\1/p' <<<"$status_env")"
    if [[ -z "$anon_key" ]]; then
      printf 'Could not read the local public Supabase key; tunnel is active, but local app config was not written.\n' >&2
      exit 1
    fi

    if [[ -e "$local_config" ]]; then
      if ! jq -e --arg url "$secure_api" --arg key "$anon_key" \
        '.SUPABASE_URL == $url and .SUPABASE_ANON_KEY == $key and .INVITE_LINK_BASE_URL == "" and (.USE_DEMO_BACKEND == "false" or .USE_DEMO_BACKEND == false)' \
        "$local_config" >/dev/null; then
        printf 'Existing local config differs from this tunnel. It was preserved; review %s before replacing it.\n' "$local_config" >&2
        exit 1
      fi
    else
      umask 077
      jq -n \
        --arg url "$secure_api" \
        --arg anonKey "$anon_key" \
        '{SUPABASE_URL:$url,SUPABASE_ANON_KEY:$anonKey,INVITE_LINK_BASE_URL:"",USE_DEMO_BACKEND:"false",MIPUSH_APP_ID:"",MIPUSH_APP_KEY:""}' \
        > "$local_config"
      chmod 600 "$local_config"
    fi

    printf '\nPrivate local backend is ready: %s\n' "$secure_api"
    printf 'Local build config: %s\n' "$local_config"
    printf 'Invitation links are intentionally disabled in this local mode; use invitation codes.\n'
    printf 'Both phones must be signed in to this same Tailscale tailnet. Do not enable Funnel.\n'
    ;;
  stop)
    if ! printf '%s\n' "$serve_status" | rg -q '(:8443)([ /]|$)'; then
      printf 'No Tailscale Serve endpoint is configured on port 8443.\n'
      exit 0
    fi
    if ! printf '%s\n' "$serve_status" | rg -Fq '127.0.0.1:54321'; then
      printf 'Port 8443 no longer points to the local Supabase API; refusing to change the current Serve configuration.\n' >&2
      exit 1
    fi
    tailscale serve --https=8443 127.0.0.1:54321 off
    printf 'Stopped the local HTTPS endpoint. The generated app config was kept at %s\n' "$local_config"
    ;;
esac
