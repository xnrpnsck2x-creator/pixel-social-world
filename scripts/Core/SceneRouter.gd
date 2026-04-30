extends Node

signal route_changed(route_name: String)

var routes_by_id: Dictionary = {}
var current_route := ""

func initialize() -> void:
	var config: Dictionary = ConfigLoader.load_config("scene_routes")
	routes_by_id.clear()
	var route_records: Variant = config.get("routes", [])

	if typeof(route_records) == TYPE_ARRAY:
		for route in route_records:
			if typeof(route) == TYPE_DICTIONARY and route.has("id"):
				routes_by_id[str(route["id"])] = route
	elif typeof(route_records) == TYPE_DICTIONARY:
		routes_by_id = route_records

func route_to(route_name: String) -> void:
	if routes_by_id.is_empty():
		initialize()

	var route: Dictionary = routes_by_id.get(route_name, {}) as Dictionary
	var scene_path: String = str(route.get("path", route.get("scene", "")))
	if scene_path.is_empty():
		push_error("Unknown route: %s" % route_name)
		return

	var error_code: int = get_tree().change_scene_to_file(scene_path)
	if error_code != OK:
		push_error("Failed to load route %s at %s" % [route_name, scene_path])
		return

	current_route = route_name
	SaveSystem.set_profile_value("current_route", route_name)
	SaveSystem.save_profile()
	route_changed.emit(route_name)
