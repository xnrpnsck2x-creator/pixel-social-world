class_name BackendE2EHelpers
extends RefCounted

static func ok(response: Dictionary) -> bool:
	return bool(response.get("ok", false)) and not bool(response.get("offline", false))

static func history_contains(response: Dictionary, body: String) -> bool:
	if not ok(response):
		return false
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")) == body:
			return true
	return false

static func history_has_action(response: Dictionary, action_type: String, session_id: String) -> bool:
	if not ok(response):
		return false
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	for message in messages:
		if typeof(message) != TYPE_DICTIONARY:
			continue
		var action_value: Variant = (message as Dictionary).get("action", {})
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value as Dictionary
		if str(action.get("type", "")) == action_type and str(action.get("session_id", "")) == session_id:
			return true
	return false

static func history_empty(response: Dictionary) -> bool:
	if not ok(response):
		return false
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	return messages.is_empty()

static func members_include(response: Dictionary, player_id: String) -> bool:
	if not ok(response):
		return false
	var members: Array = (response.get("data", {}) as Dictionary).get("members", []) as Array
	for member in members:
		if typeof(member) == TYPE_DICTIONARY and str((member as Dictionary).get("player_id", "")) == player_id:
			return true
	return false

static func ledger_has_source_prefix(response: Dictionary, prefix: String) -> bool:
	if not ok(response):
		return false
	var events: Array = (response.get("data", {}) as Dictionary).get("events", []) as Array
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("source_id", "")).begins_with(prefix):
			return true
	return false

static func package_status_ready(response: Dictionary) -> bool:
	if not ok(response):
		return false
	var data: Dictionary = response.get("data", {}) as Dictionary
	return str(data.get("status", "")) == "needs_review" and not (data.get("package", {}) as Dictionary).is_empty()

static func wait_package_status(root: Node, client: Node, game_id: String) -> Dictionary:
	var response := {}
	for _attempt in range(80):
		response = await client.call("fetch_creator_submission_status", game_id)
		if package_status_ready(response):
			return response
		await root.get_tree().create_timer(0.25).timeout
	return response

static func verify_utility_panels(client: Node, failures: Array) -> void:
	var response: Dictionary = await client.call("fetch_utility_panels")
	if not ok(response):
		failures.append("Utility panels fetch failed: %s" % str(response))
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	if ((data.get("shop", {}) as Dictionary).get("items", []) as Array).is_empty():
		failures.append("Utility panels did not include backend shop items.")
	if ((data.get("mail", {}) as Dictionary).get("messages", []) as Array).is_empty():
		failures.append("Utility panels did not include backend mail messages.")

static func verify_profile_report(client: Node, failures: Array) -> void:
	var response: Dictionary = await client.call("report_player_profile", {
		"player_id": "profile-report-target",
		"display_name": "Profile Report Target"
	})
	if not ok(response):
		failures.append("Player profile report failed: %s" % str(response))
	elif str((response.get("data", {}) as Dictionary).get("channel_id", "")) != "profile":
		failures.append("Player profile report did not enter the moderation report queue.")

static func verify_first_session_reward(client: Node, player_id: String, failures: Array) -> void:
	var steps := ["npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"]
	var reward: Dictionary = await client.call("claim_first_session_reward", steps)
	if not ok(reward):
		failures.append("First session reward claim failed: %s" % str(reward))
		return
	var data: Dictionary = reward.get("data", {}) as Dictionary
	if int(data.get("delta", 0)) != 5:
		failures.append("First session reward did not grant 5 coins.")
	var replay: Dictionary = await client.call("claim_first_session_reward", steps)
	if not ok(replay) or int((replay.get("data", {}) as Dictionary).get("delta", -1)) != 0:
		failures.append("First session reward replay was not idempotent.")
	var ledger: Dictionary = await client.call("fetch_coin_ledger", player_id)
	if not ledger_has_source_prefix(ledger, "first_session.guide_complete"):
		failures.append("First session reward did not write backend ledger source.")

