extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-utility-hotspots",
		"display_name": "Utility Hotspot Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"discovered_world_map_ids": [DEFAULT_MAP_ID]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	await _switch_and_assert_utility(instance, "social_housing_district_v1", "mail", "SocialMessagesPanel", failures)
	await _switch_and_assert_utility(instance, "city_port_market_v1", "mail", "SocialMessagesPanel", failures)
	await _switch_and_assert_utility(instance, "city_academy_plaza_v1", "creator_help", "WorldUtilityPanel", failures)
	await _switch_and_assert_utility(instance, "city_academy_plaza_v1", "notice", "WorldUtilityPanel", failures)
	await _switch_and_assert_utility(instance, "social_trade_market_v1", "notice", "WorldUtilityPanel", failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map utility hotspots smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _switch_and_assert_utility(
	instance: Node,
	map_id: String,
	action_id: String,
	panel_name: String,
	failures: Array[String]
) -> void:
	instance.call("_switch_world_map", map_id, "world.map_travel_generic")
	await process_frame
	await process_frame
	var hotspot := _utility_hotspot(instance, action_id)
	if hotspot == null:
		failures.append("%s did not create a dynamic %s utility hotspot." % [map_id, action_id])
		return
	var map_runtime = instance.get("_map_runtime")
	var activity_service = instance.get("_map_activity_service")
	if map_runtime != null and activity_service != null:
		map_runtime.call("refresh_activity_hotspots", activity_service)
		await process_frame
	if bool(hotspot.get("always_show_prompt")):
		failures.append("%s utility hotspot %s should stay hidden until hover/tap feedback." % [map_id, action_id])
	var prompt := hotspot.get_node_or_null("PromptLabel") as Label
	if prompt == null or prompt.visible:
		failures.append("%s utility hotspot %s prompt became visible during activity refresh." % [map_id, action_id])
	hotspot.call("activate")
	await process_frame
	var panel := instance.get_node_or_null("WorldHUD/Root/%s" % panel_name)
	if panel == null or not bool(panel.get("visible")):
		failures.append("%s utility hotspot %s did not open %s." % [map_id, action_id, panel_name])
	elif panel.has_method("hide_panel"):
		panel.call("hide_panel")

func _utility_hotspot(instance: Node, action_id: String) -> Node:
	var container := instance.get_node_or_null("MapRoot/InteractionPoints/DynamicMapActivityHotspots")
	if container == null:
		return null
	for child in container.get_children():
		if str(child.get("action_id")) == action_id:
			return child
	return null
