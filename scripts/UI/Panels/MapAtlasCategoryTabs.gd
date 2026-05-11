class_name MapAtlasCategoryTabs
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const ALL_CATEGORY := "all"
const ACTIVE_COLOR := Color(1.0, 0.92, 0.68, 1.0)
const IDLE_COLOR := Color.WHITE

var _buttons: Dictionary = {}

func render(parent: VBoxContainer, compact: bool, categories: Array[String], select_callback: Callable) -> void:
	_buttons.clear()
	var tabs := HFlowContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("h_separation", 4 if compact else 6)
	tabs.add_theme_constant_override("v_separation", 4)
	parent.add_child(tabs)
	_add_button(tabs, ALL_CATEGORY, App.t_key("world.panel.map.category_all"), compact, select_callback)
	for category in categories:
		_add_button(tabs, category, _tab_label(category), compact, select_callback)
	_set_active(ALL_CATEGORY)

func _add_button(parent: Control, category: String, text: String, compact: bool, select_callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(76, 24) if compact else Vector2(92, 28)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(func() -> void:
		_set_active(category)
		if select_callback.is_valid():
			select_callback.call(category)
	)
	parent.add_child(button)
	_buttons[category] = button

func _set_active(category: String) -> void:
	for key in _buttons.keys():
		var button := _buttons[key] as Button
		if button == null:
			continue
		var active := str(key) == category
		button.button_pressed = active
		button.modulate = ACTIVE_COLOR if active else IDLE_COLOR

func _tab_label(category: String) -> String:
	return App.t_key("world.panel.map.category_tab.%s" % category)
