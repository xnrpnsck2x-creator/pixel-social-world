class_name WorldHUDAssets
extends RefCounted

const PANEL_MARGINS := Vector4(8, 8, 8, 8)
const BUTTON_MARGINS := Vector4(7, 7, 7, 7)

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
	button.tooltip_text = _t(key)

static func configure_panel_frame(panel: PanelContainer) -> void:
	var style := _style_from_asset("ui.panel.pixel", PANEL_MARGINS)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)

static func configure_button_frame(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := _style_from_asset("ui.button.pixel", BUTTON_MARGINS)
		if style != null:
			button.add_theme_stylebox_override(state, style)

static func configure_line_edit_frame(line_edit: LineEdit) -> void:
	for state in ["normal", "focus", "read_only"]:
		var style := _style_from_asset("ui.button.pixel", BUTTON_MARGINS)
		if style != null:
			line_edit.add_theme_stylebox_override(state, style)

static func configure_item_list_frame(item_list: ItemList) -> void:
	for state in ["panel", "focus"]:
		var style := _style_from_asset("ui.button.pixel", BUTTON_MARGINS)
		if style != null:
			item_list.add_theme_stylebox_override(state, style)

static func create_panel(preset: Control.LayoutPreset, offsets: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	configure_panel_frame(panel)
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

static func _style_from_asset(asset_id: String, margins: Vector4) -> StyleBoxTexture:
	var texture := load_ui_texture(asset_id)
	if texture == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	style.expand_margin_left = 2
	style.expand_margin_top = 2
	style.expand_margin_right = 2
	style.expand_margin_bottom = 2
	return style
