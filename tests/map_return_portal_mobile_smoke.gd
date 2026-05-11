extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const RETURN_HOTSPOT := "MapRoot/InteractionPoints/ReturnCityHotspot"
const MIN_TOUCH_SIZE := Vector2(260.0, 190.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-return-portal-mobile",
		"display_name": "Return Portal Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
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
		if map_id == DEFAULT_MAP_ID:
			continue
		instance.call("_switch_world_map", map_id, "world.map_travel_generic")
		await process_frame
		await process_frame
		_assert_return_hotspot(instance, map_id, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map return portal mobile smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_return_hotspot(instance: Node, map_id: String, failures: Array[String]) -> void:
	var hotspot := instance.get_node_or_null(RETURN_HOTSPOT) as Area2D
	if hotspot == null:
		failures.append("%s is missing the return city hotspot." % map_id)
		return
	if not hotspot.visible or not hotspot.monitoring or not hotspot.input_pickable:
		failures.append("%s return city hotspot is not touchable." % map_id)
	var marker := hotspot.get_node_or_null("Marker") as Sprite2D
	if marker == null or not marker.visible:
		failures.append("%s return city marker should be visible on secondary maps." % map_id)
	if not hotspot.has_meta("mobile_touch_rect"):
		failures.append("%s return city hotspot has no mobile touch rect." % map_id)
		return
	var rect: Rect2 = hotspot.get_meta("mobile_touch_rect") as Rect2
	if rect.size.x < MIN_TOUCH_SIZE.x or rect.size.y < MIN_TOUCH_SIZE.y:
		failures.append("%s return city touch rect is too small: %s." % [map_id, rect])
	if not rect.has_point(hotspot.global_position):
		failures.append("%s return city touch rect does not contain the hotspot anchor." % map_id)

func _stable_map_ids(maps: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for map_id in maps.keys():
		rows.append(str(map_id))
	rows.sort()
	return rows

func _all_map_ids() -> Array[String]:
	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	return _stable_map_ids(maps)
