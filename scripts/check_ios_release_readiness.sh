#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_PRESETS="$ROOT_DIR/export_presets.cfg"
SIGNING_REQUIRED="${PSW_IOS_RELEASE_SIGNING_REQUIRED:-0}"

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

has_preset_value() {
	local pattern="$1"
	grep -Eq "$pattern" "$EXPORT_PRESETS"
}

resolve_xcode_developer_dir() {
	local selected_dir
	selected_dir="$(xcode-select -p 2>/dev/null || true)"

	if [[ -n "${PSW_XCODE_DEVELOPER_DIR:-}" ]]; then
		printf '%s' "$PSW_XCODE_DEVELOPER_DIR"
	elif [[ -n "${DEVELOPER_DIR:-}" ]]; then
		printf '%s' "$DEVELOPER_DIR"
	elif [[ "$selected_dir" == *"/Xcode.app/"* ]]; then
		printf '%s' "$selected_dir"
	elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
		printf '%s' "/Applications/Xcode.app/Contents/Developer"
	else
		printf '%s' "$selected_dir"
	fi
}

check_no_export_secrets() {
	if grep -Eq '^(keystore/(debug|debug_user|debug_password|release|release_user|release_password)|application/(app_store_team_id|code_sign_identity_debug|code_sign_identity_release|provisioning_profile_uuid_debug|provisioning_profile_uuid_release|provisioning_profile_specifier_debug|provisioning_profile_specifier_release))="[^"]+"' "$EXPORT_PRESETS"; then
		fail "export_presets.cfg contains signing credentials or provisioning values"
	else
		pass "export_presets.cfg keeps iOS signing values empty"
	fi
}

check_ios_preset_contract() {
	if [[ ! -f "$EXPORT_PRESETS" ]]; then
		fail "export_presets.cfg is missing"
		return
	fi

	has_preset_value '^platform="iOS"$' && pass "iOS export preset exists" || fail "iOS export preset is missing"
	has_preset_value '^export_path="builds/ios/[^"]+\.zip"$' && pass "iOS export path targets zip" || fail "iOS export path is not a zip"
	has_preset_value '^architectures/arm64=true$' && pass "iOS arm64 architecture is enabled" || fail "iOS arm64 architecture is not enabled"
	has_preset_value '^application/bundle_identifier="com\.pixelsocialworld\.app"$' && pass "iOS bundle id is stable" || fail "iOS bundle id is not com.pixelsocialworld.app"
	has_preset_value '^application/short_version="0\.1\.0"$' && pass "iOS short version is set" || fail "iOS short version is not 0.1.0"
	has_preset_value '^application/version="[0-9][0-9]*"$' && pass "iOS build version is numeric" || fail "iOS build version is not numeric"
	has_preset_value '^application/min_ios_version="13\.0"$' && pass "iOS minimum version is set" || fail "iOS minimum version is not 13.0"
	has_preset_value '^icons/icon_1024x1024="res://assets/branding/generated/app_icon_forest_dawn_v1_1024\.png"$' && pass "iOS store icon is wired" || fail "iOS store icon is not wired"
	check_no_export_secrets
}

check_ios_toolchain() {
	local developer_dir
	developer_dir="$(resolve_xcode_developer_dir)"

	if [[ -n "$developer_dir" && "$developer_dir" == *"/Xcode"*.app/Contents/Developer && -d "$developer_dir" ]]; then
		pass "Xcode developer directory is full Xcode"
	else
		fail "Xcode developer directory is not full Xcode: ${developer_dir:-unset}"
	fi

	if DEVELOPER_DIR="$developer_dir" xcodebuild -version >/dev/null 2>&1; then
		pass "xcodebuild is usable"
	else
		fail "xcodebuild is not usable"
	fi

	if DEVELOPER_DIR="$developer_dir" xcrun --sdk iphoneos --show-sdk-version >/dev/null 2>&1; then
		pass "iphoneos SDK is available"
	else
		fail "iphoneos SDK is unavailable"
	fi

	if DEVELOPER_DIR="$developer_dir" xcrun --find codesign >/dev/null 2>&1 || command -v codesign >/dev/null 2>&1; then
		pass "codesign is available"
	else
		fail "codesign is unavailable"
	fi

	if command -v security >/dev/null 2>&1; then
		pass "security keychain tool is available"
	else
		fail "security keychain tool is unavailable"
	fi
}

check_release_signing_env() {
	local team_id="${IOS_TEAM_ID:-}"
	local bundle_id="${IOS_BUNDLE_ID:-}"
	local identity="${IOS_CODE_SIGN_IDENTITY_RELEASE:-}"
	local profile_uuid="${IOS_PROVISIONING_PROFILE_UUID_RELEASE:-}"
	local profile_specifier="${IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE:-}"
	local signing_values=("$team_id" "$bundle_id" "$identity" "$profile_uuid" "$profile_specifier")
	local configured_count=0

	for value in "${signing_values[@]}"; do
		if [[ -n "$value" ]]; then
			configured_count=$((configured_count + 1))
		fi
	done

	if [[ "$configured_count" -eq 0 ]]; then
		if [[ "$SIGNING_REQUIRED" == "1" ]]; then
			fail "iOS release signing env is required but not configured"
		else
			pass "iOS release signing env is external and currently unset"
		fi
		return
	fi

	[[ -n "$team_id" ]] && pass "IOS_TEAM_ID is set" || fail "IOS_TEAM_ID is missing"
	[[ -n "$bundle_id" ]] && pass "IOS_BUNDLE_ID is set" || fail "IOS_BUNDLE_ID is missing"
	[[ -n "$identity" ]] && pass "IOS_CODE_SIGN_IDENTITY_RELEASE is set" || fail "IOS_CODE_SIGN_IDENTITY_RELEASE is missing"

	if [[ -n "$profile_uuid" || -n "$profile_specifier" ]]; then
		pass "iOS release provisioning profile env is set"
	else
		fail "set IOS_PROVISIONING_PROFILE_UUID_RELEASE or IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE"
	fi

	if [[ -n "$bundle_id" && "$bundle_id" != "com.pixelsocialworld.app" ]]; then
		warn "IOS_BUNDLE_ID differs from the committed preset bundle id"
	fi

	if [[ -n "$identity" ]]; then
		if security find-identity -v -p codesigning 2>/dev/null | grep -F "$identity" >/dev/null; then
			pass "iOS signing identity is present in keychain"
		else
			fail "iOS signing identity is not present in keychain"
		fi
	fi
}

check_ios_preset_contract
check_ios_toolchain
check_release_signing_env

printf '\niOS release readiness: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
