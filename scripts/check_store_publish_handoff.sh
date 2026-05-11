#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/docs/StorePublishHandoff.md"
EXPORT_PRESETS="$ROOT_DIR/export_presets.cfg"
STORE_BRANDING="$ROOT_DIR/configs/store_branding.json"
STRICT_REQUIRED="${PSW_STORE_PUBLISH_REQUIRED:-0}"

fail_count=0
warn_count=0

pass() {
	printf '[pass] %s\n' "$1"
}

warn() {
	warn_count=$((warn_count + 1))
	printf '[warn] %s\n' "$1"
}

fail() {
	fail_count=$((fail_count + 1))
	printf '[fail] %s\n' "$1"
}

require_file_nonempty() {
	local path="$1"
	if [[ -s "$ROOT_DIR/$path" ]]; then
		pass "$path exists"
	else
		fail "$path is missing or empty"
	fi
}

require_doc_text() {
	local text="$1"
	local label="$2"
	if grep -Fq "$text" "$DOC"; then
		pass "$label"
	else
		fail "publish handoff doc missing: $label"
	fi
}

require_preset_value() {
	local pattern="$1"
	local label="$2"
	if grep -Eq "$pattern" "$EXPORT_PRESETS"; then
		pass "$label"
	else
		fail "export preset missing: $label"
	fi
}

require_json_text() {
	local pattern="$1"
	local label="$2"
	if grep -Fq "$pattern" "$STORE_BRANDING"; then
		pass "$label"
	else
		fail "store branding missing: $label"
	fi
}

run_required_command() {
	local label="$1"
	shift
	local output
	if output="$("$@" 2>&1)"; then
		pass "$label passes"
	else
		fail "$label failed"
		printf '%s\n' "$output"
	fi
}

require_env_value() {
	local name="$1"
	local value="${!name:-}"
	if [[ -n "$value" && "$value" != *"<"* && "$value" != *"example.com"* ]]; then
		pass "$name is set"
	else
		fail "$name is missing or placeholder"
	fi
}

