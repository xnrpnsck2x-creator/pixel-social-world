extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/ReviewerConsolePanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame

	panel.call("set_dashboard_snapshot", {
		"items": [
			_review_item("creator_review_ready", "needs_review", "completed", "clean", "not_installed"),
			_review_item("creator_review_approved", "approved", "completed", "clean", "not_installed"),
			_review_item("creator_review_live", "published", "completed", "clean", "published")
		]
	})
	await process_frame

	if not _node_text_contains(panel, "Reviewer Console"):
		failures.append("Reviewer console did not render localized title.")
	if not _node_text_contains(panel, "Creator Review Ready"):
		failures.append("Reviewer console did not render review item titles.")
	if not _node_text_contains(panel, "Action note"):
		failures.append("Reviewer console did not render the action note input.")
	for label in ["Approve", "Reject", "Publish", "Rollback", "Unpublish", "Export CSV"]:
		if not _node_text_contains(panel, label):
			failures.append("Reviewer console did not render %s action." % label)
	if not _has_image2_panel(panel):
		failures.append("Reviewer console is not using an Image 2 panel frame.")
	panel.call("set_audit_snapshot", {
		"game_id": "creator_review_ready",
		"items": [{"action": "approve", "status": "approved"}]
	})
	await process_frame
	if not _node_text_contains(panel, "Audit entries: 1"):
		failures.append("Reviewer console did not render audit summary.")

	panel.queue_free()

	if failures.is_empty():
		print("reviewer console smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _review_item(game_id: String, status: String, job: String, scan: String, install: String) -> Dictionary:
	return {
		"game_id": game_id,
		"version": "0.1.0",
		"author": "reviewer-smoke",
		"mode_id": "2d_fighting",
		"status": status,
		"name": {"en": game_id.capitalize().replace("_", " "), "ja": game_id, "zh-Hans": game_id},
		"scan": {"status": scan, "issue_count": 0},
		"ai": {"status": "approved", "risk_level": "low"},
		"job": {"status": job},
		"install": {"status": install}
	}

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	if node is LineEdit and (node as LineEdit).placeholder_text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false

func _has_image2_panel(control: Control) -> bool:
	var style := control.get_theme_stylebox("panel")
	return style is StyleBoxTexture
