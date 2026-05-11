#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_ANDROID_UI_PANEL_SWEEP_ARTIFACT_DIR:-$ROOT_DIR/.tools/android-ui-panel-sweep}"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK_ROOT_VALUE/platform-tools/adb}"
PACKAGE_NAME="${PSW_ANDROID_PACKAGE_NAME:-com.pixelsocialworld.app}"
WAIT_SECONDS="${PSW_ANDROID_UI_PANEL_SWEEP_WAIT_SECONDS:-5}"
MIN_SCREENSHOT_BYTES="${PSW_ANDROID_UI_PANEL_SWEEP_MIN_SCREENSHOT_BYTES:-100000}"
STARTUP_FILE="android_debug_startup.json"
TMP_DIR="$ARTIFACT_DIR/tmp"
PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_sweep.json"
PROFILE_SWEEP="$TMP_DIR/player_profile.sweep.json"
LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_sweep.txt"
REPORT_FILE="$ARTIFACT_DIR/android-ui-panel-sweep.json"

if [[ "$ARTIFACT_DIR" != /* ]]; then
	ARTIFACT_DIR="$ROOT_DIR/$ARTIFACT_DIR"
	TMP_DIR="$ARTIFACT_DIR/tmp"
	PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_sweep.json"
	PROFILE_SWEEP="$TMP_DIR/player_profile.sweep.json"
	LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_sweep.txt"
	REPORT_FILE="$ARTIFACT_DIR/android-ui-panel-sweep.json"
fi

if [[ ! -x "$ADB_BIN" ]]; then
	ADB_BIN="$(command -v adb || true)"
fi
if [[ -z "$ADB_BIN" || ! -x "$ADB_BIN" ]]; then
	printf 'adb is not executable. Set ANDROID_SDK_ROOT or ADB_BIN.\n' >&2
	exit 1
fi

DEVICE_ID="${ANDROID_SERIAL:-}"
if [[ -z "$DEVICE_ID" ]]; then
	DEVICES=()
	while IFS= read -r device_id; do
		DEVICES+=("$device_id")
	done < <("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1 }')
	if [[ "${#DEVICES[@]}" -eq 0 ]]; then
		printf 'No Android device is connected and authorized.\n' >&2
		exit 1
	fi
	if [[ "${#DEVICES[@]}" -gt 1 ]]; then
		printf 'Multiple Android devices connected. Set ANDROID_SERIAL.\n' >&2
		printf '%s\n' "${DEVICES[@]}" >&2
		exit 1
	fi
	DEVICE_ID="${DEVICES[0]}"
fi
ADB=("$ADB_BIN" -s "$DEVICE_ID")

mkdir -p "$ARTIFACT_DIR" "$TMP_DIR"

if ! "${ADB[@]}" shell run-as "$PACKAGE_NAME" pwd >/dev/null 2>&1; then
	printf 'Package is not debuggable or not installed: %s\n' "$PACKAGE_NAME" >&2
	exit 1
fi

restore_profile() {
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" rm -f "files/$STARTUP_FILE" >/dev/null 2>&1 || true
	if [[ -s "$PROFILE_BACKUP" ]]; then
		"${ADB[@]}" push "$PROFILE_BACKUP" /data/local/tmp/psw_player_profile_restore.json >/dev/null
		"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_player_profile_restore.json files/player_profile.json >/dev/null
	fi
}
trap restore_profile EXIT

capture_screenshot() {
	local screenshot="$1"
	local attempt
	local bytes
	for attempt in $(seq 1 15); do
		"${ADB[@]}" exec-out screencap -p >"$screenshot"
		bytes="$(wc -c <"$screenshot" | tr -d ' ')"
		if [[ "$bytes" -ge "$MIN_SCREENSHOT_BYTES" ]]; then
			return 0
		fi
		sleep 1
	done
	printf 'screenshot stayed too small after retries: %s (%s bytes)\n' "$screenshot" "$bytes" >&2
	return 1
}

"${ADB[@]}" shell run-as "$PACKAGE_NAME" cat files/player_profile.json >"$PROFILE_BACKUP" 2>/dev/null || true

node - "$ROOT_DIR" "$PROFILE_BACKUP" "$PROFILE_SWEEP" <<'NODE'
const fs = require("fs");
const path = require("path");
const root = process.argv[2];
const backup = process.argv[3];
const out = process.argv[4];
const catalog = JSON.parse(fs.readFileSync(path.join(root, "configs/map_catalog.json"), "utf8"));
const allIds = catalog.maps.map((row) => row.id);
let profile = {};
if (fs.existsSync(backup) && fs.statSync(backup).size > 0) {
  profile = JSON.parse(fs.readFileSync(backup, "utf8"));
}
Object.assign(profile, {
  id: profile.id || "android-ui-panel-sweep",
  display_name: profile.display_name || "Guest",
  coin_balance: 17,
  current_route: "main_city",
  current_room_id: "world_town_square",
  current_world_map_id: "city_forest_dawn_v1",
  active_home_owner_id: profile.id || "android-ui-panel-sweep",
  active_home_visit_mode: false,
  owned_items: ["starter_wallpaper", "wooden_floor"],
  house_styles: { wall: "starter_wallpaper", floor: "wooden_floor" },
  house_items: [],
  discovered_world_map_ids: allIds,
  discovered_world_map_records: allIds.map((map_id, index) => ({
    map_id,
    source: "android_ui_panel_sweep",
    discovered_at: index,
  })),
  first_session_guide_completed_ids: ["npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"],
  first_session_guide_reward_claimed: true,
});
fs.writeFileSync(out, JSON.stringify(profile, null, "\t"));
NODE

"${ADB[@]}" push "$PROFILE_SWEEP" /data/local/tmp/psw_player_profile_sweep.json >/dev/null
"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_player_profile_sweep.json files/player_profile.json >/dev/null
"${ADB[@]}" logcat -c >/dev/null || true
: >"$LOGCAT_FILE"

node - "$TMP_DIR/cases.json" <<'NODE'
const fs = require("fs");
const out = process.argv[2];
const cases = [
  { name: "map-atlas", startup: { route: "main_city", map_id: "city_forest_dawn_v1", panel: "map_atlas" } },
  { name: "profile-card", startup: { route: "main_city", map_id: "city_forest_dawn_v1", panel: "profile" } },
  { name: "trade-facility", startup: { route: "main_city", map_id: "social_trade_market_v1", facility: "trade" } },
  { name: "housing-edit", startup: { route: "home_edit" } },
];
fs.writeFileSync(out, JSON.stringify(cases, null, 2));
NODE

printf 'Android UI panel sweep on %s\n' "$DEVICE_ID"

CASE_NAMES=()
while IFS= read -r case_name; do
	CASE_NAMES+=("$case_name")
done < <(node -e 'for (const item of require(process.argv[1])) console.log(item.name)' "$TMP_DIR/cases.json")
for case_name in "${CASE_NAMES[@]}"; do
	startup_json="$TMP_DIR/$STARTUP_FILE"
	node -e 'const fs=require("fs"); const cases=require(process.argv[1]); const name=process.argv[2]; const item=cases.find((row)=>row.name===name); fs.writeFileSync(process.argv[3], JSON.stringify(item.startup, null, 2));' "$TMP_DIR/cases.json" "$case_name" "$startup_json"
	"${ADB[@]}" push "$startup_json" /data/local/tmp/psw_android_debug_startup.json >/dev/null
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_android_debug_startup.json "files/$STARTUP_FILE" >/dev/null
	"${ADB[@]}" shell am force-stop "$PACKAGE_NAME" >/dev/null
	"${ADB[@]}" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
	sleep "$WAIT_SECONDS"
	screenshot="$ARTIFACT_DIR/$case_name.png"
	capture_screenshot "$screenshot"
	pid="$("${ADB[@]}" shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r' || true)"
	if [[ -n "$pid" ]]; then
		{
			printf '\n== %s pid %s ==\n' "$case_name" "$pid"
			"${ADB[@]}" logcat -d --pid="$pid" || true
		} >>"$LOGCAT_FILE"
	fi
	printf 'captured %s\n' "$case_name"
done

issues="$(rg -n -i '(FATAL EXCEPTION|ANR in|signal [0-9]+|panic|segmentation|crash|ERROR:|Godot.*ERROR| E AndroidRuntime)' "$LOGCAT_FILE" || true)"
if [[ -n "$issues" ]]; then
	printf '%s\n' "$issues" >"$ARTIFACT_DIR/logcat_issues.txt"
	printf 'Android UI panel sweep found logcat issues. See %s\n' "$ARTIFACT_DIR/logcat_issues.txt" >&2
	exit 1
fi

node - "$DEVICE_ID" "$ARTIFACT_DIR" "$REPORT_FILE" "${CASE_NAMES[@]}" <<'NODE'
const fs = require("fs");
const path = require("path");
const device = process.argv[2];
const dir = process.argv[3];
const report = process.argv[4];
const names = process.argv.slice(5);
fs.writeFileSync(report, JSON.stringify({
  schema_version: 1,
  device,
  case_count: names.length,
  cases: names.map((name) => ({ name, screenshot: path.join(dir, `${name}.png`) })),
  logcat: path.join(dir, "app_logcat_after_sweep.txt"),
}, null, 2));
NODE

printf 'Android UI panel sweep passed. Artifacts: %s\n' "$ARTIFACT_DIR"
