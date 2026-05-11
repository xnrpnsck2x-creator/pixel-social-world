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
	input.position = Vector2(0.0, 260.0)
	var controller = MobileInputController.new()
	controller.viewport_size_override = Vector2(844, 390)
	controller.bind(bottom_bar, [input], [side_panel])
	await process_frame

	controller.call("_on_focus_entered", input)
	await process_frame
	if bottom_bar.offset_top >= -104.0:
		failures.append("Focused mobile chat input did not raise the bottom bar.")
	if side_panel.offset_top >= 68.0:
		failures.append("Focused mobile side-panel input did not raise its panel.")
	if side_panel.offset_top > 36.0:
		failures.append("Focused mobile side-panel input stayed too close to the keyboard.")

	controller.call("_on_focus_exited")
	await process_frame
	if not is_equal_approx(bottom_bar.offset_top, -104.0):
		failures.append("Mobile input controller did not restore the bottom bar after blur.")
	if not is_equal_approx(side_panel.offset_top, 68.0):
		failures.append("Mobile input controller did not restore the side panel after blur.")

	controller.viewport_size_override = Vector2(2400, 1080)
	controller.force_mobile_keyboard_guard = true
	controller.call("_on_focus_entered", input)
	await process_frame
	if bottom_bar.offset_top > -560.0:
		failures.append("High-DPI landscape keyboard guard did not lift the bottom bar above Gboard height.")
	if bottom_bar.offset_top < -740.0:
		failures.append("High-DPI landscape keyboard guard moved the bottom bar too far off-screen.")
	controller.set("_focus_started_msec", Time.get_ticks_msec() - 1600)
	controller.call("_refresh_inset")
	await process_frame
	if not is_equal_approx(bottom_bar.offset_top, -104.0):
		failures.append("High-DPI keyboard fallback did not release after the grace window.")
	controller.web_visual_viewport_inset_override = 500.0
	controller.call("_refresh_inset")
	await process_frame
	if bottom_bar.offset_top > -560.0:
		failures.append("Web visualViewport keyboard inset did not keep the bottom bar visible.")
	controller.web_visual_viewport_inset_override = -1.0
	controller.call("_on_focus_exited")
	await process_frame

	holder.queue_free()
	if failures.is_empty():
		print("mobile input controller smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
