extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/ChatModerationAuditPanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame

	panel.call("set_moderation_snapshot", {
		"active": [{
			"id": "mod-1",
			"target_player_id": "player_muted",
			"target_name": "Muted Guest",
			"action": "mute",
			"scope": "room",
			"room_id": "world_town_square",
			"reason": "spam",
			"expires_at": int(Time.get_unix_time_from_system()) + 3600
		}],
		"recent": [{
			"id": "mod-2",
			"target_player_id": "player_restored",
			"target_name": "Restored Guest",
			"action": "restore",
			"scope": "room",
			"room_id": "world_town_square",
			"reason": "appeal",
			"created_at": 1777500000
		}]
	})
	await process_frame

	for text in ["Moderation Audit", "Muted Guest", "Restore", "Restored Guest", "spam", "Export CSV", "Target player id", "All actions"]:
		if not _node_text_contains(panel, text):
			failures.append("Moderation audit panel missing text: %s" % text)
	if not _has_image2_panel(panel):
		failures.append("Moderation audit panel is not using an Image 2 panel frame.")

	panel.queue_free()
	if failures.is_empty():
		print("chat moderation audit smoke passed")
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
	if node is LineEdit and (node as LineEdit).placeholder_text.contains(text):
		return true
	if node is OptionButton:
		var option := node as OptionButton
		for index in range(option.item_count):
			if option.get_item_text(index).contains(text):
				return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false

func _has_image2_panel(control: Control) -> bool:
	var style := control.get_theme_stylebox("panel")
	return style is StyleBoxTexture
