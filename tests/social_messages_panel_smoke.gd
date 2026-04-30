extends SceneTree

const SocialMessagesPanelScene := preload("res://scenes/ui/SocialMessagesPanel.tscn")
const SocialMessagesPanelRowsScript := preload("res://scripts/UI/Panels/SocialMessagesPanelRows.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var panel := SocialMessagesPanelScene.instantiate()
	root.add_child(panel)
	await panel.call("show_panel", "mail")
	if not panel.visible:
		failures.append("Social messages panel did not become visible.")
	if panel.get_node("%TitleLabel").text != _t("messages.title"):
		failures.append("Social messages title did not localize.")
	if panel.get_node("%MailTabButton").text != _t("messages.tab.mail"):
		failures.append("Mailbox tab did not render.")
	if panel.get_node("%StatusLabel").text != _t("messages.status.offline"):
		failures.append("Offline mailbox state did not render.")
	await panel.call("show_panel", "private")
	if not panel.get_node("%PrivateBox").visible:
		failures.append("Private tab did not become visible.")
	if panel.get_node("%PeerInput").placeholder_text != _t("messages.private.peer_placeholder"):
		failures.append("Private peer placeholder did not localize.")
	if panel.get_node("%ConversationScroll").custom_minimum_size.y <= 0:
		failures.append("Private conversation list did not reserve space.")
	if not panel.has_theme_stylebox_override("panel"):
		failures.append("Social messages panel is not using an Image 2 frame.")
	var unread_seen := [-1]
	panel.unread_count_changed.connect(func(count: int) -> void: unread_seen[0] = count)
	panel.call("_set_unread_count", 12)
	if int(panel.call("get_unread_count")) != 12 or int(unread_seen[0]) != 12:
		failures.append("Unread count signal did not publish mailbox state.")
	panel.queue_free()

	var unread := SocialMessagesPanelRowsScript.unread_count([
		{"id": "a", "read_at": 0},
		{"id": "b", "read_at": 42},
		{"id": "c"}
	])
	if unread != 2:
		failures.append("Social message row helper did not count unread mail.")

	if failures.is_empty():
		print("social messages panel smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _t(key: String) -> String:
	return str(root.get_node("App").call("t_key", key))
