class_name MinigameRegistry
extends Node

var minigames: Array[Dictionary] = []

func initialize() -> void:
	minigames.clear()
	var config: Dictionary = ConfigLoader.load_config("minigames")
	for minigame in config.get("minigames", []):
		if typeof(minigame) == TYPE_DICTIONARY:
			minigames.append(minigame)

func get_enabled_minigames() -> Array[Dictionary]:
	return minigames.filter(func(minigame: Dictionary) -> bool:
		return bool(minigame.get("enabled", false))
	)

func get_enabled_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for minigame in get_enabled_minigames():
		ids.append(str(minigame.get("id", "")))
	return ids

func get_minigame(game_id: String) -> Dictionary:
	for minigame in minigames:
		if str(minigame.get("id", "")) == game_id:
			return minigame.duplicate(true)
	return {}
