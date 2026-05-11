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
	if _panel_descendant_count(panel.get_node("%MailRows")) < 1:
		failures.append("Mailbox rows did not use v2 row cards.")
	panel.call("set_compact_layout", true)
	await panel.call("show_panel", "mail")
	if panel.get_node("%MailScroll").custom_minimum_size.y > 100.0:
		failures.append("Compact mailbox did not reduce scroll height.")
	if _panel_descendant_count(panel.get_node("%MailRows")) < 1:
		failures.append("Compact mailbox rows did not use v2 row cards.")
	var mail_icon := _find_texture_rect(panel.get_node("%MailRows"))
	if mail_icon == null or mail_icon.custom_minimum_size.x > 22.0:
		failures.append("Compact mailbox rows did not use the tighter mobile icon size: %s" % str(mail_icon.custom_minimum_size.x if mail_icon != null else -1.0))
	await panel.call("show_panel", "private")
	if panel.get_node("%PrivateScroll").custom_minimum_size.y > 80.0:
		failures.append("Compact private message list still takes too much vertical space.")
	if panel.get_node("%PrivateInput").placeholder_text != _t("messages.private.input_placeholder_short"):
		failures.append("Compact private input did not use the short placeholder.")
	if panel.get_node("%PrivateSendButton").text != _t("messages.private.send"):
		failures.append("Compact private send button should stay text-readable.")
	if panel.get_node("%PrivateReportButton").text != "":
		failures.append("Compact private report button should use icon-only chrome.")
	if panel.get_node("%PrivateReportButton").visible:
		failures.append("Compact private report button should stay hidden until a reportable message exists.")
	if panel.get_node("%PrivateReportButton").custom_minimum_size.x > 40.0:
		failures.append("Compact private report button still stretches too wide.")
	if panel.get_node("%PrivateInputRow").get_theme_constant("separation") > 4:
		failures.append("Compact private input row did not tighten spacing.")
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

func _panel_descendant_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is PanelContainer:
			count += 1
		count += _panel_descendant_count(child)
	return count

func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for child in node.get_children():
		var found := _find_texture_rect(child)
		if found != null:
			return found
	return null