static func verify_map_activity_reward(root: Node, client: Node, player_id: String, save_system: Node, failures: Array) -> void:
	var service = load("res://scripts/Systems/Map/MapActivityService.gd").new()
	root.add_child(service)
	service.set_context("random_flower_valley_v1", null)
	var first: Dictionary = await service.perform_activity("explore")
	service.queue_free()
	if not bool(first.get("ok", false)) or int(first.get("reward_coins", 0)) != 1:
		failures.append("Online map activity did not grant the backend reward: %s" % str(first))
	if str(first.get("skill_id", "")) != "exploration" or int(first.get("skill_xp", 0)) != 2:
		failures.append("Online map activity did not expose skill XP: %s" % str(first))
	var drops: Array = first.get("drops", []) as Array
	if drops.is_empty() or str((drops[0] as Dictionary).get("item_id", "")) != "trail_token":
		failures.append("Online map activity did not expose configured drops: %s" % str(first))
	var activity_inventory: Dictionary = save_system.call("get_profile_value", "map_activity_inventory", {}) as Dictionary
	var trail_token: Dictionary = activity_inventory.get("trail_token", {}) as Dictionary
	if int(trail_token.get("quantity", 0)) != 1:
		failures.append("Online map activity did not sync server drop quantity locally: %s" % str(activity_inventory))
	var trade_inventory: Dictionary = await client.call("fetch_trade_inventory")
	if not ok(trade_inventory):
		failures.append("Trade inventory fetch after map activity failed: %s" % str(trade_inventory))
	elif not inventory_has_count((trade_inventory.get("data", {}) as Dictionary).get("items", []) as Array, "trail_token", "available", 1):
		failures.append("Map activity drop did not enter tradeable backend inventory: %s" % str(trade_inventory))
	var inventory: Dictionary = await client.call("fetch_inventory")
	if not ok(inventory):
		failures.append("Inventory fetch after map activity failed: %s" % str(inventory))
	elif not inventory_has_count((inventory.get("data", {}) as Dictionary).get("items", []) as Array, "trail_token", "available", 1):
		failures.append("Map activity drop did not enter generic backend inventory: %s" % str(inventory))
	var profile: Dictionary = await client.call("fetch_profile")
	var wallet: Dictionary = (profile.get("data", {}) as Dictionary).get("wallet", {}) as Dictionary
	if int(save_system.call("get_coin_balance")) != int(wallet.get("coin", -1)):
		failures.append("Online map activity did not sync the local wallet.")
	var replay: Dictionary = await client.call("claim_map_activity", "random_flower_valley_v1", "explore")
	if ok(replay) or int(replay.get("status", 0)) != 429:
		failures.append("Online map activity replay did not hit backend cooldown.")
	var ledger: Dictionary = await client.call("fetch_coin_ledger", player_id)
	if not ledger_has_source_prefix(ledger, "map_activity.explore."):
		failures.append("Online map activity did not write a backend ledger source.")

static func inventory_has_count(items: Array, item_id: String, field: String, expected: int) -> bool:
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw as Dictionary
		if str(item.get("item_id", "")) == item_id:
			return int(item.get(field, -1)) == expected
	return false

static func verify_creator_package_publish(root: Node, failures: Array) -> void:
	var package_approve := await raw_json(root, HTTPClient.METHOD_POST, "/minigames/creator_e2e_package/review", {
		"action": "approve"
	}, "local-admin-token")
	if int(package_approve.get("status", 0)) != 202:
		failures.append("Creator package approve action did not pass.")
	elif str((package_approve.get("body", {}) as Dictionary).get("status", "")) != "approved":
		failures.append("Creator package approve did not set approved status.")
	var package_publish := await raw_json(root, HTTPClient.METHOD_POST, "/minigames/creator_e2e_package/review", {
		"action": "publish"
	}, "local-admin-token")
	if int(package_publish.get("status", 0)) != 202:
		failures.append("Creator package publish action did not pass.")
	else:
		var publish_body: Dictionary = package_publish.get("body", {}) as Dictionary
		var publish_package: Dictionary = publish_body.get("package", {}) as Dictionary
		if str(publish_body.get("status", "")) != "published" or (publish_package.get("install", {}) as Dictionary).is_empty():
			failures.append("Creator package publish did not install runtime package.")
	var creator_catalog := await raw_json(root, HTTPClient.METHOD_GET, "/minigames/catalog", {}, "")
	if int(creator_catalog.get("status", 0)) != 200:
		failures.append("Creator minigame catalog did not load.")
	else:
		var catalog_items: Array = (creator_catalog.get("body", {}) as Dictionary).get("items", []) as Array
		if catalog_items.is_empty():
			failures.append("Creator minigame catalog did not include published package.")
	var package_unpublish := await raw_json(root, HTTPClient.METHOD_POST, "/minigames/creator_e2e_package/review", {
		"action": "unpublish",
		"confirm": true,
		"note": "backend e2e unpublish"
	}, "local-admin-token")
	if int(package_unpublish.get("status", 0)) != 202:
		failures.append("Creator package unpublish action did not pass.")
	elif str((package_unpublish.get("body", {}) as Dictionary).get("status", "")) != "approved":
		failures.append("Creator package unpublish did not return to approved status.")
	var unpublished_catalog := await raw_json(root, HTTPClient.METHOD_GET, "/minigames/catalog", {}, "")
	if int(unpublished_catalog.get("status", 0)) == 200:
		var unpublished_items: Array = (unpublished_catalog.get("body", {}) as Dictionary).get("items", []) as Array
		for item in unpublished_items:
			if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("game_id", "")) == "creator_e2e_package":
				failures.append("Creator minigame catalog still included unpublished package.")

