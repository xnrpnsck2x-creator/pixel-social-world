class_name WorldHUDAssets
extends RefCounted

const PANEL_MARGINS := Vector4(32, 22, 32, 22)
const HUD_BAR_MARGINS := Vector4(24, 16, 24, 16)
const HUD_STRIP_MARGINS := Vector4(34, 18, 34, 18)
const HUD_BADGE_MARGINS := Vector4(14, 9, 14, 9)
const COMPACT_PANEL_MARGINS := Vector4(20, 15, 20, 15)
const BUTTON_MARGINS := Vector4(20, 15, 20, 15)
const INPUT_MARGINS := Vector4(20, 15, 20, 15)
const FIRST_SESSION_BASE_STYLE_META := "_psw_first_session_base_style"
const TOUCH_TOOLTIP_MAX_SIZE := Vector2(1100, 620)

static func configure_action_button(button: Button, asset_id: String, minimum_size: Vector2) -> void:
	button.custom_minimum_size = minimum_size
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_NONE
	configure_button_frame(button)
	var texture := load_ui_texture(asset_id)
	if texture != null:
		button.icon = texture

static func set_action_tooltip(button: Button, key: String) -> void:
	button.text = ""
	button.tooltip_text = "" if _should_hide_action_tooltip() else _t(key)

static func should_hide_action_tooltip_for(os_name: String, touchscreen: bool, viewport_size: Vector2) -> bool:
	if os_name in ["Android", "iOS"]:
		return true
	if os_name == "Web" and touchscreen and viewport_size.x <= TOUCH_TOOLTIP_MAX_SIZE.x and viewport_size.y <= TOUCH_TOOLTIP_MAX_SIZE.y:
		return true
	return touchscreen and viewport_size.x <= TOUCH_TOOLTIP_MAX_SIZE.x and viewport_size.y <= TOUCH_TOOLTIP_MAX_SIZE.y

static func configure_panel_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.pixel", PANEL_MARGINS)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)

static func configure_stretched_panel_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.pixel", PANEL_MARGINS, false)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)

static func configure_light_panel_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.hud_bar.pixel", HUD_BAR_MARGINS)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_stretched_panel_frame(panel)

