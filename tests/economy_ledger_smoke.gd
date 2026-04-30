extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system: Node = root.get_node("SaveSystem")
	var original_profile: Dictionary = save_system.call("load_profile").duplicate(true)
	save_system.set("profile", {
		"display_name": "Ledger Test",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": []
	})
	save_system.call("_apply_defaults")

	if not bool(save_system.call("validate_coin_ledger")):
		failures.append("Fresh profile ledger did not validate.")

	save_system.call("grant_coins", 10, "test.reward")
	if not bool(save_system.call("spend_coins", 8, "test.spend")):
		failures.append("Spend failed unexpectedly.")
	if int(save_system.call("get_coin_balance")) != 27:
		failures.append("Balance did not match ledger operations.")
	if not bool(save_system.call("validate_coin_ledger")):
		failures.append("Ledger did not validate after grant/spend.")

	var ledger: Array = save_system.call("get_coin_ledger")
	var tampered: Dictionary = (ledger[1] as Dictionary).duplicate(true)
	tampered["delta"] = 99
	ledger[1] = tampered
	var profile: Dictionary = save_system.get("profile")
	profile["coin_ledger"] = ledger
	save_system.set("profile", profile)
	if bool(save_system.call("validate_coin_ledger")):
		failures.append("Tampered ledger passed validation.")

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("economy ledger smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
