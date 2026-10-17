#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s validate|android|ios|all [config-file]\n' "$0"
  printf 'Default config: config/test-backend.local.json\n'
  printf 'For iOS IPA, set IOS_EXPORT_OPTIONS_PLIST to an existing ExportOptions.plist.\n'
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

target="$1"
if [[ "$target" != validate && "$target" != android && "$target" != ios && "$target" != all ]]; then
  usage
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${2:-$project_root/config/test-backend.local.json}"
if [[ ! -f "$config_file" ]]; then
  printf 'Missing config file: %s\nUse scripts/setup_cloudbase_staging.sh or copy config/test-backend.example.json and fill CloudBase staging values.\n' "$config_file" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required to validate the local test config.\n' >&2
  exit 2
fi

if [[ "$config_file" == *.env ]]; then
  source_env_file="$config_file"
  config_file="$(mktemp "${TMPDIR:-/tmp}/squadly-cloudbase-config.XXXXXX")"
  trap 'unlink "$config_file"' EXIT

  cloudbase_env_id=""
  cloudbase_region="ap-shanghai"
  cloudbase_publishable_key=""
  invite_link_base_url=""
  use_demo_backend="false"
  mipush_app_id=""
  mipush_app_key=""
  while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
    [[ -z "${key:-}" || "$key" == \#* ]] && continue
    case "$key" in
      CLOUDBASE_ENV_ID) cloudbase_env_id="$value" ;;
      CLOUDBASE_REGION) cloudbase_region="$value" ;;
      CLOUDBASE_PUBLISHABLE_KEY) cloudbase_publishable_key="$value" ;;
      INVITE_LINK_BASE_URL) invite_link_base_url="$value" ;;
      USE_DEMO_BACKEND) use_demo_backend="$value" ;;
      MIPUSH_APP_ID) mipush_app_id="$value" ;;
      MIPUSH_APP_KEY) mipush_app_key="$value" ;;
      *) printf 'Unsupported config key in %s: %s\n' "$source_env_file" "$key" >&2; exit 2 ;;
    esac
  done < "$source_env_file"

  jq -n \
    --arg envId "$cloudbase_env_id" \
    --arg region "$cloudbase_region" \
    --arg publishableKey "$cloudbase_publishable_key" \
    --arg inviteLinkBaseUrl "$invite_link_base_url" \
    --arg useDemoBackend "$use_demo_backend" \
    --arg mipushAppId "$mipush_app_id" \
    --arg mipushAppKey "$mipush_app_key" \
    '{CLOUDBASE_ENV_ID:$envId,CLOUDBASE_REGION:$region,CLOUDBASE_PUBLISHABLE_KEY:$publishableKey,INVITE_LINK_BASE_URL:$inviteLinkBaseUrl,USE_DEMO_BACKEND:$useDemoBackend,MIPUSH_APP_ID:$mipushAppId,MIPUSH_APP_KEY:$mipushAppKey}' \
    > "$config_file"
fi

if ! jq -e '
  (.CLOUDBASE_ENV_ID | type == "string" and test("^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$") and (contains("replace-with") | not)) and
  (.CLOUDBASE_REGION | type == "string" and IN("ap-shanghai", "ap-singapore")) and
  (.CLOUDBASE_PUBLISHABLE_KEY | type == "string" and length > 20 and (contains("replace-with") | not) and (test("secretkey|secret_key|service_role|service-role"; "i") | not)) and
  ((.INVITE_LINK_BASE_URL | type == "string" and test("^https://[^/?#]+/?$") and (contains("replace-with") | not)) or
   (.INVITE_LINK_BASE_URL == "")) and
  (.USE_DEMO_BACKEND == "false" or .USE_DEMO_BACKEND == false)
' "$config_file" >/dev/null; then
  printf 'Config must contain a CloudBase environment ID, supported region, public Publishable Key, USE_DEMO_BACKEND=false, and either an HTTPS invite domain or an empty domain to disable invite links.\n' >&2
  exit 2
fi

if [[ "$(jq -r '.INVITE_LINK_BASE_URL' "$config_file")" == "" ]]; then
  printf 'Invitation links are disabled for this build; use invitation codes.\n'
fi

mipush_app_id="$(jq -r '.MIPUSH_APP_ID // ""' "$config_file")"
mipush_app_key="$(jq -r '.MIPUSH_APP_KEY // ""' "$config_file")"
if [[ -n "$mipush_app_id" || -n "$mipush_app_key" ]]; then
  if [[ ! "$mipush_app_id" =~ ^[A-Za-z0-9_-]+$ || ! "$mipush_app_key" =~ ^[A-Za-z0-9_-]+$ ]]; then
    printf 'MIPUSH_APP_ID and MIPUSH_APP_KEY must both be set to valid Xiaomi developer values, or both be omitted.\n' >&2
    exit 2
  fi
  if [[ ! -f "$project_root/android/app/libs/MiPush_SDK_Client.aar" ]] && ! compgen -G "$project_root/android/app/libs/MiPush_SDK_Client*.aar" >/dev/null; then
    printf 'Mi Push credentials are present but the official Xiaomi AAR is missing from android/app/libs/.\n' >&2
    exit 2
  fi
fi

if [[ "$target" == validate ]]; then
  printf 'CloudBase test package configuration is valid. No build was started.\n'
  exit 0
fi

cd "$project_root"
flutter pub get
flutter analyze
# Current tests do not require bundled assets. This also prevents a stale
# shader bundle from a different Flutter SDK in build/unit_test_assets.
flutter test --no-test-assets
flutter test --no-test-assets --dart-define-from-file="$config_file" \
  --dart-define=USE_DEMO_BACKEND=false \
  test/app/real_mode_router_test.dart \
  test/features/auth/presentation/auth_recovery_state_test.dart

if [[ "$target" == android || "$target" == all ]]; then
  mipush_gradle_args=()
  if [[ -n "$mipush_app_id" ]]; then
    mipush_gradle_args+=("-P MIPUSH_APP_ID=$mipush_app_id" "-P MIPUSH_APP_KEY=$mipush_app_key")
    flutter build apk --debug --dart-define-from-file="$config_file" "${mipush_gradle_args[@]}"
  else
    flutter build apk --debug --dart-define-from-file="$config_file"
  fi
  printf 'Android test APK: %s/build/app/outputs/flutter-apk/app-debug.apk\n' "$project_root"
  printf 'This debug-signed APK is for direct test-device installation, not store release.\n'
fi

if [[ "$target" == ios || "$target" == all ]]; then
  export_options="${IOS_EXPORT_OPTIONS_PLIST:-}"
  if [[ -z "$export_options" || ! -f "$export_options" ]]; then
    printf 'iOS IPA needs IOS_EXPORT_OPTIONS_PLIST pointing to a valid signing/export plist.\n' >&2
    exit 2
  fi
  flutter build ipa --release --export-options-plist="$export_options" --dart-define-from-file="$config_file"
  printf 'iOS IPA directory: %s/build/ios/ipa\n' "$project_root"
fi
