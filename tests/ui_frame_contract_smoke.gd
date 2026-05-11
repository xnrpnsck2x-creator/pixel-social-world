extends SceneTree

const WorldHUDAssets := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const TILE_FIT := StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
const TILE := StyleBoxTexture.AXIS_STRETCH_MODE_TILE

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_assert_panel_style("main panel", Callable(WorldHUDAssets, "configure_panel_frame"), "ui_panel_frame_v1_alpha.png", WorldHUDAssets.PANEL_MARGINS, failures)
	_assert_panel_style("light HUD panel", Callable(WorldHUDAssets, "configure_light_panel_frame"), "ui_hud_bar_frame_v1_alpha.png", WorldHUDAssets.HUD_BAR_MARGINS, failures)
	_assert_panel_style("HUD strip", Callable(WorldHUDAssets, "configure_hud_bar_frame"), "ui_hud_strip_frame_v2_alpha.png", WorldHUDAssets.HUD_STRIP_MARGINS, failures, TILE)
	_assert_panel_style("HUD shell", Callable(WorldHUDAssets, "configure_hud_shell_frame"), "ui_hud_strip_frame_v2_alpha.png", WorldHUDAssets.HUD_STRIP_MARGINS, failures, TILE, false)
	_assert_panel_style("HUD title badge", Callable(WorldHUDAssets, "configure_hud_title_badge_frame"), "ui_hud_bar_frame_v1_alpha.png", WorldHUDAssets.HUD_BAR_MARGINS, failures, TILE)
	_assert_panel_style("HUD status badge", Callable(WorldHUDAssets, "configure_hud_status_badge_frame"), "ui_controls_v1_compact_panel.png", WorldHUDAssets.HUD_BADGE_MARGINS, failures)
	_assert_panel_style("compact panel", Callable(WorldHUDAssets, "configure_compact_panel_frame"), "ui_controls_v1_compact_panel.png", WorldHUDAssets.COMPACT_PANEL_MARGINS, failures)
	_assert_button_style(failures)
	_assert_line_edit_style(failures)
	_assert_item_list_style(failures)
	if failures.is_empty():
		print("ui frame contract smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_panel_style(
	label: String,
	configure: Callable,
	expected_file: String,
	margins: Vector4,
	failures: Array[String],
	expected_axis: int = TILE_FIT,
	expected_draw_center := true
) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	configure.call(panel)
	_assert_texture_style(label, panel.get_theme_stylebox("panel"), expected_file, margins, failures, expected_axis, expected_draw_center)
	panel.queue_free()

func _assert_button_style(failures: Array[String]) -> void:
	var button := Button.new()
	root.add_child(button)
	WorldHUDAssets.configure_button_frame(button)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_assert_texture_style("button %s" % state, button.get_theme_stylebox(state), "ui_controls_v1_button.png", WorldHUDAssets.BUTTON_MARGINS, failures)
	button.queue_free()

func _assert_line_edit_style(failures: Array[String]) -> void:
	var line_edit := LineEdit.new()
	root.add_child(line_edit)
	WorldHUDAssets.configure_line_edit_frame(line_edit)
	for state in ["normal", "focus", "read_only"]:
		_assert_texture_style("line edit %s" % state, line_edit.get_theme_stylebox(state), "ui_controls_v1_input.png", WorldHUDAssets.INPUT_MARGINS, failures)
	line_edit.queue_free()

func _assert_item_list_style(failures: Array[String]) -> void:
	var item_list := ItemList.new()
	root.add_child(item_list)
	WorldHUDAssets.configure_item_list_frame(item_list)
	for state in ["panel", "focus"]:
		_assert_texture_style("item list %s" % state, item_list.get_theme_stylebox(state), "ui_controls_v1_compact_panel.png", WorldHUDAssets.COMPACT_PANEL_MARGINS, failures)
	item_list.queue_free()

func _assert_texture_style(
	label: String,
	style: StyleBox,
	expected_file: String,
	margins: Vector4,
	failures: Array[String],
	expected_axis: int = TILE_FIT,
	expected_draw_center := true
) -> void:
	if not style is StyleBoxTexture:
		failures.append("%s did not receive a StyleBoxTexture." % label)
		return
	var texture_style := style as StyleBoxTexture
	if texture_style.texture == null:
		failures.append("%s did not load its Image 2 texture." % label)
	elif not texture_style.texture.resource_path.ends_with(expected_file):
		failures.append("%s loaded %s, expected %s." % [label, texture_style.texture.resource_path, expected_file])
	if texture_style.axis_stretch_horizontal != expected_axis or texture_style.axis_stretch_vertical != expected_axis:
		failures.append("%s must use the expected 9-slice tile mode, not stretched mode." % label)
	if texture_style.draw_center != expected_draw_center:
		failures.append("%s center draw setting drifted from the UI contract." % label)
	if not _margins_match(texture_style, margins):
		failures.append("%s 9-slice margins drifted from the UI contract." % label)

func _margins_match(style: StyleBoxTexture, margins: Vector4) -> bool:
	return is_equal_approx(style.texture_margin_left, margins.x) \
		and is_equal_approx(style.texture_margin_top, margins.y) \
		and is_equal_approx(style.texture_margin_right, margins.z) \
		and is_equal_approx(style.texture_margin_bottom, margins.w)
