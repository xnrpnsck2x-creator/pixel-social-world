extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const STATIC_HOTSPOTS := {
	"home": "MapRoot/Entrances/HomeGateHotspot",
	"fishing": "MapRoot/InteractionPoints/FishingPierHotspot",
	"games": "MapRoot/InteractionPoints/GamesHallHotspot",
	"shop": "MapRoot/InteractionPoints/ShopHotspot",
	"trade": "MapRoot/InteractionPoints/TradeMarketHotspot",
	"guild": "MapRoot/InteractionPoints/GuildGardenHotspot",
	"workshop": "MapRoot/InteractionPoints/WorkshopHotspot",
	"mine": "MapRoot/InteractionPoints/MineHotspot",
	"to_city": "MapRoot/InteractionPoints/ReturnCityHotspot"
}
const DYNAMIC_ROOT := "MapRoot/InteractionPoints/DynamicMapActivityHotspots"
const UTILITY_ACTIONS := ["mail", "creator_help", "notice"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-hotspot-route-integrity",
		"display_name": "Hotspot Route Smoke",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"map_activity_cooldowns": {},
		"discovered_world_map_ids": _all_map_ids()
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	for map_id in _stable_map_ids(maps):
		if map_id != str(instance.get("_map_runtime").get("current_map_id")):
			instance.call("_switch_world_map", map_id, "world.map_travel_generic")
			await process_frame
			await process_frame
		_assert_map_hotspots(instance, map_id, maps.get(map_id, {}) as Dictionary, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map hotspot route integrity smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_map_hotspots(instance: Node, map_id: String, map_config: Dictionary, failures: Array[String]) -> void:
	var map_metadata = instance.get("_map_metadata")
	if map_metadata == null:
		failures.append("%s did not expose runtime map metadata." % map_id)
		return
	_assert_static_hotspots(instance, map_id, map_metadata, failures)
	_assert_dynamic_hotspots(instance, map_id, map_config, failures)

func _assert_static_hotspots(instance: Node, map_id: String, map_metadata, failures: Array[String]) -> void:
	for action_id in STATIC_HOTSPOTS.keys():
		var hotspot := instance.get_node_or_null(str(STATIC_HOTSPOTS[action_id])) as Area2D
		if hotspot == null:
			failures.append("%s is missing static hotspot %s." % [map_id, action_id])
			continue
		var should_show := bool(map_metadata.call("has_interaction", action_id))
		if hotspot.visible != should_show:
			failures.append("%s hotspot %s visibility drifted." % [map_id, action_id])
		if hotspot.monitoring != should_show or hotspot.input_pickable != should_show:
			failures.append("%s hotspot %s touch state drifted." % [map_id, action_id])
		if should_show:
			var expected_position: Vector2 = map_metadata.call("interaction_world_position", action_id, Vector2.ZERO)
			if hotspot.position.distance_to(expected_position) > 0.5:
				failures.append("%s hotspot %s position is not bound to map_points." % [map_id, action_id])
			var prompt := hotspot.get_node_or_null("PromptLabel") as Label
			if prompt == null or prompt.visible:
				failures.append("%s static hotspot %s prompt should stay hidden until hover/touch." % [map_id, action_id])

func _assert_dynamic_hotspots(instance: Node, map_id: String, map_config: Dictionary, failures: Array[String]) -> void:
	var dynamic_root := instance.get_node_or_null(DYNAMIC_ROOT)
	if dynamic_root == null:
		failures.append("%s is missing dynamic hotspot container." % map_id)
		return
	var expected := _expected_dynamic_actions(map_config)
	var actual := _actual_dynamic_actions(dynamic_root)
	for action_id in expected.keys():
		if int(actual.get(action_id, 0)) != int(expected[action_id]):
			failures.append("%s dynamic action %s count drifted: expected %d, got %d." % [
				map_id,
				action_id,
				int(expected[action_id]),
				int(actual.get(action_id, 0))
			])
	for action_id in actual.keys():
		if not expected.has(action_id):
			failures.append("%s kept stale or unsupported dynamic action %s." % [map_id, action_id])
	for child in dynamic_root.get_children():
		var hotspot := child as Area2D
		if hotspot == null:
			failures.append("%s dynamic hotspot %s is not an Area2D." % [map_id, child.name])
			continue
		var action_id := str(hotspot.get("action_id"))
		var prompt := hotspot.get_node_or_null("PromptLabel") as Label
		if prompt == null or prompt.text.strip_edges().is_empty():
			failures.append("%s dynamic hotspot %s has no prompt text." % [map_id, action_id])
		elif prompt.visible:
			failures.append("%s dynamic hotspot %s prompt should stay hidden until hover/touch." % [map_id, action_id])
		var marker := hotspot.get_node_or_null("PromptMarker") as Sprite2D
		if marker == null or marker.texture == null:
			failures.append("%s dynamic hotspot %s should keep a compact marker visible." % [map_id, action_id])
		if not hotspot.input_pickable or not hotspot.monitoring:
			failures.append("%s dynamic hotspot %s is not touchable." % [map_id, action_id])

func _expected_dynamic_actions(map_config: Dictionary) -> Dictionary:
	var activity_actions: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_activities").get("actions", {}) as Dictionary
	var rows := {}
	var seen := {}
	for point in _activity_points(map_config):
		var action_id := _point_action(point)
		if action_id.is_empty() or STATIC_HOTSPOTS.has(action_id):
			continue
		if not activity_actions.has(action_id) and not UTILITY_ACTIONS.has(action_id):
			continue
		var record := point as Dictionary
		var key := "%s:%d:%d" % [
			action_id,
			int(round(float(record.get("x", 0.0)))),
			int(round(float(record.get("y", 0.0))))
		]
		if seen.has(key):
			continue
		seen[key] = true
		rows[action_id] = int(rows.get(action_id, 0)) + 1
	return rows

func _actual_dynamic_actions(dynamic_root: Node) -> Dictionary:
	var rows := {}
	for child in dynamic_root.get_children():
		var action_id := str(child.get("action_id"))
		if action_id.is_empty():
			continue
		rows[action_id] = int(rows.get(action_id, 0)) + 1
	return rows

func _activity_points(map_config: Dictionary) -> Array:
	var rows := []
	rows.append_array(map_config.get("interaction_points", []) as Array)
	rows.append_array(map_config.get("life_skill_nodes", []) as Array)
	return rows

func _point_action(point) -> String:
	if typeof(point) != TYPE_DICTIONARY:
		return ""
	var record := point as Dictionary
	return str(record.get("action", record.get("type", "")))

func _stable_map_ids(maps: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for map_id in maps.keys():
		rows.append(str(map_id))
	rows.sort()
	if rows.has(DEFAULT_MAP_ID):
		rows.erase(DEFAULT_MAP_ID)
		rows.push_front(DEFAULT_MAP_ID)
	return rows

func _all_map_ids() -> Array[String]:
	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	return _stable_map_ids(maps)
