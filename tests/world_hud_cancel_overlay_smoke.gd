extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	if bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)):
		failures.append("Android go-back default quit is still enabled.")
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "hud-cancel-overlay",
		"display_name": "HUD Cancel",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"discovered_world_map_ids": ["city_forest_dawn_v1"]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var hud := instance.get_node("WorldHUD") as CanvasLayer
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true

	hud.call("show_utility_panel", "shop")
	await process_frame
	hud.call("_unhandled_input", event)
	await process_frame
	if bool(hud.get_node("Root/WorldUtilityPanel").get("visible")):
		failures.append("ui_cancel did not close the utility panel.")

	hud.call("show_social_facility_panel", "trade")
	await process_frame
	hud.call("_unhandled_input", event)
	await process_frame
	if bool(hud.get_node("Root/SocialFacilityPanel").get("visible")):
		failures.append("ui_cancel did not close the social facility panel.")

	hud.call("show_room_panel")
	await process_frame
	hud.call("_unhandled_input", event)
	await process_frame
	if bool(hud.get_node("Root/OnlineRoomPanel").get("visible")):
		failures.append("ui_cancel did not close the room panel.")

	hud.call("show_utility_panel", "shop")
	await process_frame
	hud.call("_notification", Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	if bool(hud.get_node("Root/WorldUtilityPanel").get("visible")):
		failures.append("Android go-back notification did not close the utility panel.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("world hud cancel overlay smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
