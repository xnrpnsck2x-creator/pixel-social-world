#!/usr/bin/env bash
set -u

if [[ "${PSW_GODOT_SKIP_ADB_SERVER:-0}" == "1" ]]; then
	exit 0
fi

ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK_ROOT_VALUE/platform-tools/adb}"

if [[ ! -x "$ADB_BIN" ]]; then
	ADB_BIN="$(command -v adb || true)"
fi
if [[ -z "$ADB_BIN" || ! -x "$ADB_BIN" ]]; then
	exit 0
fi

LOCK_DIR="${TMPDIR:-/tmp}/psw-godot-adb-server.lock"
LOCK_ACQUIRED=0
for _ in $(seq 1 50); do
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		LOCK_ACQUIRED=1
		break
	fi
	sleep 0.1
done

cleanup() {
	if [[ "$LOCK_ACQUIRED" == "1" ]]; then
		rmdir "$LOCK_DIR" 2>/dev/null || true
	fi
}
trap cleanup EXIT

"$ADB_BIN" start-server >/dev/null 2>&1 || true
for _ in $(seq 1 5); do
	if "$ADB_BIN" devices >/dev/null 2>&1; then
		exit 0
	fi
	sleep 0.2
done