static func configure_hud_bar_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset(
		"ui.panel.hud_strip.pixel",
		HUD_STRIP_MARGINS,
		true,
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_light_panel_frame(panel)

static func configure_hud_shell_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset(
		"ui.panel.hud_strip.pixel",
		HUD_STRIP_MARGINS,
		true,
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	)
	if style != null:
		style.draw_center = false
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_light_panel_frame(panel)
	_configure_top_status_badges(panel)

static func configure_hud_strip_frame(panel: PanelContainer) -> void:
	configure_hud_bar_frame(panel)

static func configure_compact_panel_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.compact.pixel", COMPACT_PANEL_MARGINS)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_panel_frame(panel)

static func configure_hud_status_badge_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.compact.pixel", HUD_BADGE_MARGINS)
	if style != null:
		style.expand_margin_left = 1
		style.expand_margin_top = 1
		style.expand_margin_right = 1
		style.expand_margin_bottom = 1
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_compact_panel_frame(panel)

static func configure_hud_title_badge_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset(
		"ui.panel.hud_bar.pixel",
		HUD_BAR_MARGINS,
		true,
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	else:
		configure_hud_status_badge_frame(panel)

static func configure_first_session_guide_frame(panel: PanelContainer, mobile_chip: bool) -> void:
	var current_style := panel.get_theme_stylebox("panel")
	if not panel.has_meta(FIRST_SESSION_BASE_STYLE_META) and current_style != null:
		panel.set_meta(FIRST_SESSION_BASE_STYLE_META, current_style)
	if not mobile_chip:
		var base_style := panel.get_meta(FIRST_SESSION_BASE_STYLE_META, null) as StyleBox
		if base_style != null:
			panel.add_theme_stylebox_override("panel", base_style)
		return
	var source_style := panel.get_meta(FIRST_SESSION_BASE_STYLE_META, current_style) as StyleBox
	if source_style == null:
		return
	var chip_style := source_style.duplicate() as StyleBox
	if chip_style is StyleBoxTexture:
		var texture_style := chip_style as StyleBoxTexture
		texture_style.texture_margin_left = minf(texture_style.texture_margin_left, 10.0)
		texture_style.texture_margin_top = minf(texture_style.texture_margin_top, 6.0)
		texture_style.texture_margin_right = minf(texture_style.texture_margin_right, 10.0)
		texture_style.texture_margin_bottom = minf(texture_style.texture_margin_bottom, 6.0)
		texture_style.expand_margin_left = minf(texture_style.expand_margin_left, 1.0)
		texture_style.expand_margin_top = minf(texture_style.expand_margin_top, 1.0)
		texture_style.expand_margin_right = minf(texture_style.expand_margin_right, 1.0)
		texture_style.expand_margin_bottom = minf(texture_style.expand_margin_bottom, 1.0)
	panel.add_theme_stylebox_override("panel", chip_style)

static func browser_window_size() -> Vector2:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return Vector2.ZERO
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if bridge == null or not bridge.has_method("eval"):
		return Vector2.ZERO
	var width_value: Variant = bridge.call("eval", "window.innerWidth", true)
	var height_value: Variant = bridge.call("eval", "window.innerHeight", true)
	if not _is_number(width_value) or not _is_number(height_value):
		return Vector2.ZERO
	return Vector2(float(width_value), float(height_value))

static func mark_debug_control_rect(key: String, control: Control) -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if bridge == null or not bridge.has_method("eval"):
		return
	var global_key := "globalThis.__psw_debug_%s_rect" % key
	if control == null or not control.visible:
		bridge.call("eval", "%s = null" % global_key, true)
		return
	var rect := control.get_global_rect()
	var anchored_size := Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	if control.anchor_left == 0.0 and control.anchor_top == 0.0 and anchored_size.x > 0.0 and anchored_size.y > 0.0:
		rect = Rect2(Vector2(control.offset_left, control.offset_top), anchored_size)
	bridge.call("eval", "%s = %s" % [global_key, JSON.stringify({
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y
	})], true)

static func configure_button_frame(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := _style_from_asset("ui.button.pixel", BUTTON_MARGINS)
		if style != null:
			button.add_theme_stylebox_override(state, style)

static func configure_line_edit_frame(line_edit: LineEdit) -> void:
	for state in ["normal", "focus", "read_only"]:
		var style := _style_from_asset("ui.input.pixel", INPUT_MARGINS)
		if style != null:
			line_edit.add_theme_stylebox_override(state, style)

static func configure_item_list_frame(item_list: ItemList) -> void:
	for state in ["panel", "focus"]:
		var style := _style_from_asset("ui.panel.compact.pixel", COMPACT_PANEL_MARGINS)
		if style != null:
			item_list.add_theme_stylebox_override(state, style)

static func create_panel(preset: Control.LayoutPreset, offsets: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	configure_hud_strip_frame(panel)
	return panel

static func add_margin_child(parent: Control, child: Control, margins: Vector4) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(margins.x))
	margin.add_theme_constant_override("margin_top", int(margins.y))
	margin.add_theme_constant_override("margin_right", int(margins.z))
	margin.add_theme_constant_override("margin_bottom", int(margins.w))
	parent.add_child(margin)
	margin.add_child(child)
	return margin

static func load_ui_texture(asset_id: String) -> Texture2D:
	var config: Dictionary = _load_config("ui_assets")
	for asset in config.get("assets", []):
		if typeof(asset) != TYPE_DICTIONARY or str(asset.get("id", "")) != asset_id:
			continue

		var path := str(asset.get("path", ""))
		var resource := ResourceLoader.load(path)
		if resource is Texture2D:
			return resource as Texture2D
		if resource == null:
			push_warning("Unable to load UI asset: %s" % asset_id)
		else:
			push_warning("UI asset is not a texture: %s" % asset_id)
		return null

	return null

static func _load_config(config_id: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("ConfigLoader"):
		return tree.root.get_node("ConfigLoader").call("load_config", config_id) as Dictionary
	return {}

static func _t(key: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.has_node("App"):
		return str(tree.root.get_node("App").call("t_key", key))
	return key

static func _should_hide_action_tooltip() -> bool:
	var viewport_size := browser_window_size()
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(DisplayServer.window_get_size())
	return should_hide_action_tooltip_for(OS.get_name(), DisplayServer.is_touchscreen_available(), viewport_size)

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _configure_top_status_badges(panel: PanelContainer) -> void:
	var top_row := panel.get_node_or_null("TopMargin/TopRow")
	if top_row == null:
		return
	for badge_name in ["TitleBadge", "PlayerBadge", "CoinBadge", "PresenceBadge"]:
		var badge := top_row.get_node_or_null(badge_name) as PanelContainer
		if badge != null:
			if badge_name == "TitleBadge":
				configure_hud_title_badge_frame(badge)
			else:
				configure_hud_status_badge_frame(badge)

static func _style_from_asset(
	asset_id: String,
	margins: Vector4,
	use_tile := true,
	tile_mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
) -> StyleBoxTexture:
	var texture := load_ui_texture(asset_id)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	if use_tile:
		style.axis_stretch_horizontal = tile_mode
		style.axis_stretch_vertical = tile_mode
	else:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.expand_margin_left = 2
	style.expand_margin_top = 2
	style.expand_margin_right = 2
	style.expand_margin_bottom = 2
	return style
