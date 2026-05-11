extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const RETURN_HOTSPOT := "MapRoot/InteractionPoints/ReturnCityHotspot"
const LOCAL_PLAYER := "PlayerRoot/LocalPlayer"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-travel-return-matrix",
		"display_name": "Map Matrix Smoke",
		"locale": "en",
		"coin_balance": 50,
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
	for map_id in _all_map_ids():
		if map_id == DEFAULT_MAP_ID:
			continue
		await _assert_round_trip(instance, map_id, failures)
		await process_frame
		await process_frame
	await _assert_guard_releases_after_return(instance, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map travel return matrix smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_round_trip(instance: Node, map_id: String, failures: Array[String]) -> void:
	instance.call("_switch_world_map", map_id, "world.map_travel_generic")
	await _spin_frames()
	if str(instance.get("_map_runtime").get("current_map_id")) != map_id:
		failures.append("%s did not load through scene travel." % map_id)
		return
	var hotspot := instance.get_node_or_null(RETURN_HOTSPOT)
	if hotspot == null or not hotspot.has_method("activate"):
		failures.append("%s is missing an activatable return hotspot." % map_id)
		return
	hotspot.set("_last_activation_msec", Time.get_ticks_msec() - 1000)
	hotspot.call("activate", "touch")
	await _spin_frames()
	instance.get("_interaction_controller").call("route_touch_hotspot_action", "fishing")
	await _spin_frames()
	if str(instance.get("_map_runtime").get("current_map_id")) != DEFAULT_MAP_ID:
		failures.append("%s return path allowed a duplicate touch to leave the main city." % map_id)
		return
	_assert_main_city_spawn(instance, map_id, failures)

func _assert_guard_releases_after_return(instance: Node, failures: Array[String]) -> void:
	instance.get("_interaction_controller").set("_touch_route_guard_until_msec", Time.get_ticks_msec() - 1)
	instance.get("_interaction_controller").call("route_touch_hotspot_action", "fishing")
	await _spin_frames()
	if str(instance.get("_map_runtime").get("current_map_id")) != "life_fishing_riverbend_v1":
		failures.append("Return route guard did not release for intentional follow-up travel.")

func _assert_main_city_spawn(instance: Node, source_map_id: String, failures: Array[String]) -> void:
	var player := instance.get_node_or_null(LOCAL_PLAYER) as Node2D
	var metadata = instance.get("_map_metadata")
	if player == null or metadata == null:
		failures.append("%s return path could not inspect the player spawn." % source_map_id)
		return
	var expected: Vector2 = metadata.call("spawn_world_position", "south_pier", Vector2.ZERO)
	if player.position.distance_to(expected) > 1.0:
		failures.append("%s returned to the main city at the wrong spawn." % source_map_id)

func _spin_frames(count := 3) -> void:
	for _index in range(count):
		await process_frame

func _all_map_ids() -> Array[String]:
	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	var rows: Array[String] = []
	for map_id in maps.keys():
		rows.append(str(map_id))
	rows.sort()
	if rows.has(DEFAULT_MAP_ID):
		rows.erase(DEFAULT_MAP_ID)
		rows.push_front(DEFAULT_MAP_ID)
	return rows
