extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/ChatReportsConsolePanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame

	panel.call("set_reports_snapshot", {
		"items": [
			{
				"id": "report-1",
				"room_id": "world_town_square",
				"reason": "spam",
				"status": "open",
				"message_sender_id": "player_reported",
				"message_sender_name": "Ari",
				"message_body": "please check this reported chat"
			}
		]
	})
	await process_frame

	if not _node_text_contains(panel, "Chat Reports"):
		failures.append("Chat reports console did not render localized title.")
	if not _node_text_contains(panel, "Ari"):
		failures.append("Chat reports console did not render report sender.")
	if not _node_text_contains(panel, "please check"):
		failures.append("Chat reports console did not render reported message body.")
	for label in ["Mute 1h", "Reviewed", "Dismiss"]:
		if not _node_text_contains(panel, label):
			failures.append("Chat reports console did not render %s action." % label)
	if not _has_image2_panel(panel):
		failures.append("Chat reports console is not using an Image 2 panel frame.")

	panel.queue_free()
	if failures.is_empty():
		print("chat reports console smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false

func _has_image2_panel(control: Control) -> bool:
	var style := control.get_theme_stylebox("panel")
	return style is StyleBoxTexture
