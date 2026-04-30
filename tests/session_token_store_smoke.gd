extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "offline-player",
		"device_id": "session-store-device",
		"coin_balance": 25,
		"coin_ledger": []
	})
	save_system.call("_apply_defaults")

	var store := root.get_node("SessionTokenStore")
	store.call("save_session", {
		"player_id": "web-player",
		"session_id": "session-web",
		"access_token": "access-web",
		"refresh_token": "refresh-web"
	})
	var session: Dictionary = store.call("load_session")
	if str(session.get("player_id", "")) != "web-player":
		failures.append("SessionTokenStore did not load player_id.")
	if str(store.call("get_access_token", "")) != "access-web":
		failures.append("SessionTokenStore did not return access token.")
	if str(store.call("get_refresh_token", "")) != "refresh-web":
		failures.append("SessionTokenStore did not return refresh token.")
	if str(save_system.call("get_profile_value", "network_mode", "")) != "online":
		failures.append("SessionTokenStore did not sync SaveSystem network mode.")

	store.call("clear_session")
	if not str(store.call("get_access_token", "")).is_empty():
		failures.append("SessionTokenStore did not clear access token.")

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("session token store smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
