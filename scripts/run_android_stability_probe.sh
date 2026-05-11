#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${PSW_ANDROID_STABILITY_ARTIFACT_DIR:-$ROOT_DIR/.tools/android-stability-current}"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK_ROOT_VALUE/platform-tools/adb}"
PACKAGE_NAME="${PSW_ANDROID_PACKAGE_NAME:-com.pixelsocialworld.app}"
DURATION_SECONDS="${PSW_ANDROID_STABILITY_DURATION_SECONDS:-600}"
ROUTE_INTERVAL_SECONDS="${PSW_ANDROID_STABILITY_ROUTE_INTERVAL_SECONDS:-60}"
SAMPLE_INTERVAL_SECONDS="${PSW_ANDROID_STABILITY_SAMPLE_INTERVAL_SECONDS:-10}"
ROUTE_SETTLE_SECONDS="${PSW_ANDROID_STABILITY_ROUTE_SETTLE_SECONDS:-5}"
MIN_SCREENSHOT_BYTES="${PSW_ANDROID_STABILITY_MIN_SCREENSHOT_BYTES:-100000}"
CASES_JSON="${PSW_ANDROID_STABILITY_CASES_JSON:-}"
KEEP_TMP="${PSW_ANDROID_STABILITY_KEEP_TMP:-0}"
SKIP_BUDGET="${PSW_ANDROID_STABILITY_SKIP_BUDGET:-0}"
STARTUP_FILE="android_debug_startup.json"
TMP_DIR="$ARTIFACT_DIR/tmp"
PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_stability.json"
PROFILE_STABILITY="$TMP_DIR/player_profile.stability.json"
DEFAULT_CASES_JSON="$TMP_DIR/stability_cases.json"
SAMPLES_TSV="$ARTIFACT_DIR/stability_samples.tsv"
REPORT_FILE="$ARTIFACT_DIR/android-stability-report.json"
LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_stability.txt"
SUMMARY_FILE="$ARTIFACT_DIR/android-stability-summary.txt"

