#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_BIN="${PSW_GO_BIN:-$ROOT_DIR/.tools/go/bin/go}"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
ARTIFACT_DIR="${PSW_MVP_GATE_ARTIFACT_DIR:-$ROOT_DIR/.tools/mvp-100-gate}"
H5_ARTIFACT_DIR="$ARTIFACT_DIR/h5"
PLAYWRIGHT_DIR="$ROOT_DIR/.tools/browser-smoke"
PLAYWRIGHT_VERSION="${PSW_PLAYWRIGHT_VERSION:-1.59.1}"

DEFAULT_H5_CASES="h5-desktop-world-base,h5-mobile-landscape-world-base,h5-mobile-landscape-name-reveal,h5-mobile-landscape-hotspot-feedback,h5-mobile-landscape-tap-move-feedback,h5-desktop-map-panel,h5-mobile-landscape-map-atlas-wilds-filter,h5-desktop-creator-panel,h5-mobile-landscape-creator-panel,h5-desktop-trade-facility-panel,h5-mobile-landscape-trade-price-keyboard-guard,h5-mobile-landscape-guild-facility-panel,h5-desktop-mail-panel,h5-desktop-messages-panel,h5-mobile-landscape-chat-keyboard-guard,h5-mobile-landscape-private-keyboard-guard,h5-mobile-landscape-inventory-panel,h5-mobile-landscape-inventory-activity-rewards,h5-desktop-profile-card,h5-mobile-landscape-profile-card,h5-desktop-housing-selected,h5-mobile-landscape-housing-selected,h5-desktop-minigame-host,h5-mobile-landscape-minigame-host,h5-liveops-375x240-ops-tab,h5-mobile-portrait-guard"
H5_CASES="${PSW_MVP_GATE_H5_CASES:-$DEFAULT_H5_CASES}"

mkdir -p "$ARTIFACT_DIR" "$H5_ARTIFACT_DIR"

if [[ ! -x "$GO_BIN" ]]; then
	GO_BIN="go"
fi
if [[ ! -x "$GODOT_BIN" ]]; then
	echo "Godot binary not found: $GODOT_BIN" >&2
	exit 1
fi
"$ROOT_DIR/scripts/ensure_adb_server_for_godot.sh"

run_step() {
	local name="$1"
	shift
	echo "==> $name"
	"$@"
}

run_godot_smoke() {
	local script="$1"
	"$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$script"
}

ensure_playwright() {
	if [[ -f "$PLAYWRIGHT_DIR/node_modules/playwright/index.mjs" ]]; then
		return
	fi
	mkdir -p "$PLAYWRIGHT_DIR"
	if [[ ! -f "$PLAYWRIGHT_DIR/package.json" ]]; then
		cat >"$PLAYWRIGHT_DIR/package.json" <<JSON
{"private":true,"devDependencies":{"playwright":"$PLAYWRIGHT_VERSION"}}
JSON
	fi
	if [[ -f "$PLAYWRIGHT_DIR/package-lock.json" ]]; then
		npm ci --prefix "$PLAYWRIGHT_DIR"
	else
		npm install --prefix "$PLAYWRIGHT_DIR" --no-audit --no-fund "playwright@$PLAYWRIGHT_VERSION"
	fi
}

run_step "backend go test" bash -lc "cd '$ROOT_DIR/backend' && '$GO_BIN' test ./..."
run_step "content contract validation" python3 "$ROOT_DIR/tests/validate_content.py"
run_step "Godot import cache warmup" "$GODOT_BIN" --headless --path "$ROOT_DIR" --import
run_step "UI v2 gate" bash -lc "PSW_UI_V2_SKIP_H5=1 PSW_UI_V2_ARTIFACT_DIR='$ARTIFACT_DIR/ui-v2' '$ROOT_DIR/scripts/run_ui_v2_gate.sh'"
run_step "project category v2 gate" bash -lc "PSW_PROJECT_CATEGORY_V2_SKIP_H5=1 PSW_PROJECT_CATEGORY_V2_ARTIFACT_DIR='$ARTIFACT_DIR/project-category-v2' '$ROOT_DIR/scripts/run_project_category_v2_gate.sh'"
run_step "localization JSON syntax" bash -lc "python3 -m json.tool '$ROOT_DIR/localization/en.json' >/dev/null && python3 -m json.tool '$ROOT_DIR/localization/ja.json' >/dev/null && python3 -m json.tool '$ROOT_DIR/localization/zh-Hans.json' >/dev/null"

