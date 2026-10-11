#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s android|ios|all [config-file]\n' "$0"
  printf 'Default config: config/test-backend.local.json\n'
  printf 'For iOS IPA, set IOS_EXPORT_OPTIONS_PLIST to an existing ExportOptions.plist.\n'
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

target="$1"
if [[ "$target" != android && "$target" != ios && "$target" != all ]]; then
  usage
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_file="${2:-$project_root/config/test-backend.local.json}"
if [[ ! -f "$config_file" ]]; then
  printf 'Missing config file: %s\nCopy config/test-backend.example.json to the local path and fill staging values.\n' "$config_file" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'jq is required to validate the local test config.\n' >&2
  exit 2
fi

if ! jq -e '
  (.SUPABASE_URL | type == "string" and startswith("https://") and (contains("replace-with") | not)) and
  (.SUPABASE_ANON_KEY | type == "string" and length > 20 and (contains("replace-with") | not)) and
  (.INVITE_LINK_BASE_URL | type == "string" and test("^https://[^/?#]+/?$") and (contains("replace-with") | not)) and
  (.USE_DEMO_BACKEND == "false" or .USE_DEMO_BACKEND == false)
' "$config_file" >/dev/null; then
  printf 'Config must contain a real staging URL, publishable key, HTTPS invite-link domain, and USE_DEMO_BACKEND=false.\n' >&2
  exit 2
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

cd "$project_root"
flutter pub get
flutter analyze
# Current tests do not require bundled assets. This also prevents a stale
# shader bundle from a different Flutter SDK in build/unit_test_assets.
flutter test --no-test-assets
flutter test --no-test-assets --dart-define=USE_DEMO_BACKEND=false \
  test/app/real_mode_router_test.dart \
  test/features/auth/presentation/auth_recovery_state_test.dart

if [[ "$target" == android || "$target" == all ]]; then
  mipush_gradle_args=()
  if [[ -n "$mipush_app_id" ]]; then
    mipush_gradle_args+=("-P MIPUSH_APP_ID=$mipush_app_id" "-P MIPUSH_APP_KEY=$mipush_app_key")
  fi
  flutter build apk --debug --dart-define-from-file="$config_file" "${mipush_gradle_args[@]}"
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
