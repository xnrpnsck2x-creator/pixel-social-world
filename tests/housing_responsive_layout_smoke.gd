extends SceneTree

const HousingRoomResponsiveLayout := preload("res://scripts/UI/Panels/HousingRoomResponsiveLayout.gd")
const HousingRoomRenderer := preload("res://scripts/UI/Panels/HousingRoomRenderer.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(960, 540)

	var room_root := Node2D.new()
	root.add_child(room_root)
	var top_panel := PanelContainer.new()
	var owner_label := Label.new()
	var invite_button := Button.new()
	var rotate_button := Button.new()
	var social_panel := PanelContainer.new()
	var catalog_bar := PanelContainer.new()
	top_panel.add_child(owner_label)
	top_panel.add_child(invite_button)
	top_panel.add_child(rotate_button)

	var layout = HousingRoomResponsiveLayout.new()
	layout.apply(
		room_root,
		top_panel,
		owner_label,
		invite_button,
		social_panel,
		catalog_bar,
		null,
		null,
		false
	)

	if owner_label.visible:
		failures.append("Housing 960x540 layout kept the long owner label visible.")
	if invite_button.visible:
		failures.append("Housing 960x540 layout kept the invite button visible.")
	if not is_equal_approx(top_panel.offset_bottom, 44.0):
		failures.append("Housing 960x540 layout did not use compact top height.")
	if social_panel.offset_top > 56.0:
		failures.append("Housing 960x540 layout left the social panel too low.")
	var social_width := social_panel.offset_right - social_panel.offset_left
	if social_width > 250.0:
		failures.append("Housing 960x540 social panel stayed too wide for compact landscape.")
	if social_panel.offset_right > -24.0:
		failures.append("Housing 960x540 social panel stayed too close to the right edge.")
	var catalog_height := catalog_bar.offset_bottom - catalog_bar.offset_top
	if catalog_bar.offset_bottom > -24.0 or catalog_height > 96.0:
		failures.append("Housing 960x540 layout did not keep the catalog bar compact and above the screen edge.")
	var catalog_width := catalog_bar.offset_right - catalog_bar.offset_left
	if catalog_width > 640.0:
		failures.append("Housing 960x540 catalog bar still stretches across too much of the screen.")
	if rotate_button.custom_minimum_size.y > 28.0:
		failures.append("Housing 960x540 layout did not compact toolbar buttons.")

	var renderer = HousingRoomRenderer.new()
	renderer.set_responsive_layout(36.0, 274.0, 50.0, 96.0, true)
	var tile: Vector2i = renderer.tile_from_position(room_root, renderer.grid_origin(root.size) + Vector2(18.0, 18.0))
	if tile != Vector2i(0, 0):
		failures.append("Housing renderer used physical pixels instead of logical viewport size.")

	top_panel.free()
	social_panel.free()
	catalog_bar.free()
	room_root.free()
	if failures.is_empty():
		print("housing responsive layout smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
