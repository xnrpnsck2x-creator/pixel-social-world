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
		"device_id": "test-device",
		"display_name": "",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "login",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": []
	})
	save_system.call("_apply_defaults")

	var client := root.get_node("OnlineClient")
	client.call("configure", {
		"offline_mode_enabled": true,
		"network": {
			"online_enabled": false,
			"base_url": "http://127.0.0.1:1",
			"http_timeout_seconds": 0.1
		}
	})
	var login: Dictionary = await client.call("guest_login", "Online Smoke")
	if not bool(login.get("ok", false)):
		failures.append("Offline fallback login did not return ok.")
	if not bool(login.get("offline", false)):
		failures.append("Offline fallback login did not mark offline=true.")
	if bool(client.get("is_connected")):
		failures.append("Client should stay disconnected when online is disabled.")
	if str(client.get("player_id")) != "offline-player":
		failures.append("Offline player id was not preserved.")
	var history: Dictionary = await client.call("fetch_creator_submission_history", "creator_missing")
	if str(history.get("error", "")) != "online_disabled":
		failures.append("Creator submission history did not route through OnlineClient endpoint.")
	var upgrade: Dictionary = await client.call("upgrade_guest_account", {
		"provider": "google",
		"platform": "h5",
		"provider_subject": "offline-web-subject",
		"identity_token": "dummy-h5-token"
	})
	if str(upgrade.get("error", "")) != "online_disabled":
		failures.append("Guest account upgrade did not route through OnlineClient auth endpoint.")
	var social: Dictionary = await client.call("social_action", "follow", "peer-smoke")
	if str(social.get("error", "")) != "online_disabled":
		failures.append("Social action did not route through OnlineClient endpoint.")

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("online client smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
