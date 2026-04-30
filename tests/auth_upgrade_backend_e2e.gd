extends SceneTree

const Helpers := preload("res://tests/BackendE2EHelpers.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "offline-player",
		"device_id": "auth-upgrade-e2e-device",
		"display_name": "Auth Upgrade E2E",
		"locale": "en",
		"coin_balance": 0,
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
		"offline_mode_enabled": false,
		"network": {
			"online_enabled": true,
			"base_url": "http://127.0.0.1:18787",
			"http_timeout_seconds": 2.0
		}
	})

	var login: Dictionary = await client.call("guest_login", "Auth Upgrade E2E")
	if not Helpers.ok(login):
		failures.append("Guest login failed: %s" % str(login))
	var player_id := str(client.get("player_id"))
	var original_access := str(client.get("access_token"))
	var upgrade: Dictionary = await client.call("upgrade_guest_account", {
		"provider": "google",
		"platform": "web",
		"provider_subject": "h5-e2e-%d" % Time.get_ticks_msec(),
		"identity_token": "dummy-h5-token",
		"email": "h5-e2e@example.test"
	})
	if not Helpers.ok(upgrade):
		failures.append("Guest upgrade failed: %s" % str(upgrade))
	if str(client.get("player_id")) != player_id:
		failures.append("Guest upgrade changed player id.")
	if str(client.get("access_token")) == original_access:
		failures.append("Guest upgrade did not rotate access token.")
	var data: Dictionary = upgrade.get("data", {}) as Dictionary
	var linked: Dictionary = data.get("linked_account", {}) as Dictionary
	if str(linked.get("platform", "")) != "h5":
		failures.append("Backend did not normalize web platform to h5.")
	var stored_link: Dictionary = save_system.call("get_profile_value", "linked_account", {}) as Dictionary
	if str(stored_link.get("provider", "")) != "google":
		failures.append("Linked account metadata was not stored locally.")
	var profile: Dictionary = await client.call("fetch_profile")
	if not Helpers.ok(profile):
		failures.append("Upgraded session could not fetch profile: %s" % str(profile))

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("auth upgrade backend e2e passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
