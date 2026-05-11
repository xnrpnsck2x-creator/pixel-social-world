#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_ANDROID_REGRESSION_ARTIFACT_DIR:-$ROOT_DIR/.tools/android-regression-current}"
APK_PATH="${1:-$ROOT_DIR/builds/android/pixel_social_world-debug.apk}"

RUN_PREFLIGHT="${PSW_ANDROID_REGRESSION_PREFLIGHT:-1}"
RUN_PLAYER_PATH="${PSW_ANDROID_REGRESSION_PLAYER_PATH:-1}"
RUN_UI_PANEL="${PSW_ANDROID_REGRESSION_UI_PANEL:-1}"
RUN_MAP_SWEEP="${PSW_ANDROID_REGRESSION_MAP_SWEEP:-1}"
RUN_INSTALL="${PSW_ANDROID_REGRESSION_INSTALL:-1}"
RUN_EXPORT="${PSW_ANDROID_REGRESSION_EXPORT:-auto}"
SKIP_READINESS="${PSW_ANDROID_REGRESSION_SKIP_READINESS:-1}"
SKIP_PREFLIGHT_MAP="${PSW_ANDROID_REGRESSION_SKIP_PREFLIGHT_MAP:-1}"
KEEP_TMP="${PSW_ANDROID_REGRESSION_KEEP_TMP:-0}"
REPORT_FILE="$ARTIFACT_DIR/android-device-regression.json"

if [[ "$APK_PATH" != /* ]]; then
	APK_PATH="$ROOT_DIR/$APK_PATH"
fi
if [[ "$ARTIFACT_DIR" != /* ]]; then
	ARTIFACT_DIR="$ROOT_DIR/$ARTIFACT_DIR"
	REPORT_FILE="$ARTIFACT_DIR/android-device-regression.json"
fi

mkdir -p "$ARTIFACT_DIR"

run_step() {
	local name="$1"
	shift
	echo "==> $name"
	"$@"
}

resolve_export_mode() {
	if [[ "$RUN_EXPORT" != "auto" ]]; then
		printf '%s\n' "$RUN_EXPORT"
		return
	fi
	if [[ -f "$APK_PATH" ]]; then
		printf '0\n'
	else
		printf '1\n'
	fi
}

cleanup_tmp() {
	if [[ "$KEEP_TMP" == "1" ]]; then
		return
	fi
	/bin/rm -rf "$ARTIFACT_DIR/player-path/tmp" "$ARTIFACT_DIR/ui-panel/tmp" "$ARTIFACT_DIR/map-sweep/tmp" "$ARTIFACT_DIR/preflight/map-quality-v2"
}

write_report() {
	node - "$ARTIFACT_DIR" "$REPORT_FILE" <<'NODE'
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const report = process.argv[3];
const readJson = (relativePath) => {
  const fullPath = path.join(root, relativePath);
  if (!fs.existsSync(fullPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(fullPath, "utf8"));
};

const player = readJson("player-path/android-player-path-sweep.json");
const ui = readJson("ui-panel/android-ui-panel-sweep.json");
const maps = readJson("map-sweep/android-map-sweep.json");
const device = player?.device || ui?.device || maps?.device || "";

fs.writeFileSync(report, JSON.stringify({
  schema_version: 1,
  generated_at: new Date().toISOString(),
  device,
  artifacts: {
    root,
    preflight: path.join(root, "preflight"),
    player_path: path.join(root, "player-path"),
    ui_panel: path.join(root, "ui-panel"),
    map_sweep: path.join(root, "map-sweep"),
    map_contact_sheet: maps?.contact_sheet || path.join(root, "map-sweep/contact-sheet.png"),
  },
  checks: {
    player_path_cases: player?.case_count || 0,
    ui_panel_cases: ui?.case_count || 0,
    map_count: maps?.map_count || 0,
  },
}, null, 2));
NODE
}

PREFLIGHT_EXPORT="$(resolve_export_mode)"

if [[ "$RUN_PREFLIGHT" == "1" ]]; then
	run_step "Android preflight install/launch" env \
		PSW_ANDROID_PREFLIGHT_EXPORT="$PREFLIGHT_EXPORT" \
		PSW_ANDROID_PREFLIGHT_INSTALL="$RUN_INSTALL" \
		PSW_ANDROID_PREFLIGHT_SKIP_READINESS="$SKIP_READINESS" \
		PSW_ANDROID_PREFLIGHT_SKIP_MAP_QUALITY="$SKIP_PREFLIGHT_MAP" \
		PSW_ANDROID_PREFLIGHT_ARTIFACT_DIR="$ARTIFACT_DIR/preflight" \
		"$ROOT_DIR/scripts/run_android_device_preflight.sh" "$APK_PATH"
fi

if [[ "$RUN_PLAYER_PATH" == "1" ]]; then
	run_step "Android player path sweep" env \
		PSW_ANDROID_PLAYER_PATH_SWEEP_ARTIFACT_DIR="$ARTIFACT_DIR/player-path" \
		"$ROOT_DIR/scripts/run_android_player_path_sweep.sh"
fi

if [[ "$RUN_UI_PANEL" == "1" ]]; then
	run_step "Android UI panel sweep" env \
		PSW_ANDROID_UI_PANEL_SWEEP_ARTIFACT_DIR="$ARTIFACT_DIR/ui-panel" \
		"$ROOT_DIR/scripts/run_android_ui_panel_sweep.sh"
fi

if [[ "$RUN_MAP_SWEEP" == "1" ]]; then
	run_step "Android 32-map sweep" env \
		PSW_ANDROID_MAP_SWEEP_ARTIFACT_DIR="$ARTIFACT_DIR/map-sweep" \
		"$ROOT_DIR/scripts/run_android_map_sweep.sh"
fi

cleanup_tmp
write_report

echo "Android device regression passed. Artifacts: $ARTIFACT_DIR"
echo "Report: $REPORT_FILE"