run_step "Godot core smoke" run_godot_smoke "$ROOT_DIR/tests/godot_smoke.gd"
run_step "Godot login character selection smoke" run_godot_smoke "$ROOT_DIR/tests/login_character_selection_smoke.gd"
run_step "Godot player avatar smoke" run_godot_smoke "$ROOT_DIR/tests/player_avatar_smoke.gd"
run_step "Godot player avatar variants smoke" run_godot_smoke "$ROOT_DIR/tests/player_avatar_variants_smoke.gd"
run_step "Godot main city smoke" run_godot_smoke "$ROOT_DIR/tests/main_city_interactions_smoke.gd"
run_step "Godot main city NPC feedback smoke" run_godot_smoke "$ROOT_DIR/tests/main_city_npc_feedback_smoke.gd"
run_step "Godot main city NPC attention smoke" run_godot_smoke "$ROOT_DIR/tests/main_city_npc_attention_smoke.gd"
run_step "Godot main city NPC ambience smoke" run_godot_smoke "$ROOT_DIR/tests/main_city_npc_ambience_smoke.gd"
run_step "Godot map actor depth sort smoke" run_godot_smoke "$ROOT_DIR/tests/map_actor_depth_sort_smoke.gd"
run_step "Godot first-session guide smoke" run_godot_smoke "$ROOT_DIR/tests/first_session_guide_smoke.gd"
run_step "Godot economy ledger smoke" run_godot_smoke "$ROOT_DIR/tests/economy_ledger_smoke.gd"
run_step "Godot inventory audit smoke" run_godot_smoke "$ROOT_DIR/tests/inventory_audit_rows_smoke.gd"
run_step "Godot world inventory smoke" run_godot_smoke "$ROOT_DIR/tests/world_utility_inventory_rows_smoke.gd"
run_step "Godot trade actions smoke" run_godot_smoke "$ROOT_DIR/tests/social_facility_trade_actions_smoke.gd"
run_step "Godot trade feedback smoke" run_godot_smoke "$ROOT_DIR/tests/social_facility_trade_feedback_smoke.gd"
run_step "Godot trade history audit smoke" run_godot_smoke "$ROOT_DIR/tests/trade_history_audit_panel_smoke.gd"
run_step "Godot social facility smoke" run_godot_smoke "$ROOT_DIR/tests/social_facility_panel_smoke.gd"
run_step "Godot social facility actions smoke" run_godot_smoke "$ROOT_DIR/tests/social_facility_panel_actions_smoke.gd"
run_step "Godot social messages smoke" run_godot_smoke "$ROOT_DIR/tests/social_messages_panel_smoke.gd"
run_step "Godot online room UI smoke" run_godot_smoke "$ROOT_DIR/tests/online_room_ui_smoke.gd"
run_step "Godot remote players smoke" run_godot_smoke "$ROOT_DIR/tests/remote_players_smoke.gd"
run_step "Godot world state sync smoke" run_godot_smoke "$ROOT_DIR/tests/world_state_sync_smoke.gd"
run_step "Godot mobile input smoke" run_godot_smoke "$ROOT_DIR/tests/mobile_input_controller_smoke.gd"
run_step "Godot main city tap move smoke" run_godot_smoke "$ROOT_DIR/tests/main_city_tap_move_controller_smoke.gd"
run_step "Godot housing smoke" run_godot_smoke "$ROOT_DIR/tests/housing_smoke.gd"
run_step "Godot housing responsive layout smoke" run_godot_smoke "$ROOT_DIR/tests/housing_responsive_layout_smoke.gd"
run_step "Godot minigame contract smoke" run_godot_smoke "$ROOT_DIR/tests/minigame_contract_smoke.gd"
run_step "Godot minigame launch smoke" run_godot_smoke "$ROOT_DIR/tests/minigame_launch_flow_smoke.gd"
run_step "Godot minigame session smoke" run_godot_smoke "$ROOT_DIR/tests/minigame_session_service_smoke.gd"
run_step "Godot fishing reward UI smoke" run_godot_smoke "$ROOT_DIR/tests/fishing_reward_ui_smoke.gd"
run_step "Godot liveops smoke" run_godot_smoke "$ROOT_DIR/tests/liveops_console_smoke.gd"
run_step "Godot reviewer console smoke" run_godot_smoke "$ROOT_DIR/tests/reviewer_console_smoke.gd"
run_step "Godot chat reports console smoke" run_godot_smoke "$ROOT_DIR/tests/chat_reports_console_smoke.gd"
run_step "Godot chat moderation audit smoke" run_godot_smoke "$ROOT_DIR/tests/chat_moderation_audit_smoke.gd"
run_step "map quality v2 gate" bash -lc "PSW_MAP_QUALITY_V2_SKIP_H5=1 PSW_MAP_QUALITY_V2_ARTIFACT_DIR='$ARTIFACT_DIR/map-quality-v2' '$ROOT_DIR/scripts/run_map_quality_v2_gate.sh'"

run_step "backend Godot E2E suite" "$ROOT_DIR/scripts/run_backend_e2e.sh"

run_step "browser smoke dependency bootstrap" ensure_playwright

run_step "H5 priority screenshot matrix" bash -lc "PSW_H5_EXPORT_WEB=1 PSW_H5_RUNTIME_GATE=1 PSW_H5_ARTIFACT_DIR='$H5_ARTIFACT_DIR' PSW_H5_CASE='$H5_CASES' '$ROOT_DIR/scripts/run_h5_matrix.sh'"
run_step "H5 screenshot semantic smoke" bash -lc "PSW_H5_SEMANTIC_MATRIX='$H5_ARTIFACT_DIR/h5-matrix.json' PSW_H5_SEMANTIC_CASES='$H5_CASES' node '$ROOT_DIR/tests/h5_semantic_smoke.mjs'"
run_step "H5 generated map patrol" bash -lc "PSW_H5_EXPORT_WEB=0 PSW_H5_MAP_PATROL_ARTIFACT_DIR='$ARTIFACT_DIR/h5-map-patrol' '$ROOT_DIR/scripts/run_h5_map_patrol.sh'"
run_step "map debug atlas report" node "$ROOT_DIR/scripts/Tools/MapPipeline/build_map_debug_atlas.mjs" "$ARTIFACT_DIR/map-debug-atlas"

run_step "GDScript line budget" python3 - "$ROOT_DIR" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
failures = []
for path in root.rglob("*.gd"):
    if ".godot" in path.parts:
        continue
    line_count = sum(1 for _ in path.open("r", encoding="utf-8"))
    if line_count > 300:
        failures.append(f"{path}: {line_count} lines")
if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
print("GDScript line budget passed")
PY

run_step "git diff whitespace" git -C "$ROOT_DIR" diff --check

echo "MVP 100 gate passed. Artifacts: $ARTIFACT_DIR"