if [[ "$ARTIFACT_DIR" != /* ]]; then
	ARTIFACT_DIR="$ROOT_DIR/$ARTIFACT_DIR"
	TMP_DIR="$ARTIFACT_DIR/tmp"
	PROFILE_BACKUP="$ARTIFACT_DIR/player_profile.before_stability.json"
	PROFILE_STABILITY="$TMP_DIR/player_profile.stability.json"
	DEFAULT_CASES_JSON="$TMP_DIR/stability_cases.json"
	SAMPLES_TSV="$ARTIFACT_DIR/stability_samples.tsv"
	REPORT_FILE="$ARTIFACT_DIR/android-stability-report.json"
	LOGCAT_FILE="$ARTIFACT_DIR/app_logcat_after_stability.txt"
	SUMMARY_FILE="$ARTIFACT_DIR/android-stability-summary.txt"
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
: >"$SAMPLES_TSV"
: >"$LOGCAT_FILE"
: >"$SUMMARY_FILE"

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
	if [[ "$KEEP_TMP" != "1" ]]; then
		/bin/rm -rf "$TMP_DIR"
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

write_default_cases() {
	node - "$DEFAULT_CASES_JSON" <<'NODE'
const fs = require("fs");
const out = process.argv[2];
const cases = [
  { name: "main-city-idle", startup: { route: "main_city", map_id: "city_forest_dawn_v1" } },
  { name: "trade-panel", startup: { route: "main_city", map_id: "social_trade_market_v1", facility: "trade" } },
  { name: "map-atlas", startup: { route: "main_city", map_id: "city_forest_dawn_v1", panel: "map_atlas" } },
  { name: "housing-edit", startup: { route: "home_edit" } },
  { name: "fishing-minigame", startup: { route: "main_city", map_id: "city_forest_dawn_v1", launch_minigame: "fishing" } }
];
fs.writeFileSync(out, JSON.stringify(cases, null, 2));
NODE
}

write_profile() {
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" cat files/player_profile.json >"$PROFILE_BACKUP" 2>/dev/null || true
	node - "$ROOT_DIR" "$PROFILE_BACKUP" "$PROFILE_STABILITY" <<'NODE'
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
  id: profile.id || "android-stability-probe",
  display_name: profile.display_name || "Guest",
  coin_balance: 200,
  current_route: "main_city",
  current_room_id: "world_town_square",
  current_world_map_id: "city_forest_dawn_v1",
  active_home_owner_id: profile.id || "android-stability-probe",
  active_home_visit_mode: false,
  owned_items: ["starter_wallpaper", "wooden_floor"],
  house_styles: { wall: "starter_wallpaper", floor: "wooden_floor" },
  house_items: [],
  discovered_world_map_ids: allIds,
  discovered_world_map_records: allIds.map((map_id, index) => ({
    map_id,
    source: "android_stability_probe",
    discovered_at: index,
  })),
  first_session_guide_completed_ids: ["npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"],
  first_session_guide_reward_claimed: true,
});
fs.writeFileSync(out, JSON.stringify(profile, null, "\t"));
NODE
	"${ADB[@]}" push "$PROFILE_STABILITY" /data/local/tmp/psw_player_profile_stability.json >/dev/null
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_player_profile_stability.json files/player_profile.json >/dev/null
}

launch_case() {
	local case_name="$1"
	local startup_json="$TMP_DIR/$STARTUP_FILE"
	node -e 'const fs=require("fs"); const cases=require(process.argv[1]); const item=cases.find((row)=>row.name===process.argv[2]); if (!item) throw new Error(`Unknown case ${process.argv[2]}`); fs.writeFileSync(process.argv[3], JSON.stringify(item.startup, null, 2));' "$CASES_JSON" "$case_name" "$startup_json"
	"${ADB[@]}" push "$startup_json" /data/local/tmp/psw_android_debug_startup.json >/dev/null
	"${ADB[@]}" shell run-as "$PACKAGE_NAME" cp /data/local/tmp/psw_android_debug_startup.json "files/$STARTUP_FILE" >/dev/null
	"${ADB[@]}" shell am force-stop "$PACKAGE_NAME" >/dev/null
	"${ADB[@]}" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null
	sleep "$ROUTE_SETTLE_SECONDS"
}

sample_metrics() {
	local case_name="$1"
	local elapsed="$2"
	local pid raw proc_line total_line cpu_count meminfo_file metrics
	mkdir -p "$TMP_DIR"
	pid="$("${ADB[@]}" shell pidof "$PACKAGE_NAME" 2>/dev/null | tr -d '\r' || true)"
	if [[ -z "$pid" ]]; then
		printf '%s\t%s\t%s\t\t0\t0\t0\t0\t0\t0\n' "$(date +%s)" "$elapsed" "$case_name" >>"$SAMPLES_TSV"
		return
	fi
	raw="$("${ADB[@]}" shell "cat /proc/$pid/stat 2>/dev/null; head -n 1 /proc/stat; grep -c '^processor' /proc/cpuinfo" | tr -d '\r')"
	proc_line="$(printf '%s\n' "$raw" | sed -n '1p')"
	total_line="$(printf '%s\n' "$raw" | sed -n '2p')"
	cpu_count="$(printf '%s\n' "$raw" | sed -n '3p')"
	meminfo_file="$TMP_DIR/meminfo-$pid.txt"
	if ! "${ADB[@]}" shell dumpsys meminfo "$PACKAGE_NAME" | tr -d '\r' >"$meminfo_file"; then
		printf '%s\t%s\t%s\t%s\t0\t0\t%s\t0\t0\t0\n' "$(date +%s)" "$elapsed" "$case_name" "$pid" "${cpu_count:-1}" >>"$SAMPLES_TSV"
		return
	fi
	metrics="$(node - "$pid" "$proc_line" "$total_line" "$cpu_count" "$meminfo_file" <<'NODE'
const fs = require("fs");
const pid = process.argv[2] || "";
const procLine = process.argv[3] || "";
const totalLine = process.argv[4] || "";
const cpuCount = Number(process.argv[5] || 1);
const meminfo = fs.readFileSync(process.argv[6], "utf8");
const afterName = procLine.replace(/^.*\)\s+/, "").trim().split(/\s+/);
const procJiffies = Number(afterName[11] || 0) + Number(afterName[12] || 0);
const totalJiffies = totalLine.trim().split(/\s+/).slice(1).reduce((sum, value) => sum + Number(value || 0), 0);
const totalMatch = meminfo.match(/TOTAL PSS:\s*(\d+)\s+TOTAL RSS:\s*(\d+)\s+TOTAL SWAP PSS:\s*(\d+)/s);
let pssKb = 0;
let rssKb = 0;
let swapPssKb = 0;
if (totalMatch) {
  pssKb = Number(totalMatch[1]);
  rssKb = Number(totalMatch[2]);
  swapPssKb = Number(totalMatch[3]);
} else {
  const tableMatch = meminfo.match(/^\s*TOTAL\s+(\d+)(?:\s+\d+){3}\s+(\d+)/m);
  if (tableMatch) {
    pssKb = Number(tableMatch[1]);
    rssKb = Number(tableMatch[2]);
  }
}
console.log([pid, procJiffies, totalJiffies, cpuCount, pssKb, rssKb, swapPssKb].join("\t"));
NODE
)"
	printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$elapsed" "$case_name" "$metrics" >>"$SAMPLES_TSV"
}

write_report() {
	"${ADB[@]}" logcat -d >"$LOGCAT_FILE" || true
	node - "$DEVICE_ID" "$ARTIFACT_DIR" "$SAMPLES_TSV" "$REPORT_FILE" "$SUMMARY_FILE" "$DURATION_SECONDS" "$SAMPLE_INTERVAL_SECONDS" "$ROUTE_INTERVAL_SECONDS" "$PACKAGE_NAME" "$START_SECONDS" <<'NODE'
const fs = require("fs");
const path = require("path");

const device = process.argv[2];
const artifactDir = process.argv[3];
const samplePath = process.argv[4];
const reportPath = process.argv[5];
const summaryPath = process.argv[6];
const targetDurationSeconds = Number(process.argv[7]);
const sampleIntervalSeconds = Number(process.argv[8]);
const routeIntervalSeconds = Number(process.argv[9]);
const packageName = process.argv[10];
const startSeconds = Number(process.argv[11] || 0);

const rows = fs.readFileSync(samplePath, "utf8").trim().split(/\n+/).filter(Boolean).map((line) => {
  const [epoch, elapsed, caseName, pid, procJiffies, totalJiffies, cpuCount, pssKb, rssKb, swapPssKb] = line.split("\t");
  return {
    epoch: Number(epoch),
    elapsed_seconds: Number(elapsed),
    case_name: caseName,
    pid,
    proc_jiffies: Number(procJiffies || 0),
    total_jiffies: Number(totalJiffies || 0),
    cpu_count: Number(cpuCount || 1),
    pss_kb: Number(pssKb || 0),
    rss_kb: Number(rssKb || 0),
    swap_pss_kb: Number(swapPssKb || 0),
  };
});

let previous = null;
const samples = rows.map((row) => {
  let cpuPct = null;
  if (previous && row.pid && previous.pid === row.pid) {
    const procDelta = row.proc_jiffies - previous.proc_jiffies;
    const totalDelta = row.total_jiffies - previous.total_jiffies;
    if (procDelta >= 0 && totalDelta > 0) {
      cpuPct = (procDelta / totalDelta) * row.cpu_count * 100;
    }
  }
  previous = row;
  return { ...row, cpu_pct: cpuPct == null ? null : Number(cpuPct.toFixed(1)) };
});

const numeric = (field) => samples.map((row) => row[field]).filter((value) => Number.isFinite(value) && value > 0);
const avg = (values) => values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : 0;
const max = (values) => values.length ? Math.max(...values) : 0;
const firstPss = numeric("pss_kb")[0] || 0;
const lastPss = numeric("pss_kb").at(-1) || 0;
const cpuValues = samples.map((row) => row.cpu_pct).filter((value) => Number.isFinite(value));
const peakCpu = samples.reduce((best, row) => (row.cpu_pct ?? -1) > (best.cpu_pct ?? -1) ? row : best, {});
const peakPss = samples.reduce((best, row) => row.pss_kb > (best.pss_kb || 0) ? row : best, {});

const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  device,
  package_name: packageName,
  target_duration_seconds: targetDurationSeconds,
  observed_duration_seconds: samples.length ? samples.at(-1).elapsed_seconds : 0,
  wall_duration_seconds: startSeconds > 0 ? Math.max(0, Math.floor(Date.now() / 1000) - startSeconds) : 0,
  sample_interval_seconds: sampleIntervalSeconds,
  route_interval_seconds: routeIntervalSeconds,
  sample_count: samples.length,
  artifacts: {
    root: artifactDir,
    samples: samplePath,
    logcat: path.join(artifactDir, "app_logcat_after_stability.txt"),
    summary: summaryPath,
  },
  metrics: {
    avg_cpu_pct: Number(avg(cpuValues).toFixed(1)),
    max_cpu_pct: Number(max(cpuValues).toFixed(1)),
    avg_pss_mb: Number((avg(numeric("pss_kb")) / 1024).toFixed(1)),
    max_pss_mb: Number((max(numeric("pss_kb")) / 1024).toFixed(1)),
    avg_rss_mb: Number((avg(numeric("rss_kb")) / 1024).toFixed(1)),
    max_rss_mb: Number((max(numeric("rss_kb")) / 1024).toFixed(1)),
    pss_growth_mb: Number(((lastPss - firstPss) / 1024).toFixed(1)),
    max_swap_pss_mb: Number((max(numeric("swap_pss_kb")) / 1024).toFixed(1)),
  },
  peak_cpu_sample: peakCpu,
  peak_pss_sample: peakPss,
};

fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
fs.writeFileSync(summaryPath, [
  `Android stability probe: ${device}`,
  `Duration: ${report.observed_duration_seconds}s sampled, ${report.wall_duration_seconds}s wall / target ${targetDurationSeconds}s`,
  `Samples: ${samples.length}`,
  `CPU avg/max: ${report.metrics.avg_cpu_pct}% / ${report.metrics.max_cpu_pct}%`,
  `PSS avg/max/growth: ${report.metrics.avg_pss_mb}MB / ${report.metrics.max_pss_mb}MB / ${report.metrics.pss_growth_mb}MB`,
  `RSS avg/max: ${report.metrics.avg_rss_mb}MB / ${report.metrics.max_rss_mb}MB`,
  `Swap PSS max: ${report.metrics.max_swap_pss_mb}MB`,
  `Report: ${reportPath}`,
].join("\n") + "\n");
NODE
}

write_default_cases
if [[ -z "$CASES_JSON" ]]; then
	CASES_JSON="$DEFAULT_CASES_JSON"
elif [[ "$CASES_JSON" != /* ]]; then
	CASES_JSON="$ROOT_DIR/$CASES_JSON"
fi

write_profile
"${ADB[@]}" logcat -c >/dev/null || true

CASE_NAMES=()
while IFS= read -r case_name; do
	CASE_NAMES+=("$case_name")
done < <(node -e 'for (const item of require(process.argv[1])) console.log(item.name)' "$CASES_JSON")
if [[ "${#CASE_NAMES[@]}" -eq 0 ]]; then
	printf 'No stability cases selected.\n' >&2
	exit 1
fi

printf 'Android stability probe on %s: %ss target, %ss samples, %ss route interval\n' "$DEVICE_ID" "$DURATION_SECONDS" "$SAMPLE_INTERVAL_SECONDS" "$ROUTE_INTERVAL_SECONDS"
START_SECONDS="$(date +%s)"
END_SECONDS=$((START_SECONDS + DURATION_SECONDS))
route_index=0

while [[ "$(date +%s)" -lt "$END_SECONDS" ]]; do
	case_name="${CASE_NAMES[$((route_index % ${#CASE_NAMES[@]}))]}"
	route_index=$((route_index + 1))
	printf 'stability case start: %s\n' "$case_name"
	launch_case "$case_name"
	capture_screenshot "$ARTIFACT_DIR/route-$(printf '%02d' "$route_index")-$case_name.png"
	route_end=$(( $(date +%s) + ROUTE_INTERVAL_SECONDS ))
	if [[ "$route_end" -gt "$END_SECONDS" ]]; then
		route_end="$END_SECONDS"
	fi
	while [[ "$(date +%s)" -lt "$route_end" ]]; do
		now="$(date +%s)"
		elapsed=$((now - START_SECONDS))
		sample_metrics "$case_name" "$elapsed"
		sleep "$SAMPLE_INTERVAL_SECONDS"
	done
done

write_report
issues="$(rg -n -i "(FATAL EXCEPTION.*$PACKAGE_NAME|ANR in $PACKAGE_NAME|$PACKAGE_NAME.*(panic|segmentation|crash)|Godot.*(ERROR|SCRIPT ERROR)|ERROR:.*(res://|GDScript|Godot))" "$LOGCAT_FILE" || true)"
if [[ -n "$issues" ]]; then
	printf '%s\n' "$issues" >"$ARTIFACT_DIR/logcat_issues.txt"
	printf 'Android stability probe found logcat issues. See %s\n' "$ARTIFACT_DIR/logcat_issues.txt" >&2
	exit 1
fi

if [[ "$SKIP_BUDGET" != "1" ]]; then
	"$ROOT_DIR/scripts/check_android_runtime_budget.sh" "$REPORT_FILE"
fi

cat "$SUMMARY_FILE"
printf 'Android stability probe passed. Artifacts: %s\n' "$ARTIFACT_DIR"
