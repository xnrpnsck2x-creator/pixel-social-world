#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_ANDROID_MAP_SWEEP_ARTIFACT_DIR:-$ROOT_DIR/.tools/android-map-sweep}"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK_ROOT_VALUE/platform-tools/adb}"
PACKAGE_NAME="${PSW_ANDROID_PACKAGE_NAME:-com.pixelsocialworld.app}"
MAPS_CSV="${PSW_ANDROID_MAP_SWEEP_MAPS:-}"
WAIT_SECONDS="${PSW_ANDROID_MAP_SWEEP_WAIT_SECONDS:-5}"
MIN_SCREENSHOT_BYTES="${PSW_ANDROID_MAP_SWEEP_MIN_SCREENSHOT_BYTES:-100000}"
STARTUP_FILE="android_debug_startup.json"
TMP_DIR="$ARTIFACT_DIR/tmp"
PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_sweep.json"
PROFILE_SWEEP="$TMP_DIR/player_profile.sweep.json"
LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_sweep.txt"
REPORT_FILE="$ARTIFACT_DIR/android-map-sweep.json"

if [[ "$ARTIFACT_DIR" != /* ]]; then
	ARTIFACT_DIR="$ROOT_DIR/$ARTIFACT_DIR"
	TMP_DIR="$ARTIFACT_DIR/tmp"
	PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_sweep.json"
	PROFILE_SWEEP="$TMP_DIR/player_profile.sweep.json"
	LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_sweep.txt"
	REPORT_FILE="$ARTIFACT_DIR/android-map-sweep.json"
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

node - "$ROOT_DIR" "$PROFILE_BACKUP" "$PROFILE_SWEEP" "$MAPS_CSV" <<'NODE'
const fs = require("fs");
const path = require("path");
const root = process.argv[2];
const backup = process.argv[3];
const out = process.argv[4];
const mapsCsv = process.argv[5] || "";
const catalog = JSON.parse(fs.readFileSync(path.join(root, "configs/map_catalog.json"), "utf8"));
const allIds = catalog.maps.map((row) => row.id);
const selected = mapsCsv.trim()
  ? mapsCsv.split(",").map((value) => value.trim()).filter(Boolean)
  : allIds;
const unknown = selected.filter((id) => !allIds.includes(id));
if (unknown.length > 0) {
  throw new Error(`Unknown map id(s): ${unknown.join(", ")}`);
}
let profile = {};
if (fs.existsSync(backup) && fs.statSync(backup).size > 0) {
  profile = JSON.parse(fs.readFileSync(backup, "utf8"));
}
profile.id = profile.id || "android-map-sweep";
profile.display_name = profile.display_name || "Guest";
profile.current_route = "main_city";
profile.current_room_id = "world_town_square";
profile.current_world_map_id = "city_forest_dawn_v1";
profile.discovered_world_map_ids = allIds;
profile.discovered_world_map_records = allIds.map((map_id, index) => ({
  map_id,
  source: "android_map_sweep",
  discovered_at: index
}));
profile.first_session_guide_completed_ids = ["npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"];
profile.first_session_guide_reward_claimed = true;
fs.writeFileSync(out, JSON.stringify(profile, null, "\t"));
fs.writeFileSync(path.join(path.dirname(out), "maps.json"), JSON.stringify(selected, null, 2));
NODE

"${ADB[@]}" push "$PROFILE_SWEEP" /data/local/tmp/psw_player_profile_sweep.json >/dev/null
"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_player_profile_sweep.json files/player_profile.json >/dev/null
"${ADB[@]}" logcat -c >/dev/null || true
: >"$LOGCAT_FILE"

MAP_IDS=()
while IFS= read -r map_id; do
	MAP_IDS+=("$map_id")
done < <(node -e 'for (const id of require(process.argv[1])) console.log(id)' "$TMP_DIR/maps.json")
if [[ "${#MAP_IDS[@]}" -eq 0 ]]; then
	printf 'No maps selected for Android map sweep.\n' >&2
	exit 1
fi
printf 'Android map sweep on %s: %d map(s)\n' "$DEVICE_ID" "${#MAP_IDS[@]}"

screenshots=()
for map_id in "${MAP_IDS[@]}"; do
	startup_json="$TMP_DIR/$STARTUP_FILE"
	node -e 'const fs=require("fs"); fs.writeFileSync(process.argv[2], JSON.stringify({route:"main_city", map_id:process.argv[1]}, null, 2));' "$map_id" "$startup_json"
	"${ADB[@]}" push "$startup_json" /data/local/tmp/psw_android_debug_startup.json >/dev/null
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_android_debug_startup.json "files/$STARTUP_FILE" >/dev/null
	"${ADB[@]}" shell am force-stop "$PACKAGE_NAME" >/dev/null
	"${ADB[@]}" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
	for _ in $(seq 1 30); do
		current="$("${ADB[@]}" shell run-as "$PACKAGE_NAME" cat files/player_profile.json 2>/dev/null | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { try { console.log(JSON.parse(s).current_world_map_id || ""); } catch { console.log(""); } });' | tr -d '\r')"
		if [[ "$current" == "$map_id" ]]; then
			break
		fi
		sleep 0.25
	done
	sleep "$WAIT_SECONDS"
	safe_name="${map_id//[^A-Za-z0-9_]/_}"
	screenshot="$ARTIFACT_DIR/map-$safe_name.png"
	capture_screenshot "$screenshot"
	pid="$("${ADB[@]}" shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r' || true)"
	if [[ -n "$pid" ]]; then
		{
			printf '\n== %s pid %s ==\n' "$map_id" "$pid"
			"${ADB[@]}" logcat -d --pid="$pid" || true
		} >>"$LOGCAT_FILE"
	fi
	screenshots+=("$screenshot")
	printf 'captured %s\n' "$map_id"
done

issues="$(rg -n -i '(FATAL EXCEPTION|ANR in|signal [0-9]+|panic|segmentation|crash|ERROR:|Godot.*ERROR| E AndroidRuntime)' "$LOGCAT_FILE" || true)"
if [[ -n "$issues" ]]; then
	printf '%s\n' "$issues" >"$ARTIFACT_DIR/logcat_issues.txt"
	printf 'Android map sweep found logcat issues. See %s\n' "$ARTIFACT_DIR/logcat_issues.txt" >&2
	exit 1
fi

if command -v ffmpeg >/dev/null && [[ "${#screenshots[@]}" -gt 0 ]]; then
	ffmpeg -y -pattern_type glob -i "$ARTIFACT_DIR/map-*.png" \
		-vf "scale=640:-1,tile=4x8:padding=8:margin=8:color=0x20242cff" \
		-frames:v 1 "$ARTIFACT_DIR/contact-sheet.png" >/dev/null 2>&1 || true
fi

node - "$DEVICE_ID" "$ARTIFACT_DIR" "$REPORT_FILE" "${MAP_IDS[@]}" <<'NODE'
const fs = require("fs");
const path = require("path");
const device = process.argv[2];
const dir = process.argv[3];
const report = process.argv[4];
const maps = process.argv.slice(5);
const rows = maps.map((map_id) => ({
  map_id,
  screenshot: path.join(dir, `map-${map_id.replace(/[^A-Za-z0-9_]/g, "_")}.png`)
}));
fs.writeFileSync(report, JSON.stringify({
  schema_version: 1,
  device,
  map_count: rows.length,
  maps: rows,
  logcat: path.join(dir, "app_logcat_after_sweep.txt"),
  contact_sheet: path.join(dir, "contact-sheet.png")
}, null, 2));
NODE

printf 'Android map sweep passed. Artifacts: %s\n' "$ARTIFACT_DIR"
