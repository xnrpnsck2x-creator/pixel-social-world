#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
ARTIFACT_DIR="${PSW_MAP_QUALITY_V2_ARTIFACT_DIR:-$ROOT_DIR/.tools/map-quality-v2-gate}"
H5_ARTIFACT_DIR="$ARTIFACT_DIR/h5"
DEFAULT_H5_CASES="h5-mobile-landscape-world-base,h5-mobile-landscape-tap-move-feedback,h5-mobile-landscape-hotspot-feedback,h5-mobile-landscape-name-reveal,h5-mobile-landscape-map-atlas-wilds-filter"
H5_CASES="${PSW_MAP_QUALITY_V2_H5_CASES:-$DEFAULT_H5_CASES}"

GODOT_MAP_TESTS=(
	"tests/map_production_contract_smoke.gd"
	"tests/map_first_screen_readability_smoke.gd"
	"tests/map_point_quality_smoke.gd"
	"tests/map_gathering_zone_quality_smoke.gd"
	"tests/map_npc_grounding_smoke.gd"
	"tests/map_npc_visual_quality_v2_smoke.gd"
	"tests/map_npc_action_routes_smoke.gd"
	"tests/map_actor_depth_sort_smoke.gd"
	"tests/map_collision_patrol_smoke.gd"
	"tests/map_activity_service_smoke.gd"
	"tests/map_activity_hotspots_smoke.gd"
	"tests/map_utility_hotspots_smoke.gd"
	"tests/map_hotspot_route_integrity_smoke.gd"
	"tests/main_city_hotspot_precision_smoke.gd"
	"tests/main_city_tap_move_controller_smoke.gd"
	"tests/main_city_interaction_route_debounce_smoke.gd"
	"tests/map_return_portal_mobile_smoke.gd"
	"tests/map_travel_return_matrix_smoke.gd"
	"tests/hotspot_prompt_safe_area_smoke.gd"
	"tests/map_interaction_quality_v2_smoke.gd"
	"tests/map_unlocker_smoke.gd"
)

mkdir -p "$ARTIFACT_DIR" "$H5_ARTIFACT_DIR"

if [[ ! -x "$GODOT_BIN" ]]; then
	echo "Godot binary not found: $GODOT_BIN" >&2
	exit 1
fi

run_step() {
	local name="$1"
	shift
	echo "==> $name"
	"$@"
}

run_godot_smoke() {
	local script="$1"
	"$GODOT_BIN" --headless --path "$ROOT_DIR" --script "$ROOT_DIR/$script"
}

run_step "content contract validation" python3 "$ROOT_DIR/tests/validate_content.py"
run_step "Godot import cache warmup" "$GODOT_BIN" --headless --path "$ROOT_DIR" --import
for script in "${GODOT_MAP_TESTS[@]}"; do
	run_step "Godot ${script#tests/}" run_godot_smoke "$script"
done

if [[ "${PSW_MAP_QUALITY_V2_SKIP_H5:-0}" != "1" ]]; then
	run_step "H5 map quality focused matrix" bash -lc "PSW_H5_EXPORT_WEB='${PSW_H5_EXPORT_WEB:-0}' PSW_H5_RUNTIME_GATE='${PSW_H5_RUNTIME_GATE:-0}' PSW_H5_ARTIFACT_DIR='$H5_ARTIFACT_DIR' PSW_H5_CASE='$H5_CASES' '$ROOT_DIR/scripts/run_h5_matrix.sh'"
	run_step "H5 map quality semantic smoke" bash -lc "PSW_H5_SEMANTIC_MATRIX='$H5_ARTIFACT_DIR/h5-matrix.json' PSW_H5_SEMANTIC_CASES='$H5_CASES' node '$ROOT_DIR/tests/h5_semantic_smoke.mjs'"
fi

if [[ "${PSW_MAP_QUALITY_V2_FULL_PATROL:-0}" == "1" ]]; then
	run_step "H5 generated map patrol" bash -lc "PSW_H5_EXPORT_WEB='${PSW_H5_EXPORT_WEB:-0}' PSW_H5_MAP_PATROL_ARTIFACT_DIR='$ARTIFACT_DIR/h5-map-patrol' '$ROOT_DIR/scripts/run_h5_map_patrol.sh'"
	run_step "map debug atlas report" node "$ROOT_DIR/scripts/Tools/MapPipeline/build_map_debug_atlas.mjs" "$ARTIFACT_DIR/map-debug-atlas"
fi

run_step "git diff whitespace" git -C "$ROOT_DIR" diff --check

echo "Map quality v2 gate passed. Artifacts: $ARTIFACT_DIR"
