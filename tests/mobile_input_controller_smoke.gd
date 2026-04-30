extends SceneTree

const MobileInputController := preload("res://scripts/UI/HUD/WorldHUDMobileInputController.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(844, 390)
	DisplayServer.window_set_size(Vector2i(844, 390))

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)

	var bottom_bar := PanelContainer.new()
	holder.add_child(bottom_bar)
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -104.0
	bottom_bar.offset_bottom = 0.0

	var side_panel := PanelContainer.new()
	holder.add_child(side_panel)
	side_panel.anchor_left = 1.0
	side_panel.anchor_right = 1.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = -300.0
	side_panel.offset_right = -12.0
	side_panel.offset_top = 68.0
	side_panel.offset_bottom = -104.0

	var input := LineEdit.new()
	side_panel.add_child(input)
	var controller = MobileInputController.new()
	controller.viewport_size_override = Vector2(844, 390)
	controller.bind(bottom_bar, [input], [side_panel])

	controller.call("_on_focus_entered", input)
	await process_frame
	if bottom_bar.offset_top >= -104.0:
		failures.append("Focused mobile chat input did not raise the bottom bar.")
	if side_panel.offset_top >= 68.0:
		failures.append("Focused mobile side-panel input did not raise its panel.")
	if side_panel.offset_top < 7.5:
		failures.append("Focused mobile side panel moved past the top safe area.")

	controller.call("_on_focus_exited")
	await process_frame
	if not is_equal_approx(bottom_bar.offset_top, -104.0):
		failures.append("Mobile input controller did not restore the bottom bar after blur.")
	if not is_equal_approx(side_panel.offset_top, 68.0):
		failures.append("Mobile input controller did not restore the side panel after blur.")

	holder.queue_free()
	if failures.is_empty():
		print("mobile input controller smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
