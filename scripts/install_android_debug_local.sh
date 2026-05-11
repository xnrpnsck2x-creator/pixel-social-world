#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK_ROOT_VALUE/platform-tools/adb}"
APK_PATH="${1:-$ROOT_DIR/builds/android/pixel_social_world-debug.apk}"
PACKAGE_NAME="${PSW_ANDROID_PACKAGE_NAME:-com.pixelsocialworld.app}"

if [[ ! -x "$ADB_BIN" ]]; then
	ADB_BIN="$(command -v adb || true)"
fi
if [[ -z "$ADB_BIN" || ! -x "$ADB_BIN" ]]; then
	printf 'adb is not executable. Set ANDROID_SDK_ROOT or ADB_BIN.\n' >&2
	exit 1
fi
if [[ ! -f "$APK_PATH" ]]; then
	printf 'APK is missing: %s\n' "$APK_PATH" >&2
	printf 'Run scripts/export_android_debug_local.sh first.\n' >&2
	exit 1
fi

DEVICES=()
while IFS= read -r device_id; do
	DEVICES+=("$device_id")
done < <("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1 }')
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
	DEVICES=("$ANDROID_SERIAL")
fi
if [[ "${#DEVICES[@]}" -eq 0 ]]; then
	printf 'No Android device is connected and authorized.\n' >&2
	exit 1
fi
if [[ "${#DEVICES[@]}" -gt 1 && -z "${ANDROID_SERIAL:-}" ]]; then
	printf 'Multiple Android devices connected. Set ANDROID_SERIAL.\n' >&2
	printf '%s\n' "${DEVICES[@]}" >&2
	exit 1
fi

"$ADB_BIN" -s "${DEVICES[0]}" install -r "$APK_PATH"
"$ADB_BIN" -s "${DEVICES[0]}" shell monkey -p "$PACKAGE_NAME" 1 >/dev/null
printf 'Installed and launched %s on %s\n' "$PACKAGE_NAME" "${DEVICES[0]}"
