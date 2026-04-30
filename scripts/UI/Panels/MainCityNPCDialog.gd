class_name MainCityNPCDialog
extends PanelContainer

signal primary_action(action_id: String)
signal close_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MIN_BUTTON_SIZE := Vector2(44, 44)

var _record: Dictionary = {}
var _primary_action_id := ""

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var body_label: Label = %BodyLabel
@onready var primary_button: Button = %PrimaryButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)
	primary_button.pressed.connect(_emit_primary_action)
	App.locale_changed.connect(_on_locale_changed)
	_apply_image2_style()
	_refresh_text()

func show_dialog(record: Dictionary) -> void:
	_record = record.duplicate(true)
	_primary_action_id = str(_record.get("primary_action_id", _record.get("action_id", "")))
	visible = true
	_refresh_text()

func hide_dialog() -> void:
	visible = false

func _refresh_text() -> void:
	close_button.text = ""
	close_button.tooltip_text = App.t_key("ui.action.close")
	title_label.text = _localized_text("name_key", "world.title")
	body_label.text = _localized_text("dialogue_key", "")
	primary_button.text = _localized_text("primary_action_key", "ui.action.confirm")
	primary_button.tooltip_text = primary_button.text
	primary_button.disabled = _primary_action_id.is_empty()
	_apply_primary_icon()

func _localized_text(field_name: String, fallback_key: String) -> String:
	var key := str(_record.get(field_name, ""))
	if not key.is_empty():
		return App.t_key(key)
	return App.t_key(fallback_key) if not fallback_key.is_empty() else ""

func _apply_primary_icon() -> void:
	primary_button.icon = null
	var icon_id := str(_record.get("primary_icon_id", ""))
	if icon_id.is_empty():
		return
	var texture := WorldHUDAssetsScript.load_ui_texture(icon_id)
	if texture != null:
		primary_button.icon = texture
		primary_button.expand_icon = true

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_button_frame(primary_button)
	WorldHUDAssetsScript.configure_button_frame(close_button)
	close_button.custom_minimum_size = MIN_BUTTON_SIZE
	close_button.expand_icon = true
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")

func _emit_primary_action() -> void:
	if _primary_action_id.is_empty():
		return
	hide_dialog()
	primary_action.emit(_primary_action_id)

func _close() -> void:
	hide_dialog()
	close_requested.emit()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