require_https_env() {
	local name="$1"
	local value="${!name:-}"
	if [[ "$value" =~ ^https://[^[:space:]]+$ ]] && [[ "$value" != *"example.com"* ]]; then
		pass "$name is an HTTPS URL"
	else
		fail "$name must be a non-placeholder HTTPS URL"
	fi
}

require_email_env() {
	local name="$1"
	local value="${!name:-}"
	if [[ "$value" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] && [[ "$value" != *"example.com"* ]]; then
		pass "$name is set"
	else
		fail "$name must be a non-placeholder email"
	fi
}

require_flag_one() {
	local name="$1"
	if [[ "${!name:-}" == "1" ]]; then
		pass "$name=1"
	else
		fail "$name must be 1"
	fi
}

check_doc_contract() {
	require_file_nonempty "docs/StorePublishHandoff.md"
	require_file_nonempty "docs/NativeReleaseHandoffRunbook.md"
	require_file_nonempty "docs/StoreAuthProviderHandoff.md"
	require_file_nonempty "docs/MobileExportReadiness.md"
	require_file_nonempty "configs/store_branding.json"
	require_file_nonempty "export_presets.cfg"
	require_file_nonempty "scripts/check_ios_release_readiness.sh"
	require_file_nonempty "scripts/check_android_release_readiness.sh"
	require_file_nonempty "scripts/check_native_release_handoff.sh"

	require_doc_text "https://developer.apple.com/app-store/submitting/" "Apple submission source"
	require_doc_text "https://developer.apple.com/news/upcoming-requirements/" "Apple upload requirements source"
	require_doc_text "Xcode 26" "Apple Xcode 26 requirement"
	require_doc_text "iOS 26 SDK" "Apple iOS 26 SDK requirement"
	require_doc_text "https://developer.android.com/guide/app-bundle" "Android App Bundle source"
	require_doc_text "https://support.google.com/googleplay/android-developer/answer/11926878" "Google target API source"
	require_doc_text "Data safety" "Google Data safety evidence"
	require_doc_text "app access" "Google app access evidence"
	require_doc_text "Content rating" "Google content rating evidence"
	require_doc_text "Target audience" "Google target audience evidence"
	require_doc_text "User-generated content" "UGC moderation evidence"
	require_doc_text ".tools/store-publish-handoff/" "store publish evidence path"
	require_doc_text "PSW_STORE_PUBLISH_REQUIRED=1" "strict publish flag"
	require_doc_text "PSW_APPLE_CONNECT_APP_ID" "Apple app id env"
	require_doc_text "PSW_APPLE_PRIVACY_POLICY_URL" "Apple privacy URL env"
	require_doc_text "PSW_GOOGLE_PLAY_APP_ID" "Google app id env"
	require_doc_text "PSW_GOOGLE_DATA_SAFETY_READY" "Google Data safety env"
	require_doc_text "PSW_GOOGLE_CONTENT_RATING_READY" "Google content rating env"
	require_doc_text "PSW_GOOGLE_TARGET_AUDIENCE_READY" "Google target audience env"
}

check_export_contract() {
	require_preset_value '^name="iOS"$' "iOS preset exists"
	require_preset_value '^application/bundle_identifier="com\.pixelsocialworld\.app"$' "iOS bundle id is stable"
	require_preset_value '^application/short_version="0\.1\.0"$' "iOS marketing version is stable"
	require_preset_value '^application/version="1"$' "iOS build number is stable"
	require_preset_value '^icons/icon_1024x1024="res://assets/branding/generated/app_icon_forest_dawn_v1_1024\.png"$' "iOS store icon is wired"

	require_preset_value '^name="Android"$' "Android APK preset exists"
	require_preset_value '^export_path="builds/android/pixel_social_world\.apk"$' "Android APK export path is stable"
	require_preset_value '^name="Android Play AAB"$' "Android Play AAB preset exists"
	require_preset_value '^gradle_build/use_gradle_build=true$' "Android Play AAB uses Gradle"
	require_preset_value '^gradle_build/export_format=1$' "Android Play AAB export format is AAB"
	require_preset_value '^gradle_build/target_sdk=35$' "Android Play AAB target SDK is 35"
	require_preset_value '^export_path="builds/android/pixel_social_world\.aab"$' "Android Play AAB export path is stable"
	require_preset_value '^package/unique_name="com\.pixelsocialworld\.app"$' "Android package id is stable"
	require_preset_value '^version/code=1$' "Android version code is stable"
	require_preset_value '^version/name="0\.1\.0"$' "Android version name is stable"
	require_preset_value '^permissions/internet=true$' "Android internet permission is enabled"

	if grep -Eq '^(keystore/(debug|debug_user|debug_password|release|release_user|release_password)|application/(app_store_team_id|code_sign_identity_debug|code_sign_identity_release|provisioning_profile_uuid_debug|provisioning_profile_uuid_release|provisioning_profile_specifier_debug|provisioning_profile_specifier_release))="[^"]+"' "$EXPORT_PRESETS"; then
		fail "export_presets.cfg contains signing credentials or provisioning values"
	else
		pass "export presets keep signing credentials empty"
	fi
}

check_store_branding_contract() {
	require_json_text "branding.icon.ios_1024" "iOS icon branding record"
	require_json_text "branding.icon.android_main_192" "Android launcher icon branding record"
	require_json_text "branding.icon.android_adaptive_foreground_432" "Android adaptive foreground branding record"
	require_json_text "branding.icon.android_adaptive_background_432" "Android adaptive background branding record"
	require_json_text "branding.splash.ios_2x" "iOS 2x splash branding record"
	require_json_text "Image 2" "Image 2 generation policy"

	local paths=(
		"assets/branding/generated/app_icon_forest_dawn_v1_1024.png"
		"assets/branding/generated/launcher_icon_forest_dawn_v1_192.png"
		"assets/branding/generated/adaptive_foreground_forest_dawn_v1_432.png"
		"assets/branding/generated/adaptive_background_forest_dawn_v1_432.png"
		"assets/branding/generated/launch_splash_forest_dawn_v1_2048x1152.png"
		"assets/branding/generated/launch_splash_forest_dawn_v1_2732x1536.png"
	)
	local path
	for path in "${paths[@]}"; do
		if [[ -f "$ROOT_DIR/$path" ]]; then
			pass "$path exists"
		else
			fail "$path is missing"
		fi
	done
}

check_no_committed_store_secrets() {
	local tracked_secret_paths
	tracked_secret_paths="$(git -C "$ROOT_DIR" ls-files | grep -E '(AuthKey_.*\.p8|service.*account.*\.json|google.*play.*\.json|\.jks$|\.keystore$|\.mobileprovision$)' || true)"
	if [[ -z "$tracked_secret_paths" ]]; then
		pass "no tracked store signing key/service-account files"
	else
		fail "tracked store secret-looking files found"
		printf '%s\n' "$tracked_secret_paths"
	fi

	local secret_assignments
	secret_assignments="$(git -C "$ROOT_DIR" grep -nE '(APP_STORE_CONNECT_API_KEY|GOOGLE_PLAY_SERVICE_ACCOUNT_JSON|ANDROID_RELEASE_KEYSTORE_PASSWORD|ANDROID_RELEASE_KEY_PASSWORD|IOS_CODE_SIGN_IDENTITY_RELEASE)=([^<[:space:]]|\"[^<])' -- configs backend export_presets.cfg || true)"
	if [[ -z "$secret_assignments" ]]; then
		pass "no committed store secret assignments"
	else
		fail "store secret-looking assignments found"
		printf '%s\n' "$secret_assignments"
	fi
}

check_strict_env() {
	require_env_value "PSW_APPLE_CONNECT_APP_ID"
	require_https_env "PSW_APPLE_PRIVACY_POLICY_URL"
	require_email_env "PSW_APPLE_REVIEW_CONTACT_EMAIL"
	require_flag_one "PSW_APPLE_APP_PRIVACY_READY"
	require_flag_one "PSW_APPLE_AGE_RATING_READY"
	require_flag_one "PSW_APPLE_REVIEW_NOTES_READY"
	require_flag_one "PSW_APPLE_TESTFLIGHT_READY"

	if [[ "${PSW_GOOGLE_PLAY_APP_ID:-}" == "com.pixelsocialworld.app" ]]; then
		pass "PSW_GOOGLE_PLAY_APP_ID matches package id"
	else
		fail "PSW_GOOGLE_PLAY_APP_ID must be com.pixelsocialworld.app"
	fi
	require_https_env "PSW_GOOGLE_PRIVACY_POLICY_URL"
	require_flag_one "PSW_GOOGLE_DATA_SAFETY_READY"
	require_flag_one "PSW_GOOGLE_CONTENT_RATING_READY"
	require_flag_one "PSW_GOOGLE_TARGET_AUDIENCE_READY"
	require_flag_one "PSW_GOOGLE_APP_ACCESS_READY"
	require_flag_one "PSW_GOOGLE_CLOSED_TESTING_READY"
}

check_strict_mode_fails_closed_when_unset() {
	if [[ "$STRICT_REQUIRED" == "1" ]]; then
		check_strict_env
		return
	fi
	if [[ "${PSW_STORE_PUBLISH_SELFTEST:-0}" == "1" ]]; then
		return
	fi

	local output
	if output="$(PSW_STORE_PUBLISH_REQUIRED=1 PSW_STORE_PUBLISH_SELFTEST=1 "$0" 2>&1)"; then
		fail "strict store publish mode unexpectedly passed without store env"
		printf '%s\n' "$output"
	else
		pass "strict store publish mode fails closed without store env"
	fi
}

check_doc_contract
check_export_contract
check_store_branding_contract
check_no_committed_store_secrets
run_required_command "iOS release readiness default contract" "$ROOT_DIR/scripts/check_ios_release_readiness.sh"
run_required_command "Android APK release readiness default contract" "$ROOT_DIR/scripts/check_android_release_readiness.sh"
run_required_command "Android AAB release readiness default contract" env PSW_ANDROID_RELEASE_FORMAT=aab "$ROOT_DIR/scripts/check_android_release_readiness.sh"
check_strict_mode_fails_closed_when_unset

if [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
	pass "store publish handoff has no warnings"
elif [[ "$fail_count" -eq 0 ]]; then
	warn "store publish handoff passed with warnings"
fi

printf '\nStore publish handoff: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
