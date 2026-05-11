extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "utility-panel-ui-smoke",
		"device_id": "test-device",
		"display_name": "Utility UI",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"owned_items": ["starter_wallpaper"],
		"house_items": []
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/ui/WorldUtilityPanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame

	if not _panel_uses_main_frame(panel):
		failures.append("World utility panel did not use the formal main Image 2 panel frame.")
	panel.call("show_panel", "shop")
	await process_frame
	if not _node_tree_contains(panel, "Simple Chair"):
		failures.append("Shop utility panel did not render configured stock.")
	if not _rows_scan_friendly(panel):
		failures.append("Shop utility rows can stretch buttons or wrap copy into a narrow column.")
	panel.call("show_panel", "mail")
	await process_frame
	if not _node_tree_contains(panel, "Welcome home"):
		failures.append("Mail utility panel did not render configured messages.")
	if not _rows_scan_friendly(panel):
		failures.append("Mail utility rows can stretch buttons or wrap copy into a narrow column.")
	panel.call("set_compact_layout", true)
	panel.call("show_panel", "creator")
	await process_frame
	if panel.get_node("%BodyLabel").max_lines_visible != 1 or panel.get_node("%ItemsScroll").custom_minimum_size.y < 112.0:
		failures.append("Compact creator panel did not trade long intro copy for more row space.")
	var compact_mode_detail := _find_label(panel, "Contained")
	if compact_mode_detail == null:
		failures.append("Compact creator rows did not expose mode runtime details.")
	elif compact_mode_detail.autowrap_mode != TextServer.AUTOWRAP_OFF:
		failures.append("Compact creator mode details should stay one-line scan text.")
	if _node_tree_contains(panel, "Small social games"):
		failures.append("Compact creator rows should not spend first-screen space on long summaries.")
	var compact_icon := _find_texture_rect(panel.get_node("%ItemsRows"))
	if compact_icon == null or compact_icon.custom_minimum_size.x > 24.0:
		failures.append("Compact creator rows should use smaller icons to avoid stretched row cards.")

	panel.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("world utility panel ui smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _panel_uses_main_frame(node: Node) -> bool:
	if not node is PanelContainer:
		return false
	var style := (node as PanelContainer).get_theme_stylebox("panel")
	if not style is StyleBoxTexture:
		return false
	var texture := (style as StyleBoxTexture).texture
	return texture != null and texture.resource_path.ends_with("ui_panel_frame_v1_alpha.png")

func _rows_scan_friendly(panel: Node) -> bool:
	var rows := panel.find_child("ItemsRows", true, false)
	return rows != null and _node_scan_friendly(rows)

func _node_scan_friendly(node: Node) -> bool:
	if node is Button:
		var button := node as Button
		if not button.text.is_empty() and button.size_flags_vertical != Control.SIZE_SHRINK_CENTER:
			return false
	if node is Label:
		var label := node as Label
		if not label.text.is_empty() and label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return false
	for child in node.get_children():
		if not _node_scan_friendly(child):
			return false
	return true

func _node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _node_tree_contains(child, text):
			return true
	return false

func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.contains(text):
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null

func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for child in node.get_children():
		var found := _find_texture_rect(child)
		if found != null:
			return found
	return null
