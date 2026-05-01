class_name MinigameManifestValidator
extends RefCounted

const REQUIRED_TOP_LEVEL := [
	"game_id",
	"version",
	"author",
	"mode_id",
	"name",
	"min_players",
	"max_players",
	"tags",
	"requires_network",
	"runtime_contract",
	"entry_scene",
	"main_script",
	"asset_budget_bytes"
]
const REQUIRED_NAME_KEYS := ["en", "ja", "zh"]
const MODE_PLAYER_CAPS := {
	"casual_activity": 4,
	"side_scroller_2d": 4,
	"2d_fighting": 4,
	"strategy_war": 4,
	"rpg_adventure": 4,
	"tower_defense": 4,
	"battle_royale": 16
}
const MODE_RUNTIME_CONTRACTS := {
	"casual_activity": {"camera": "contained", "input_profile": "tap_timing", "network_profile": "offline_optional"},
	"side_scroller_2d": {"camera": "side_view", "input_profile": "action_platformer", "network_profile": "session_sync"},
	"2d_fighting": {"camera": "side_view", "input_profile": "fighting_action", "network_profile": "authoritative_realtime"},
	"strategy_war": {"camera": "isometric", "input_profile": "strategy_pointer", "network_profile": "turn_or_lockstep"},
	"rpg_adventure": {"camera": "top_down", "input_profile": "rpg_move_confirm", "network_profile": "session_sync"},
	"tower_defense": {"camera": "lane_grid", "input_profile": "tower_place_upgrade", "network_profile": "session_sync"},
	"battle_royale": {"camera": "top_down", "input_profile": "survival_action", "network_profile": "authoritative_realtime"}
}

static func validate(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_TOP_LEVEL:
		if not manifest.has(key):
			errors.append("Missing field: %s" % key)

	var name_value: Variant = manifest.get("name", {})
	if typeof(name_value) != TYPE_DICTIONARY:
		errors.append("name must be an object")
	else:
		var name_map: Dictionary = name_value as Dictionary
		for locale in REQUIRED_NAME_KEYS:
			if str(name_map.get(locale, "")).strip_edges().is_empty():
				errors.append("name.%s is required" % locale)

	var min_players: int = int(manifest.get("min_players", 0))
	var max_players: int = int(manifest.get("max_players", 0))
	if min_players <= 0:
		errors.append("min_players must be positive")
	if max_players < min_players:
		errors.append("max_players must be greater than or equal to min_players")
	var mode_id := str(manifest.get("mode_id", ""))
	if not MODE_PLAYER_CAPS.has(mode_id):
		errors.append("Unsupported mode_id: %s" % mode_id)
	elif max_players > int(MODE_PLAYER_CAPS[mode_id]):
		errors.append("max_players exceeds mode cap for %s" % mode_id)

	var tags: Variant = manifest.get("tags", [])
	if typeof(tags) != TYPE_ARRAY:
		errors.append("tags must be an array")
	var runtime_contract: Variant = manifest.get("runtime_contract", {})
	if typeof(runtime_contract) != TYPE_DICTIONARY:
		errors.append("runtime_contract must be an object")
	elif MODE_RUNTIME_CONTRACTS.has(mode_id):
		_validate_runtime_contract(runtime_contract as Dictionary, MODE_RUNTIME_CONTRACTS[mode_id] as Dictionary, errors)
	if int(manifest.get("asset_budget_bytes", 0)) <= 0:
		errors.append("asset_budget_bytes must be positive")

	return errors

static func _validate_runtime_contract(contract: Dictionary, expected: Dictionary, errors: Array[String]) -> void:
	for field in ["camera", "input_profile", "network_profile"]:
		if str(contract.get(field, "")) != str(expected.get(field, "")):
			errors.append("runtime_contract.%s must be %s" % [field, str(expected.get(field, ""))])
