extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "room-life-player",
		"display_name": "Room Life",
		"coin_balance": 25,
		"coin_ledger": []
	})
	save_system.call("_apply_defaults")

	var realtime := root.get_node("RealtimeClient")
	realtime.call("configure", {"network": {"online_enabled": false}})
	var lifecycle := root.get_node("RoomLifecycle")

	lifecycle.call("enter_main_city", "Room Life")
	if save_system.call("get_profile_value", "current_room_id", "") != "world_town_square":
		failures.append("Main city room was not recorded.")

	lifecycle.call("enter_housing", "room-life-player", "Room Life")
	if save_system.call("get_profile_value", "current_room_id", "") != "home:room-life-player":
		failures.append("Housing room was not recorded.")

	lifecycle.call("enter_minigame", "fishing", "session_123", "Room Life")
	if save_system.call("get_profile_value", "current_room_id", "") != "minigame:fishing:session_123":
		failures.append("Minigame room was not recorded.")

	realtime.call("configure", {"network": {"online_enabled": true}})
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("room lifecycle smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
