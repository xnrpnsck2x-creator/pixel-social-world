extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "session-service-player",
		"device_id": "session-service-device",
		"display_name": "Session Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"current_room_id": "world_town_square",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {
		"offline_mode_enabled": true,
		"network": {"online_enabled": false}
	})
	root.get_node("OnlineClient").set("is_connected", false)
	root.get_node("SceneRouter").set("current_route", "main_city")

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	var service: Node = instance.get_node("ServiceRoot/MinigameSessionService")

	var response: Dictionary = await service.create_session("fishing")
	if not bool(response.get("ok", false)):
		failures.append("Offline create_session should succeed.")
	if str(save_system.call("get_profile_value", "pending_minigame_id", "")) != "fishing":
		failures.append("create_session did not remember the pending game.")
	if str(save_system.call("get_profile_value", "pending_minigame_session_id", "")) != "local_fishing":
		failures.append("create_session did not remember the local session.")
	if str(root.get_node("SceneRouter").get("current_route")) != "main_city":
		failures.append("create_session should not route directly.")

	var join_response: Dictionary = await service.join_session("local_fishing")
	if not bool(join_response.get("ok", false)):
		failures.append("Offline join_session should succeed.")
	if str((join_response.get("data", {}) as Dictionary).get("game_id", "")) != "fishing":
		failures.append("join_session returned the wrong game id.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("minigame session service smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
