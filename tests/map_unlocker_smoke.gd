extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "unlocker-smoke",
		"discovered_world_map_ids": ["city_forest_dawn_v1"],
		"discovered_world_map_records": [{"map_id": "city_forest_dawn_v1", "source": "default", "discovered_at": 0}]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var runtime = load("res://scripts/main_city/MainCityMapRuntime.gd").new()
	var unlocker = load("res://scripts/main_city/MainCityMapUnlocker.gd").new()
	unlocker.bind(runtime)
	var first: Dictionary = await unlocker.unlock_map("life_fishing_riverbend_v1", "npc")
	var second: Dictionary = await unlocker.unlock_map("life_fishing_riverbend_v1", "arrival")
	var records: Array = save_system.call("get_profile_value", "discovered_world_map_records", [])
	var source := _source_for(records, "life_fishing_riverbend_v1")

	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if bool(first.get("unlocked", false)) and not bool(second.get("unlocked", true)) and source == "npc":
		print("map unlocker smoke passed")
		quit(0)
		return
	push_error("map unlocker did not keep first source, got %s" % source)
	quit(1)

func _source_for(records: Array, map_id: String) -> String:
	for record in records:
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("map_id", "")) == map_id:
			return str((record as Dictionary).get("source", ""))
	return ""
