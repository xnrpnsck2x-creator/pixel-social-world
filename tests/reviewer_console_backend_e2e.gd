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
		"device_id": "reviewer-e2e-device",
		"display_name": "Reviewer E2E",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"current_route": "main_city",
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

	var login: Dictionary = await client.call("guest_login", "Reviewer E2E")
	if not Helpers.ok(login):
		failures.append("Reviewer E2E login failed: %s" % str(login))
	var submit: Dictionary = await client.call("submit_creator_package", Helpers.creator_package_manifest())
	if not Helpers.ok(submit):
		failures.append("Reviewer E2E package submit failed: %s" % str(submit))
	var status: Dictionary = await Helpers.wait_package_status(root, client, "creator_e2e_package")
	if not Helpers.package_status_ready(status):
		failures.append("Reviewer E2E package did not reach needs_review.")

	var denied: Dictionary = await client.call("fetch_reviewer_dashboard", "")
	if int(denied.get("status", 0)) != 403:
		failures.append("Reviewer dashboard without token was not blocked.")
	var dashboard: Dictionary = await client.call("fetch_reviewer_dashboard", "local-admin-token")
	if not Helpers.ok(dashboard) or not _dashboard_has_game(dashboard, "creator_e2e_package"):
		failures.append("Reviewer dashboard did not include submitted package.")
	var chat_message: Dictionary = await client.call(
		"send_chat",
		"world_town_square",
		"global",
		"Reviewer E2E",
		"chat report e2e"
	)
	if not Helpers.ok(chat_message):
		failures.append("Reviewer E2E chat send failed: %s" % str(chat_message))
	var reported_message := chat_message.get("data", {}) as Dictionary
	var report_response: Dictionary = await client.call(
		"report_chat_message",
		reported_message,
		"spam"
	)
	if not Helpers.ok(report_response):
		failures.append("Reviewer E2E chat report failed: %s" % str(report_response))
	var reports: Dictionary = await client.call("fetch_chat_reports_admin", "local-admin-token", "open")
	if not Helpers.ok(reports) or _chat_report_count(reports) < 1:
		failures.append("Chat report dashboard did not include submitted report.")
	var reviewed_report: Dictionary = await client.call(
		"review_chat_report_admin",
		str((report_response.get("data", {}) as Dictionary).get("id", "")),
		"reviewed",
		"local-admin-token",
		"handled"
	)
	if not Helpers.ok(reviewed_report) or str((reviewed_report.get("data", {}) as Dictionary).get("status", "")) != "reviewed":
		failures.append("Chat report review action failed: %s" % str(reviewed_report))
	var moderation: Dictionary = await client.call("apply_chat_moderation_admin", {
		"target_player_id": str(reported_message.get("sender_id", "")),
		"target_name": str(reported_message.get("sender_name", "")),
		"action": "mute",
		"scope": "room",
		"room_id": "world_town_square",
		"duration_seconds": 60,
		"reason": "reviewer e2e mute",
		"report_id": str((report_response.get("data", {}) as Dictionary).get("id", ""))
	}, "local-admin-token")
	if not Helpers.ok(moderation):
		failures.append("Chat moderation action failed: %s" % str(moderation))
	var moderation_csv: Dictionary = await client.call(
		"export_chat_moderation_admin",
		"local-admin-token",
		str(reported_message.get("sender_id", "")),
		"mute",
		0
	)
	if not Helpers.ok(moderation_csv) or not _csv_contains(moderation_csv, "target_player_id"):
		failures.append("Chat moderation CSV export failed: %s" % str(moderation_csv))

	var approve: Dictionary = await client.call("review_minigame_admin", "creator_e2e_package", "approve", "local-admin-token")
	if not Helpers.ok(approve) or str((approve.get("data", {}) as Dictionary).get("status", "")) != "approved":
		failures.append("Reviewer approve action failed: %s" % str(approve))
	var publish: Dictionary = await client.call("review_minigame_admin", "creator_e2e_package", "publish", "local-admin-token")
	if not Helpers.ok(publish) or str((publish.get("data", {}) as Dictionary).get("status", "")) != "published":
		failures.append("Reviewer publish action failed: %s" % str(publish))
	var catalog := await Helpers.raw_json(root, HTTPClient.METHOD_GET, "/minigames/catalog", {}, "")
	if int(catalog.get("status", 0)) != 200 or _catalog_missing_game(catalog, "creator_e2e_package"):
		failures.append("Published reviewer package did not enter catalog.")
	var unpublish: Dictionary = await client.call("review_minigame_admin", "creator_e2e_package", "unpublish", "local-admin-token", true, "reviewer e2e unpublish")
	if not Helpers.ok(unpublish) or str((unpublish.get("data", {}) as Dictionary).get("status", "")) != "approved":
		failures.append("Reviewer unpublish action failed: %s" % str(unpublish))
	var audit: Dictionary = await client.call("fetch_reviewer_audit", "creator_e2e_package", "local-admin-token")
	if not Helpers.ok(audit) or _audit_count(audit) < 3:
		failures.append("Reviewer audit did not record action history: %s" % str(audit))
	var audit_csv: Dictionary = await client.call("export_reviewer_audit_admin", "creator_e2e_package", "local-admin-token", {})
	if not Helpers.ok(audit_csv) or not _csv_contains(audit_csv, "creator_e2e_package"):
		failures.append("Reviewer audit CSV export failed: %s" % str(audit_csv))

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("reviewer console backend e2e passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _dashboard_has_game(response: Dictionary, game_id: String) -> bool:
	var items: Array = (response.get("data", {}) as Dictionary).get("items", []) as Array
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("game_id", "")) == game_id:
			return true
	return false

func _catalog_missing_game(response: Dictionary, game_id: String) -> bool:
	var items: Array = (response.get("body", {}) as Dictionary).get("items", []) as Array
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("game_id", "")) == game_id:
			return false
	return true

func _audit_count(response: Dictionary) -> int:
	return ((response.get("data", {}) as Dictionary).get("items", []) as Array).size()

func _chat_report_count(response: Dictionary) -> int:
	return ((response.get("data", {}) as Dictionary).get("items", []) as Array).size()

func _csv_contains(response: Dictionary, text: String) -> bool:
	return str((response.get("data", {}) as Dictionary).get("text", "")).contains(text)
