class_name MinigameRegistry
extends Node

signal catalog_updated

var minigames: Array[Dictionary] = []

func initialize() -> void:
	minigames.clear()
	var config: Dictionary = ConfigLoader.load_config("minigames")
	for minigame in config.get("minigames", []):
		if typeof(minigame) == TYPE_DICTIONARY:
			var record := (minigame as Dictionary).duplicate(true)
			record["source"] = "official"
			minigames.append(record)
	call_deferred("refresh_online_catalog")

func refresh_online_catalog() -> void:
	var client := get_node_or_null("/root/OnlineClient")
	if client == null or not bool(client.get("is_connected")):
		return
	var response: Dictionary = await client.call("fetch_published_minigame_catalog")
	if not bool(response.get("ok", false)):
		return
	minigames = minigames.filter(func(record: Dictionary) -> bool:
		return str(record.get("source", "official")) != "creator"
	)
	for value in (response.get("data", {}) as Dictionary).get("items", []):
		if typeof(value) == TYPE_DICTIONARY:
			minigames.append(_creator_catalog_record(value as Dictionary))
	catalog_updated.emit()

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

func _creator_catalog_record(install: Dictionary) -> Dictionary:
	return {
		"id": str(install.get("game_id", "")),
		"mode_id": str(install.get("mode_id", "")),
		"name": (install.get("name", {}) as Dictionary).duplicate(true),
		"version": str(install.get("version", "")),
		"author": str(install.get("author", "")),
		"route_id": "minigame_fishing",
		"game_path": "res://scenes/minigames/declarative/main.tscn",
		"enabled": true,
		"source": "creator",
		"requires_network": bool(install.get("requires_network", false)),
		"min_players": int(install.get("min_players", 1)),
		"max_players": int(install.get("max_players", 1)),
		"runtime_contract": (install.get("runtime_contract", {}) as Dictionary).duplicate(true)
	}
