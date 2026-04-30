extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "launch-flow-player",
		"device_id": "launch-flow-device",
		"display_name": "Launch Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "minigame_fishing",
		"current_room_id": "world_town_square",
		"pending_minigame_id": "fishing",
		"pending_minigame_session_id": "local_fishing",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/sandbox/MinigameSandbox.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	if str(instance.get("active_game_id")) != "fishing":
		failures.append("Sandbox did not mark fishing as active.")
	var active_game: Node = instance.get("active_game") as Node
	if active_game == null or not active_game.has_method("on_start"):
		failures.append("Sandbox did not instantiate an IMinigame.")
	var room_id := str(root.get_node("RoomLifecycle").get("current_room_id"))
	if room_id != "minigame:fishing:local_fishing":
		failures.append("RoomLifecycle did not enter the minigame session room.")

	if active_game != null and active_game.has_method("_finish_game"):
		active_game.call("_finish_game")
		await process_frame
		await process_frame
		var returned_room := str(root.get_node("RoomLifecycle").get("current_room_id"))
		if returned_room != "world_town_square":
			failures.append("Finished minigame did not return to the main city room.")
		if str(save_system.call("get_profile_value", "current_route", "")) != "main_city":
			failures.append("Finished minigame did not route back to main_city.")

	if is_instance_valid(instance):
		instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("minigame launch flow smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
