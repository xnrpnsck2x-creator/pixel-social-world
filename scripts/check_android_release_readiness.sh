#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_PRESETS="$ROOT_DIR/export_presets.cfg"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ANDROID_BUILD_TOOLS_VERSION="${ANDROID_BUILD_TOOLS_VERSION:-35.0.1}"
ANDROID_BUILD_TOOLS_DIR="${ANDROID_BUILD_TOOLS_DIR:-$ANDROID_SDK_ROOT_VALUE/build-tools/$ANDROID_BUILD_TOOLS_VERSION}"
RELEASE_FORMAT="${PSW_ANDROID_RELEASE_FORMAT:-apk}"
SIGNING_REQUIRED="${PSW_ANDROID_RELEASE_SIGNING_REQUIRED:-0}"

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

resolve_java_home() {
	if [[ -n "${PSW_JAVA_HOME:-}" ]]; then
		printf '%s' "$PSW_JAVA_HOME"
	elif [[ -n "${JAVA_HOME:-}" ]]; then
		printf '%s' "$JAVA_HOME"
	elif [[ -x "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/java" ]]; then
		printf '%s' "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
	elif [[ -x "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home/bin/java" ]]; then
		printf '%s' "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
	fi
}

resolve_keytool() {
	local java_home
	java_home="$(resolve_java_home)"
	if [[ -n "$java_home" && -x "$java_home/bin/keytool" ]]; then
		printf '%s' "$java_home/bin/keytool"
	elif command -v keytool >/dev/null 2>&1; then
		command -v keytool
	fi
}

check_no_export_secrets() {
	if grep -Eq '^(keystore/(debug|debug_user|debug_password|release|release_user|release_password)|application/(app_store_team_id|provisioning_profile_uuid_debug|provisioning_profile_uuid_release|provisioning_profile_specifier_debug|provisioning_profile_specifier_release))="[^"]+"' "$EXPORT_PRESETS"; then
		fail "export_presets.cfg contains signing credentials or provisioning values"
	else
		pass "export_presets.cfg keeps signing credentials empty"
	fi
}

check_android_preset_contract() {
	if [[ ! -f "$EXPORT_PRESETS" ]]; then
		fail "export_presets.cfg is missing"
		return
	fi

	has_preset_value '^platform="Android"$' && pass "Android export preset exists" || fail "Android export preset is missing"
	has_preset_value '^package/unique_name="com\.pixelsocialworld\.app"$' && pass "Android package id is stable" || fail "Android package id is not com.pixelsocialworld.app"
	has_preset_value '^package/signed=true$' && pass "Android package signing is enabled" || fail "Android package signing is not enabled"
	has_preset_value '^permissions/internet=true$' && pass "Android internet permission is enabled" || fail "Android internet permission is missing"
	check_no_export_secrets

	case "$RELEASE_FORMAT" in
		apk)
			has_preset_value '^export_path="builds/android/[^"]+\.apk"$' && pass "release export path targets APK" || fail "release export path is not an APK"
			;;
		aab)
			has_preset_value '^gradle_build/use_gradle_build=true$' && pass "Gradle build is enabled for AAB" || fail "AAB export requires gradle_build/use_gradle_build=true"
			has_preset_value '^gradle_build/export_format=1$' && pass "Android export format is AAB" || fail "AAB export requires gradle_build/export_format=1"
			has_preset_value '^export_path="builds/android/[^"]+\.aab"$' && pass "release export path targets AAB" || fail "release export path is not an AAB"
			;;
		*)
			fail "unsupported PSW_ANDROID_RELEASE_FORMAT: $RELEASE_FORMAT"
			;;
	esac
}

check_android_release_tools() {
	local java_home java_path
	java_home="$(resolve_java_home)"
	java_path="${java_home:+$java_home/bin/java}"

	if [[ -n "$java_path" && -x "$java_path" ]] && "$java_path" -version >/dev/null 2>&1; then
		pass "Java runtime is usable"
	else
		fail "Java runtime is unavailable"
	fi

	if [[ -x "$ANDROID_BUILD_TOOLS_DIR/zipalign" ]]; then
		pass "zipalign is executable"
	else
		fail "zipalign is missing: $ANDROID_BUILD_TOOLS_DIR/zipalign"
	fi

	if [[ -x "$ANDROID_BUILD_TOOLS_DIR/apksigner" ]]; then
		pass "apksigner is executable"
	else
		fail "apksigner is missing: $ANDROID_BUILD_TOOLS_DIR/apksigner"
	fi

	if [[ -n "$(resolve_keytool)" ]]; then
		pass "keytool is available"
	else
		fail "keytool is unavailable"
	fi
}

check_release_signing_env() {
	local keystore="${ANDROID_RELEASE_KEYSTORE:-}"
	local alias="${ANDROID_RELEASE_KEYSTORE_USER:-}"
	local store_pass="${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}"
	local keytool_bin real_keystore

	if [[ -z "$keystore" && -z "$alias" && -z "$store_pass" ]]; then
		if [[ "$SIGNING_REQUIRED" == "1" ]]; then
			fail "Android release signing env is required but not configured"
		else
			pass "Android release signing env is external and currently unset"
		fi
		return
	fi

	if [[ -z "$keystore" || -z "$alias" || -z "$store_pass" ]]; then
		fail "Android release signing env is partial; set ANDROID_RELEASE_KEYSTORE, ANDROID_RELEASE_KEYSTORE_USER, and ANDROID_RELEASE_KEYSTORE_PASSWORD together"
		return
	fi

	if [[ "$keystore" != /* ]]; then
		fail "ANDROID_RELEASE_KEYSTORE must be an absolute path outside the repo"
		return
	fi

	if [[ ! -f "$keystore" ]]; then
		fail "Android release keystore file is missing: $keystore"
		return
	fi

	real_keystore="$(cd "$(dirname "$keystore")" && pwd -P)/$(basename "$keystore")"
	case "$real_keystore" in
		"$ROOT_DIR"/*)
			fail "Android release keystore must not live inside the repository"
			return
			;;
		*)
			pass "Android release keystore lives outside the repository"
			;;
	esac

	keytool_bin="$(resolve_keytool)"
	if [[ -z "$keytool_bin" ]]; then
		fail "cannot verify release keystore alias because keytool is unavailable"
		return
	fi

	if ANDROID_RELEASE_KEYSTORE_PASSWORD="$store_pass" "$keytool_bin" -list -keystore "$keystore" -storepass:env ANDROID_RELEASE_KEYSTORE_PASSWORD -alias "$alias" >/dev/null 2>&1; then
		pass "Android release keystore alias is readable"
	else
		fail "Android release keystore alias is not readable"
	fi

	if [[ -z "${ANDROID_RELEASE_KEY_PASSWORD:-}" ]]; then
		warn "ANDROID_RELEASE_KEY_PASSWORD is not set; release export must use the store password or configure key password externally"
	else
		pass "Android release key password env is set"
	fi
}

check_android_preset_contract
check_android_release_tools
check_release_signing_env

printf '\nAndroid release readiness: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
