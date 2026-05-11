#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_ANDROID_PREFLIGHT_ARTIFACT_DIR:-$ROOT_DIR/.tools/android-device-preflight}"
APK_PATH="${1:-$ROOT_DIR/builds/android/pixel_social_world-debug.apk}"

RUN_EXPORT="${PSW_ANDROID_PREFLIGHT_EXPORT:-1}"
RUN_INSTALL="${PSW_ANDROID_PREFLIGHT_INSTALL:-0}"
SKIP_READINESS="${PSW_ANDROID_PREFLIGHT_SKIP_READINESS:-0}"
SKIP_MAP_QUALITY="${PSW_ANDROID_PREFLIGHT_SKIP_MAP_QUALITY:-0}"
MAP_SKIP_H5="${PSW_ANDROID_PREFLIGHT_MAP_SKIP_H5:-1}"
SKIP_APK_BUDGET="${PSW_ANDROID_PREFLIGHT_SKIP_APK_BUDGET:-0}"

if [[ "$APK_PATH" != /* ]]; then
	APK_PATH="$ROOT_DIR/$APK_PATH"
fi

mkdir -p "$ARTIFACT_DIR"

run_step() {
	local name="$1"
	shift
	echo "==> $name"
	"$@"
}

if [[ "$SKIP_READINESS" != "1" ]]; then
	run_step "mobile export readiness" "$ROOT_DIR/scripts/check_mobile_export_readiness.sh"
fi

if [[ "$SKIP_MAP_QUALITY" != "1" ]]; then
	run_step "map quality v2 android preflight" bash -lc "PSW_MAP_QUALITY_V2_SKIP_H5='$MAP_SKIP_H5' PSW_MAP_QUALITY_V2_ARTIFACT_DIR='$ARTIFACT_DIR/map-quality-v2' '$ROOT_DIR/scripts/run_map_quality_v2_gate.sh'"
fi

if [[ "$RUN_EXPORT" == "1" ]]; then
	run_step "Android debug APK export" "$ROOT_DIR/scripts/export_android_debug_local.sh" "$APK_PATH"
elif [[ "$SKIP_APK_BUDGET" != "1" && -f "$APK_PATH" ]]; then
	run_step "existing Android APK asset budget" "$ROOT_DIR/scripts/check_android_asset_budget.sh" "$APK_PATH"
elif [[ "$SKIP_APK_BUDGET" != "1" ]]; then
	echo "==> existing Android APK asset budget"
	echo "skip: APK does not exist yet: $APK_PATH"
fi

if [[ "$RUN_INSTALL" == "1" ]]; then
	run_step "Android device install and launch" "$ROOT_DIR/scripts/install_android_debug_local.sh" "$APK_PATH"
fi

echo "Android device preflight passed. Artifacts: $ARTIFACT_DIR"