static func raw_json(
	root: Node,
	method: int,
	path: String,
	payload: Dictionary,
	access_token: String
) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer %s" % access_token)
	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)
	var error_code := request.request("http://127.0.0.1:18787%s" % path, headers, method, body)
	if error_code != OK:
		request.queue_free()
		return {"status": 0, "error": "request_failed"}
	var completed: Array = await request.request_completed
	request.queue_free()
	return {
		"status": int(completed[1]),
		"body": JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	}

static func creator_admin_manifest() -> Dictionary:
	return {
		"game_id": "creator_e2e",
		"version": "1.0.0",
		"author": "Backend E2E",
		"mode_id": "casual_activity",
		"name": {"en": "Creator E2E", "ja": "Creator E2E", "zh": "Creator E2E"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "contained",
			"input_profile": "tap_timing",
			"network_profile": "offline_optional"
		},
		"entry_scene": "res://creator/creator_e2e/main.tscn",
		"main_script": "res://creator/creator_e2e/game.gd",
		"asset_budget_bytes": 5242880
	}

static func creator_draft_manifest() -> Dictionary:
	return {
		"game_id": "creator_e2e_draft",
		"version": "0.1.0",
		"mode_id": "2d_fighting",
		"name": {"en": "Creator Draft", "ja": "Creator Draft", "zh": "Creator Draft"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e", "fighting"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "side_view",
			"input_profile": "fighting_action",
			"network_profile": "authoritative_realtime"
		},
		"entry_scene": "res://creator/creator_e2e_draft/main.tscn",
		"main_script": "res://creator/creator_e2e_draft/game.gd",
		"asset_budget_bytes": 5242880
	}

static func creator_package_manifest() -> Dictionary:
	var manifest := {
		"game_id": "creator_e2e_package",
		"version": "0.1.0",
		"mode_id": "2d_fighting",
		"name": {"en": "Creator Package", "ja": "Creator Package", "zh": "Creator Package"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e", "package", "fighting"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "side_view",
			"input_profile": "fighting_action",
			"network_profile": "authoritative_realtime"
		},
		"entry_scene": "res://creator/creator_e2e_package/main.tscn",
		"main_script": "res://creator/creator_e2e_package/game.gd",
		"asset_budget_bytes": 5242880
	}
	var meta_text := JSON.stringify(manifest)
	var script := "class_name CreatorE2EPackage\nextends IMinigame\n\nfunc get_game_id() -> String:\n\treturn \"creator_e2e_package\"\n"
	manifest["files"] = [
		_file("meta.json", meta_text),
		_file("main.tscn", "[gd_scene format=3]\n[node name=\"CreatorE2EPackage\" type=\"Node\"]"),
		_file("game.gd", script),
		_file("README.md", "Creator package E2E fixture.")
	]
	return manifest

static func _file(path: String, content: String) -> Dictionary:
	return {
		"path": path,
		"size_bytes": content.to_utf8_buffer().size(),
		"content_text": content
	}
