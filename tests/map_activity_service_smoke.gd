extends SceneTree

class FakeHUD:
	extends Node

	var coin_refresh_count := 0
	var status_messages: Array[String] = []

	func refresh_coin() -> void:
		coin_refresh_count += 1

	func show_status_message(message: String) -> void:
		status_messages.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-activity-smoke",
		"display_name": "Map Activity Smoke",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"map_activity_cooldowns": {},
		"discovered_world_map_ids": ["city_forest_dawn_v1"]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var chat_service = load("res://scripts/Systems/Chat/ChatService.gd").new()
	chat_service.initialize()
	root.add_child(chat_service)
	var fake_hud := FakeHUD.new()
	root.add_child(fake_hud)
	var service = load("res://scripts/Systems/Map/MapActivityService.gd").new()
	root.add_child(service)
	service.bind(chat_service, fake_hud)
	service.set_context("random_flower_valley_v1", null)

	var first: Dictionary = await service.perform_activity("explore")
	if not bool(first.get("ok", false)) or int(first.get("reward_coins", 0)) != 1:
		failures.append("Explore activity did not grant the configured reward.")
	if save_system.call("get_coin_balance") != 1 or not save_system.call("validate_coin_ledger"):
		failures.append("Explore activity did not update the coin ledger cleanly.")
	var activity_inventory: Dictionary = save_system.call("get_profile_value", "map_activity_inventory", {}) as Dictionary
	var trail_token: Dictionary = activity_inventory.get("trail_token", {}) as Dictionary
	if int(trail_token.get("quantity", 0)) != 1:
		failures.append("Explore activity did not grant its configured local drop.")
	var skill_xp: Dictionary = save_system.call("get_profile_value", "map_activity_skill_xp", {}) as Dictionary
	if int(skill_xp.get("exploration", 0)) != 2:
		failures.append("Explore activity did not grant its configured skill XP.")
	if fake_hud.coin_refresh_count < 1 or fake_hud.status_messages.is_empty():
		failures.append("Explore activity did not refresh HUD status feedback.")
	elif not fake_hud.status_messages[0].contains("Trail Token") or not fake_hud.status_messages[0].contains("Exploration"):
		failures.append("Explore activity HUD feedback did not include skill XP and drop summary.")
	var cooldown: Dictionary = await service.perform_activity("explore")
	if bool(cooldown.get("ok", true)) or str(cooldown.get("error", "")) != "cooldown":
		failures.append("Explore activity ignored its per-map cooldown.")
	if save_system.call("get_coin_balance") != 1:
		failures.append("Cooldown activity granted duplicate coins.")
	if fake_hud.status_messages.size() < 2:
		failures.append("Cooldown activity did not show HUD feedback.")
	var daily_claims: Dictionary = save_system.call("get_profile_value", "map_activity_daily_claims", {}) as Dictionary
	daily_claims[service.call("_daily_claim_key", "explore")] = 10
	save_system.call("set_profile_value", "map_activity_daily_claims", daily_claims)
	save_system.call("set_profile_value", "map_activity_cooldowns", {})
	var limited: Dictionary = await service.perform_activity("explore")
	if bool(limited.get("ok", true)) or str(limited.get("error", "")) != "daily_limit":
		failures.append("Explore activity ignored its daily reward limit.")
	if save_system.call("get_coin_balance") != 1:
		failures.append("Daily limited activity granted duplicate coins.")

	service.set_context("season_cherry_blossom_fair_v1", null)
	var seasonal: Dictionary = await service.perform_activity("seasonal_event")
	if not bool(seasonal.get("ok", false)) or save_system.call("get_coin_balance") != 3:
		failures.append("Seasonal activity did not grant the configured two-coin reward.")
	var unknown: Dictionary = await service.perform_activity("missing_action")
	if bool(unknown.get("ok", true)) or str(unknown.get("error", "")) != "unknown":
		failures.append("Unknown map activity did not fail closed.")

	chat_service.queue_free()
	fake_hud.queue_free()
	service.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map activity service smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
