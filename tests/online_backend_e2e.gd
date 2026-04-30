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
		"device_id": "backend-e2e-device",
		"display_name": "Backend E2E",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"current_route": "login",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
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

	var login: Dictionary = await client.call("guest_login", "Backend E2E")
	if not Helpers.ok(login):
		failures.append("Guest login failed: %s" % str(login))
	var player_id := str(client.get("player_id"))
	if not player_id.begins_with("guest_"):
		failures.append("Guest login did not set a backend player id: %s" % player_id)

	var original_access_token := str(client.get("access_token"))
	var refresh: Dictionary = await client.call("refresh_session")
	if not Helpers.ok(refresh):
		failures.append("Token refresh failed: %s" % str(refresh))
	if str(client.get("access_token")) == original_access_token:
		failures.append("Token refresh did not rotate the access token.")

	var profile: Dictionary = await client.call("fetch_profile")
	if not Helpers.ok(profile):
		failures.append("Profile fetch failed: %s" % str(profile))
	var wallet: Dictionary = (profile.get("data", {}) as Dictionary).get("wallet", {}) as Dictionary
	if int(wallet.get("coin", -1)) != 25:
		failures.append("Backend profile did not return starting 25 coins.")
	if int(save_system.call("get_coin_balance")) != 25:
		failures.append("Local wallet did not sync backend balance.")

	await Helpers.verify_utility_panels(client, failures)

	var presence: Dictionary = await client.call("send_presence", "world_town_square", "Backend E2E")
	if not Helpers.ok(presence):
		failures.append("Presence heartbeat failed: %s" % str(presence))
	var members: Dictionary = await client.call("fetch_room_members", "world_town_square")
	if not Helpers.members_include(members, player_id):
		failures.append("Room members did not include the heartbeat player.")

	var chat_body := "backend e2e %d" % Time.get_ticks_msec()
	var chat: Dictionary = await client.call("send_chat", "world_town_square", "global", "Backend E2E", chat_body, {"action": {"type": "join_minigame", "game_id": "fishing", "session_id": "session_online"}})
	if not Helpers.ok(chat):
		failures.append("Chat send failed: %s" % str(chat))
	var chat_action: Dictionary = (chat.get("data", {}) as Dictionary).get("action", {}) as Dictionary
	if str(chat_action.get("session_id", "")) != "session_online":
		failures.append("Chat send did not preserve join_minigame action: %s" % str(chat))
	var history: Dictionary = await client.call("fetch_chat_history", "world_town_square", "global", 5)
	if not Helpers.history_empty(history):
		failures.append("Room chat history should be ephemeral and empty.")
	await Helpers.verify_profile_report(client, failures)

	var session_response: Dictionary = await client.call("create_minigame_session", "fishing", "world_town_square", 2)
	if not Helpers.ok(session_response):
		failures.append("Minigame session create failed: %s" % str(session_response))
	var session_id := str((session_response.get("data", {}) as Dictionary).get("id", ""))
	if session_id.is_empty():
		failures.append("Minigame session id was empty.")
	var join_response: Dictionary = await client.call("join_minigame_session", session_id)
	if not Helpers.ok(join_response):
		failures.append("Minigame session join failed: %s" % str(join_response))

	var place_response: Dictionary = await client.call(
		"place_housing_item",
		player_id,
		"simple_chair",
		Vector2i(1, 2),
		0
	)
	if not Helpers.ok(place_response):
		failures.append("Housing place failed: %s" % str(place_response))
	var place_data: Dictionary = place_response.get("data", {}) as Dictionary
	if int(place_data.get("balance", -1)) != 0:
		failures.append("Housing place did not spend the starter 25 coins.")

	var moved_house_item := {
		"item_id": "simple_chair",
		"tile": {"x": 1, "y": 2},
		"rotation": 0
	}
	var move_response: Dictionary = await client.call(
		"move_housing_item",
		player_id,
		moved_house_item,
		Vector2i(2, 2),
		90
	)
	if not Helpers.ok(move_response):
		failures.append("Housing move failed: %s" % str(move_response))
	var moved_layout: Dictionary = (move_response.get("data", {}) as Dictionary).get("layout", {}) as Dictionary
	var moved_items: Array = moved_layout.get("items", []) as Array
	if moved_items.is_empty() or int((moved_items[0] as Dictionary).get("rotation", -1)) != 90:
		failures.append("Housing move did not persist rotation.")

	var house_invite: Dictionary = await client.call("create_housing_invite", player_id)
	if not Helpers.ok(house_invite):
		failures.append("Housing invite failed: %s" % str(house_invite))
	var house_room_id := str((house_invite.get("data", {}) as Dictionary).get("room_id", ""))
	if house_room_id != "home:%s" % player_id:
		failures.append("Housing invite returned an unexpected room id: %s" % house_room_id)

	var ledger: Dictionary = await client.call("fetch_coin_ledger", player_id)
	if not Helpers.ok(ledger):
		failures.append("Ledger fetch failed: %s" % str(ledger))
	var events: Array = (ledger.get("data", {}) as Dictionary).get("events", []) as Array
	if events.size() < 2:
		failures.append("Backend ledger did not include init and housing spend events.")

	var reject_response: Dictionary = await client.call(
		"place_housing_item",
		player_id,
		"simple_chair",
		Vector2i(4, 2),
		0
	)
	if Helpers.ok(reject_response) or int(reject_response.get("status", 0)) != 402:
		failures.append("Expected second housing place to fail with 402.")
	if not bool(client.get("is_connected")):
		failures.append("HTTP 402 should not mark OnlineClient disconnected.")

	var remove_response: Dictionary = await client.call("remove_housing_item", player_id, {
		"item_id": "simple_chair",
		"tile": {"x": 2, "y": 2},
		"rotation": 90
	})
	if not Helpers.ok(remove_response):
		failures.append("Housing remove failed: %s" % str(remove_response))
	var remove_data: Dictionary = remove_response.get("data", {}) as Dictionary
	if int(remove_data.get("refund", 0)) != 12 or int(remove_data.get("balance", -1)) != 12:
		failures.append("Housing remove did not grant configured sell refund.")

	var fishing_request_id := "e2e-fishing-%d" % Time.get_ticks_msec()
	var catch_response: Dictionary = await client.call("claim_fishing_catch", session_id, fishing_request_id)
	if not Helpers.ok(catch_response):
		failures.append("Fishing reward claim failed: %s" % str(catch_response))
	var catch_data: Dictionary = catch_response.get("data", {}) as Dictionary
	var fishing_reward := int(catch_data.get("reward_coin", 0))
	if fishing_reward <= 0:
		failures.append("Fishing reward did not return a positive coin amount.")
	if str(catch_data.get("rarity", "")).is_empty():
		failures.append("Fishing reward did not return a rarity callout id.")
	var replay_response: Dictionary = await client.call("claim_fishing_catch", session_id, fishing_request_id)
	if not Helpers.ok(replay_response):
		failures.append("Fishing reward idempotent replay failed: %s" % str(replay_response))
	var replay_data: Dictionary = replay_response.get("data", {}) as Dictionary
	if int(replay_data.get("catch_number", -1)) != int(catch_data.get("catch_number", -2)):
		failures.append("Fishing reward replay changed catch number.")
	if int(replay_data.get("balance", -1)) != int(catch_data.get("balance", -2)):
		failures.append("Fishing reward replay changed wallet balance.")
	var rewarded_profile: Dictionary = await client.call("fetch_profile")
	var rewarded_wallet: Dictionary = (rewarded_profile.get("data", {}) as Dictionary).get("wallet", {}) as Dictionary
	if int(rewarded_wallet.get("coin", -1)) != fishing_reward + 12:
		failures.append("Fishing reward did not sync to the backend wallet.")
	var rewarded_ledger: Dictionary = await client.call("fetch_coin_ledger", player_id)
	if not Helpers.ledger_has_source_prefix(rewarded_ledger, "minigame.fishing."):
		failures.append("Fishing reward did not write a backend ledger event.")

	var access_token := str(client.get("access_token"))
	var spoof_chat := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/chat/send", {
		"room_id": "world_town_square",
		"channel_id": "global",
		"sender_id": "guest_spoof",
		"sender_name": "Spoof",
		"body": "spoof"
	}, access_token)
	if int(spoof_chat.get("status", 0)) != 401:
		failures.append("Spoofed chat sender was not rejected.")

	var spoof_house := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/housing/place", {
		"owner_id": "guest_spoof",
		"player_id": player_id,
		"item_id": "simple_chair",
		"tile_x": 3,
		"tile_y": 3,
		"rotation": 0
	}, access_token)
	if int(spoof_house.get("status", 0)) != 403:
		failures.append("Cross-owner housing mutation was not rejected.")

	var public_reward := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/economy/reward", {
		"player_id": player_id,
		"source_id": "e2e.public_reward",
		"amount": 100
	}, access_token)
	if int(public_reward.get("status", 0)) != 403:
		failures.append("Public reward endpoint was not blocked.")

	var creator_submit := Helpers.creator_admin_manifest()
	var creator_draft := Helpers.creator_draft_manifest()
	var draft_submit: Dictionary = await client.call("submit_creator_draft", creator_draft)
	if not Helpers.ok(draft_submit):
		failures.append("Creator draft submit failed: %s" % str(draft_submit))
	var draft_status: Dictionary = await client.call("fetch_creator_submission_status", "creator_e2e_draft")
	if not Helpers.ok(draft_status):
		failures.append("Creator draft status failed: %s" % str(draft_status))
	else:
		var draft_data: Dictionary = draft_status.get("data", {}) as Dictionary
		if str(draft_data.get("status", "")) != "pending_review":
			failures.append("Creator draft status did not return pending_review.")
	var package_submit: Dictionary = await client.call("submit_creator_package", Helpers.creator_package_manifest())
	if not Helpers.ok(package_submit):
		failures.append("Creator package submit failed: %s" % str(package_submit))
	var package_status: Dictionary = await Helpers.wait_package_status(root, client, "creator_e2e_package")
	if not Helpers.package_status_ready(package_status):
		failures.append("Creator package status did not include needs_review scan data.")
	var package_history: Dictionary = await client.call("fetch_creator_submission_history", "creator_e2e_package")
	if not Helpers.ok(package_history) or (((package_history.get("data", {}) as Dictionary).get("items", []) as Array).is_empty()):
		failures.append("Creator package history did not include version records.")
	var submit_denied := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/minigames/submit", creator_submit, access_token)
	if int(submit_denied.get("status", 0)) != 403:
		failures.append("Creator submit without admin token was not blocked.")
	var submit_allowed := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/minigames/submit", creator_submit, "local-admin-token")
	if int(submit_allowed.get("status", 0)) != 202:
		failures.append("Creator submit with admin token did not pass.")
	var ops_denied := await Helpers.raw_json(root, HTTPClient.METHOD_GET, "/debug/ops", {}, "")
	if int(ops_denied.get("status", 0)) != 403:
		failures.append("Debug ops without admin token was not blocked.")
	var ops_allowed := await Helpers.raw_json(root, HTTPClient.METHOD_GET, "/debug/ops", {}, "local-admin-token")
	if int(ops_allowed.get("status", 0)) != 200:
		failures.append("Debug ops with admin token did not pass.")
	else:
		var ops_body: Dictionary = ops_allowed.get("body", {}) as Dictionary
		if not ops_body.has("chat") or not ops_body.has("fishing_rewards"):
			failures.append("Debug ops did not include chat and fishing reward stats.")
	await Helpers.verify_creator_package_publish(root, failures)

	var visitor_login: Dictionary = await client.call("guest_login", "Visitor E2E")
	if not Helpers.ok(visitor_login):
		failures.append("Visitor login failed: %s" % str(visitor_login))
	var visitor_id := str(client.get("player_id"))
	var visit_home: Dictionary = await client.call("visit_housing", player_id)
	if not Helpers.ok(visit_home):
		failures.append("Housing visit failed: %s" % str(visit_home))
	var visit_data: Dictionary = visit_home.get("data", {}) as Dictionary
	if bool(visit_data.get("can_edit", true)):
		failures.append("Visitor should not be able to edit another player's home.")
	if str(visit_data.get("room_id", "")) != house_room_id:
		failures.append("Housing visit did not return the invite room id.")
	var visit_layout: Dictionary = visit_data.get("layout", {}) as Dictionary
	if str(visit_layout.get("owner_id", "")) != player_id:
		failures.append("Housing visit did not return the owner's layout.")
	var house_presence: Dictionary = await client.call("send_presence", house_room_id, "Visitor E2E")
	if not Helpers.ok(house_presence):
		failures.append("Visitor house presence failed: %s" % str(house_presence))
	var house_members: Dictionary = await client.call("fetch_room_members", house_room_id)
	if not Helpers.members_include(house_members, visitor_id):
		failures.append("House members did not include the visiting player.")
	var house_chat_body := "house visit e2e %d" % Time.get_ticks_msec()
	var house_chat: Dictionary = await client.call("send_chat", house_room_id, "house", "Visitor E2E", house_chat_body)
	if not Helpers.ok(house_chat):
		failures.append("House chat failed: %s" % str(house_chat))
	var house_history: Dictionary = await client.call("fetch_chat_history", house_room_id, "house", 5)
	if not Helpers.history_empty(house_history):
		failures.append("House room chat history should be ephemeral and empty.")
	var visitor_place: Dictionary = await client.call("place_housing_item", player_id, "simple_chair", Vector2i(3, 3), 0)
	if Helpers.ok(visitor_place) or int(visitor_place.get("status", 0)) != 403:
		failures.append("Visitor was allowed to mutate the owner's home.")
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("online backend e2e passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
