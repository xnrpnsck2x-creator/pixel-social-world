class_name WorldHUDEmotePalette
extends RefCounted

signal emote_selected(emote_id: String)

const EmoteCatalogScript := preload("res://scripts/Systems/Emotes/EmoteCatalog.gd")

var _palette: PanelContainer
var _grid: GridContainer
var _emote_buttons: Dictionary = {}
var _shortcut_to_emote: Dictionary = {}

func bind(palette: PanelContainer, grid: GridContainer) -> void:
	_palette = palette
	_grid = grid

func build() -> void:
	_emote_buttons.clear()
	_shortcut_to_emote.clear()
	for child in _grid.get_children():
		child.queue_free()

	for entry in EmoteCatalogScript.get_palette_entries():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_add_button(entry as Dictionary)

func toggle() -> void:
	_palette.visible = not _palette.visible

func hide() -> void:
	_palette.visible = false

func refresh_tooltips() -> void:
	for emote_id in _emote_buttons:
		var record: Dictionary = _emote_buttons[emote_id]
		var button: Button = record.get("button") as Button
		if button != null:
			button.tooltip_text = App.t_key(str(record.get("name_key", "")))

func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode == KEY_ESCAPE and _palette.visible:
		hide()
		return true

	var shortcut := _shortcut_from_key(key_event)
	if shortcut.is_empty() or not _shortcut_to_emote.has(shortcut):
		return false
	_select(str(_shortcut_to_emote[shortcut]))
	return true

func _add_button(entry: Dictionary) -> void:
	var emote_id := str(entry.get("id", ""))
	if emote_id.is_empty():
		return

	var button := Button.new()
	button.custom_minimum_size = Vector2(44, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.icon = EmoteCatalogScript.load_texture(emote_id)
	button.tooltip_text = App.t_key(str(entry.get("name_key", "")))
	button.pressed.connect(_select.bind(emote_id))
	_grid.add_child(button)

	_emote_buttons[emote_id] = {
		"button": button,
		"name_key": str(entry.get("name_key", ""))
	}

	var shortcut := str(entry.get("shortcut", ""))
	if not shortcut.is_empty():
		_shortcut_to_emote[shortcut] = emote_id

func _select(emote_id: String) -> void:
	hide()
	emote_selected.emit(emote_id)

func _shortcut_from_key(event: InputEventKey) -> String:
	if not event.alt_pressed:
		return ""
	match event.keycode:
		KEY_0:
			return "Alt+0"
		KEY_1:
			return "Alt+1"
		KEY_2:
			return "Alt+2"
		KEY_3:
			return "Alt+3"
		KEY_4:
			return "Alt+4"
		KEY_5:
			return "Alt+5"
		KEY_6:
			return "Alt+6"
		KEY_7:
			return "Alt+7"
		KEY_8:
			return "Alt+8"
		KEY_9:
			return "Alt+9"
	return ""
