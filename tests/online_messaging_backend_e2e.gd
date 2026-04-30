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
		"device_id": "messaging-e2e-device",
		"display_name": "Messaging E2E",
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

	var login: Dictionary = await client.call("guest_login", "Messaging E2E")
	if not Helpers.ok(login):
		failures.append("Guest login failed: %s" % str(login))
	var player_id := str(client.get("player_id"))
	var peer_id := "guest_peer_static"
	var private_body := "private e2e %d" % Time.get_ticks_msec()
	var private_send: Dictionary = await client.call("send_private_message", peer_id, private_body)
	if not Helpers.ok(private_send):
		failures.append("Private message send failed: %s" % str(private_send))
	elif str((private_send.get("data", {}) as Dictionary).get("conversation_id", "")).is_empty():
		failures.append("Private message did not return conversation_id.")
	var conversation: Dictionary = await client.call("fetch_private_conversation", peer_id, 10)
	if not _messages_contain(conversation, private_body):
		failures.append("Private conversation did not include sent message: %s" % str(conversation))
	var conversations: Dictionary = await client.call("fetch_private_conversations", 10)
	if not _conversations_contain(conversations, peer_id):
		failures.append("Private conversation summary did not include peer: %s" % str(conversations))
	var read_private: Dictionary = await client.call("mark_private_read", peer_id)
	if not Helpers.ok(read_private):
		failures.append("Private read marker failed: %s" % str(read_private))
	var private_report: Dictionary = await client.call(
		"report_private_message",
		private_send.get("data", {}) as Dictionary,
		"player_report"
	)
	if not Helpers.ok(private_report):
		failures.append("Private message report failed: %s" % str(private_report))

	var mail_subject := "Mailbox E2E"
	var mail_body := "mail e2e %d" % Time.get_ticks_msec()
	var mail_send: Dictionary = await client.call("send_mail", player_id, mail_subject, mail_body)
	if not Helpers.ok(mail_send):
		failures.append("Mail send failed: %s" % str(mail_send))
	var mail_id := str((mail_send.get("data", {}) as Dictionary).get("id", ""))
	if mail_id.is_empty():
		failures.append("Mail send did not return id.")
	var inbox: Dictionary = await client.call("fetch_mailbox", 10)
	if not _messages_contain(inbox, mail_body):
		failures.append("Mailbox inbox did not include sent mail: %s" % str(inbox))
	var read: Dictionary = await client.call("mark_mail_read", mail_id)
	if not Helpers.ok(read):
		failures.append("Mail read failed: %s" % str(read))
	elif int((read.get("data", {}) as Dictionary).get("read_at", 0)) <= 0:
		failures.append("Mail read did not set read_at: %s" % str(read))

	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("online messaging backend e2e passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _messages_contain(response: Dictionary, body: String) -> bool:
	if not Helpers.ok(response):
		return false
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")) == body:
			return true
	return false

func _conversations_contain(response: Dictionary, peer_id: String) -> bool:
	if not Helpers.ok(response):
		return false
	var conversations: Array = (response.get("data", {}) as Dictionary).get("conversations", []) as Array
	for conversation in conversations:
		if typeof(conversation) == TYPE_DICTIONARY and str((conversation as Dictionary).get("peer_id", "")) == peer_id:
			return true
	return false
