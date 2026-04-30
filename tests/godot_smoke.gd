extends SceneTree

const ROUTES_PATH := "res://configs/scene_routes.json"
const MINIGAMES_PATH := "res://configs/minigames.json"

func _initialize() -> void:
	var failures: Array[String] = []
	var routes: Array = _load_routes()

	for route in routes:
		if typeof(route) != TYPE_DICTIONARY:
			failures.append("Route entry is not an object.")
			continue

		var route_id: String = str(route.get("id", ""))
		var route_path: String = str(route.get("path", ""))
		var scene: PackedScene = load(route_path)
		if scene == null:
			failures.append("Failed to load route %s at %s" % [route_id, route_path])
			continue

		var instance: Node = scene.instantiate()
		if instance == null:
			failures.append("Failed to instantiate route %s at %s" % [route_id, route_path])
			continue
		instance.free()

	for minigame in _load_minigames():
		if typeof(minigame) != TYPE_DICTIONARY or not bool(minigame.get("enabled", false)):
			continue
		var game_id: String = str(minigame.get("id", ""))
		var game_path: String = str(minigame.get("game_path", ""))
		var game_scene: PackedScene = load(game_path)
		if game_scene == null:
			failures.append("Failed to load minigame %s at %s" % [game_id, game_path])
			continue
		var game_instance: Node = game_scene.instantiate()
		if game_instance == null:
			failures.append("Failed to instantiate minigame %s at %s" % [game_id, game_path])
			continue
		for method_name in ["get_game_id", "on_start", "on_end", "on_pause", "on_resume"]:
			if not game_instance.has_method(method_name):
				failures.append("Minigame %s is missing method %s" % [game_id, method_name])
		game_instance.free()

	if failures.is_empty():
		print("godot smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _load_routes() -> Array:
	var file: FileAccess = FileAccess.open(ROUTES_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing route config: %s" % ROUTES_PATH)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Route config is not a JSON object.")
		return []

	var data: Dictionary = parsed as Dictionary
	var routes: Variant = data.get("routes", [])
	if typeof(routes) != TYPE_ARRAY:
		push_error("Route config does not contain a routes array.")
		return []

	return routes as Array

func _load_minigames() -> Array:
	var file: FileAccess = FileAccess.open(MINIGAMES_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing minigame config: %s" % MINIGAMES_PATH)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Minigame config is not a JSON object.")
		return []

	var data: Dictionary = parsed as Dictionary
	var minigames: Variant = data.get("minigames", [])
	if typeof(minigames) != TYPE_ARRAY:
		push_error("Minigame config does not contain a minigames array.")
		return []

	return minigames as Array
