#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
ARTIFACT_DIR="${PSW_UI_V2_ARTIFACT_DIR:-$ROOT_DIR/.tools/ui-v2-gate}"
H5_ARTIFACT_DIR="$ARTIFACT_DIR/h5"

DEFAULT_H5_CASES="h5-desktop-login-character-preview,h5-desktop-world-base,h5-mobile-landscape-world-base,h5-mobile-landscape-chat-keyboard-guard,h5-mobile-landscape-private-keyboard-guard,h5-mobile-landscape-trade-price-keyboard-guard,h5-desktop-map-panel,h5-mobile-landscape-map-atlas-wilds-filter,h5-desktop-shop-panel,h5-desktop-creator-panel,h5-mobile-landscape-creator-panel,h5-desktop-trade-facility-panel,h5-mobile-landscape-trade-facility-panel,h5-desktop-messages-panel,h5-mobile-landscape-messages-panel,h5-desktop-inventory-panel,h5-mobile-landscape-inventory-panel,h5-mobile-landscape-inventory-activity-rewards,h5-desktop-profile-card,h5-mobile-landscape-profile-card,h5-desktop-housing-selected,h5-mobile-landscape-housing-selected,h5-desktop-minigame-host,h5-mobile-landscape-minigame-host,h5-liveops-375x240-ops-tab,h5-mobile-portrait-guard"
H5_CASES="${PSW_UI_V2_H5_CASES:-$DEFAULT_H5_CASES}"

mkdir -p "$ARTIFACT_DIR" "$H5_ARTIFACT_DIR"

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

run_step "UI v2 runtime asset contract" python3 "$ROOT_DIR/tests/ui_v2_contract_smoke.py" "$ARTIFACT_DIR"
run_step "Godot import cache warmup" "$GODOT_BIN" --headless --path "$ROOT_DIR" --import
run_step "Godot UI frame contract smoke" run_godot_smoke "$ROOT_DIR/tests/ui_frame_contract_smoke.gd"
run_step "Godot world utility panel UI smoke" run_godot_smoke "$ROOT_DIR/tests/world_utility_panel_ui_smoke.gd"
run_step "Godot housing responsive layout smoke" run_godot_smoke "$ROOT_DIR/tests/housing_responsive_layout_smoke.gd"
run_step "content contract validation" python3 "$ROOT_DIR/tests/validate_content.py"

if [[ "${PSW_UI_V2_SKIP_H5:-0}" != "1" ]]; then
	run_step "H5 UI screenshot matrix" bash -lc "PSW_H5_EXPORT_WEB='${PSW_H5_EXPORT_WEB:-0}' PSW_H5_RUNTIME_GATE='${PSW_H5_RUNTIME_GATE:-0}' PSW_H5_ARTIFACT_DIR='$H5_ARTIFACT_DIR' PSW_H5_CASE='$H5_CASES' '$ROOT_DIR/scripts/run_h5_matrix.sh'"
	run_step "H5 UI screenshot semantic smoke" bash -lc "PSW_H5_SEMANTIC_MATRIX='$H5_ARTIFACT_DIR/h5-matrix.json' PSW_H5_SEMANTIC_CASES='$H5_CASES' node '$ROOT_DIR/tests/h5_semantic_smoke.mjs'"
fi

run_step "git diff whitespace" git -C "$ROOT_DIR" diff --check

echo "UI v2 gate passed. Artifacts: $ARTIFACT_DIR"
