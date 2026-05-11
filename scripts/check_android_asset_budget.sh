#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_PATH="${1:-$ROOT_DIR/builds/android/pixel_social_world-debug.apk}"
MAX_MB="${PSW_ANDROID_APK_MAX_MB:-220}"

if [[ "$APK_PATH" != /* ]]; then
	APK_PATH="$ROOT_DIR/$APK_PATH"
fi

if [[ ! -f "$APK_PATH" ]]; then
	printf 'Android APK is missing: %s\n' "$APK_PATH" >&2
	exit 1
fi

if ! command -v zipinfo >/dev/null 2>&1; then
	printf 'zipinfo is required to inspect Android APK payloads.\n' >&2
	exit 1
fi

file_size_bytes() {
	if stat -f%z "$1" >/dev/null 2>&1; then
		stat -f%z "$1"
	else
		stat -c%s "$1"
	fi
}

SIZE_BYTES="$(file_size_bytes "$APK_PATH")"
MAX_BYTES=$((MAX_MB * 1024 * 1024))
SIZE_MB="$(awk -v bytes="$SIZE_BYTES" 'BEGIN { printf "%.1f", bytes / 1024 / 1024 }')"

if (( SIZE_BYTES > MAX_BYTES )); then
	printf 'Android APK exceeds asset budget: %s MB > %s MB (%s)\n' "$SIZE_MB" "$MAX_MB" "$APK_PATH" >&2
	exit 1
fi

SOURCE_PAYLOAD_REGEX='(^|/)_source\.png$|_source\.png\.import$|assets/\.godot/imported/.*_source'
if zipinfo -1 "$APK_PATH" | grep -E "$SOURCE_PAYLOAD_REGEX" >/dev/null; then
	printf 'Android APK still contains generated source/master image payloads:\n' >&2
	zipinfo -1 "$APK_PATH" | grep -E "$SOURCE_PAYLOAD_REGEX" | sed -n '1,40p' >&2
	exit 1
fi

ANDROID_ONLY_REGEX='assets/\.godot/imported/launch_splash_forest_dawn_v1_|assets/assets/branding/generated/launch_splash_forest_dawn_v1_|assets/\.godot/imported/city_forest_dawn_v1_candidate_[abcd]|assets/assets/maps/generated/city_forest_dawn_v1_candidate_[abcd]\.png'
if zipinfo -1 "$APK_PATH" | grep -E "$ANDROID_ONLY_REGEX" >/dev/null; then
	printf 'Android APK still contains large non-runtime branding or retired map candidates:\n' >&2
	zipinfo -1 "$APK_PATH" | grep -E "$ANDROID_ONLY_REGEX" | sed -n '1,40p' >&2
	exit 1
fi

printf 'Android APK asset budget passed: %s MB <= %s MB (%s)\n' "$SIZE_MB" "$MAX_MB" "$APK_PATH"
