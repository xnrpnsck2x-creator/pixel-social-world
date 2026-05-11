class_name MainCityMapNotice
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const TOAST_NAME := "MapUnlockToast"

var map_runtime
var chat_service: Node
var hud: Node
var _toast: PanelContainer

func bind(new_map_runtime, new_chat_service: Node, new_hud: Node = null) -> void:
	map_runtime = new_map_runtime
	chat_service = new_chat_service
	hud = new_hud

func show_unlocked(result: Dictionary) -> void:
	if not bool(result.get("unlocked", false)) or chat_service == null or map_runtime == null:
		return
	var map_name := _map_name(str(result.get("map_id", "")))
	chat_service.add_system_message(App.t_key("chat.system.name"), App.format_key("world.map_unlocked_format", {
		"name": map_name
	}))
	_show_toast(map_name)

func _map_name(map_id: String) -> String:
	var record: Dictionary = map_runtime.call("_record_for_map", map_id)
	var names: Dictionary = record.get("name", {}) as Dictionary
	var locale := "zh" if App.current_locale.begins_with("zh") else App.current_locale
	return str(names.get(locale, names.get("en", map_id)))

func _show_toast(map_name: String) -> void:
	var parent := _toast_parent()
	if parent == null:
		return
	if _toast == null or not is_instance_valid(_toast):
		_toast = _build_toast()
		parent.add_child(_toast)
	(_toast.get_node("Margin/Row/TextRows/TitleLabel") as Label).text = App.t_key("world.map_unlocked_toast_title")
	(_toast.get_node("Margin/Row/TextRows/NameLabel") as Label).text = map_name
	_toast.visible = true
	(_toast.get_node("HideTimer") as Timer).start()

func _toast_parent() -> Control:
	if hud == null:
		return null
	return hud.get_node_or_null("Root") as Control

func _build_toast() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = TOAST_NAME
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -286.0
	panel.offset_top = 54.0
	panel.offset_right = -12.0
	panel.offset_bottom = 104.0
	panel.visible = false
	WorldHUDAssetsScript.configure_panel_frame(panel)
	_add_toast_contents(panel)
	_add_hide_timer(panel)
	return panel

func _add_toast_contents(panel: PanelContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	var margin := WorldHUDAssetsScript.add_margin_child(panel, row, Vector4(10, 7, 10, 7))
	margin.name = "Margin"
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(30, 30)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.map")
	row.add_child(icon)
	var text_rows := VBoxContainer.new()
	text_rows.name = "TextRows"
	text_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_rows.add_theme_constant_override("separation", 0)
	row.add_child(text_rows)
	text_rows.add_child(_toast_label("TitleLabel", Color(0.96, 0.78, 0.38, 1.0)))
	text_rows.add_child(_toast_label("NameLabel", Color(1.0, 0.96, 0.86, 1.0)))

func _toast_label(label_name: String, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", color)
	return label

func _add_hide_timer(panel: PanelContainer) -> void:
	var timer := Timer.new()
	timer.name = "HideTimer"
	timer.one_shot = true
	timer.wait_time = 2.2
	timer.timeout.connect(func() -> void:
		if is_instance_valid(panel):
			panel.visible = false
	)
	panel.add_child(timer)
