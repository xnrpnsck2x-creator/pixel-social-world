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
	if typeof(manifest.get("runtime_contract", {})) != TYPE_DICTIONARY:
		errors.append("runtime_contract must be an object")
	if int(manifest.get("asset_budget_bytes", 0)) <= 0:
		errors.append("asset_budget_bytes must be positive")

	return errors
