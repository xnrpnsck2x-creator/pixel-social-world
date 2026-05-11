extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var client := root.get_node("OnlineClient")
	var original_online_enabled := bool(client.get("online_enabled"))
	var original_is_connected := bool(client.get("is_connected"))
	var original_access_token := str(client.get("access_token"))

	client.call("configure", {"network": {"online_enabled": false}})
	client.set("is_connected", false)
	client.set("access_token", "")

	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "offline-player",
		"device_id": "test-device",
		"display_name": "Presence Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": [],
		"owned_items": [],
		"house_styles": {},
		"house_items": []
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var service: Node = instance.get_node("ServiceRoot/PresenceService")
	var callback := Callable(service, "_on_online_connection_changed")
	if not client.is_connected("connection_changed", callback):
		failures.append("Presence service should refresh immediately when the online client connects.")
	client.set("online_enabled", true)
	client.set("is_connected", false)
	client.set("access_token", "test-access-token")
	service.set("_last_heartbeat_msec", Time.get_ticks_msec())
	service.set("_tick_seconds", 10)

	if not bool(service.call("_online_client_available")):
		failures.append("Presence refresh should probe an enabled online client even after a transient disconnect.")
	if not service.is_online():
		failures.append("Fresh heartbeat should keep the presence pill online even when another request toggled the client disconnected.")
	if service.is_stale():
		failures.append("Fresh heartbeat should not be marked stale.")

	client.set("online_enabled", false)
	if bool(service.call("_online_client_available")):
		failures.append("Disabled online client should not be probed.")
	client.set("online_enabled", true)
	client.set("access_token", "")
	if bool(service.call("_online_client_available")):
		failures.append("Presence refresh should not probe online endpoints without an access token.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	client.set("online_enabled", original_online_enabled)
	client.set("is_connected", original_is_connected)
	client.set("access_token", original_access_token)

	if failures.is_empty():
		print("presence service online state smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
