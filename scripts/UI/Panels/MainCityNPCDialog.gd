class_name MainCityNPCDialog
extends PanelContainer

signal primary_action(action_id: String)
signal close_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MIN_BUTTON_SIZE := Vector2(44, 44)
const PORTRAIT_MIN_SIZE := Vector2(56, 64)

var _record: Dictionary = {}
var _primary_action_id := ""

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var portrait_frame: PanelContainer = %PortraitFrame
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var role_label: Label = %RoleLabel
@onready var duty_label: Label = %DutyLabel
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
	_refresh_role_text()
	_refresh_portrait()
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

func _refresh_role_text() -> void:
	var role_text := _localized_optional("role_key")
	role_label.visible = not role_text.is_empty()
	if role_label.visible:
		role_label.text = App.format_key("npc.dialog.role_format", {"role": role_text})

	var duty_text := _localized_optional("duty_key")
	duty_label.visible = not duty_text.is_empty()
	if duty_label.visible:
		duty_label.text = duty_text

func _refresh_portrait() -> void:
	portrait_texture.texture = null
	var texture := _npc_visual_texture()
	portrait_frame.visible = texture != null
	if texture != null:
		portrait_texture.texture = texture

func _localized_optional(field_name: String) -> String:
	var key := str(_record.get(field_name, ""))
	if key.is_empty():
		return ""
	return App.t_key(key)

func _npc_visual_texture() -> Texture2D:
	var visual_id := str(_record.get("npc_visual_id", ""))
	if visual_id.is_empty():
		return _load_texture(str(_record.get("sprite_path", "")))

	var data: Dictionary = ConfigLoader.load_config("npc_professions")
	for role in data.get("roles", []):
		if typeof(role) != TYPE_DICTIONARY:
			continue
		var role_record := role as Dictionary
		if str(role_record.get("id", "")) == visual_id:
			return _load_texture(str(role_record.get("frame_path", "")))
	return _load_texture(str(_record.get("sprite_path", "")))

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_panel_frame(portrait_frame)
	WorldHUDAssetsScript.configure_button_frame(primary_button)
	WorldHUDAssetsScript.configure_button_frame(close_button)
	close_button.custom_minimum_size = MIN_BUTTON_SIZE
	close_button.expand_icon = true
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	portrait_frame.custom_minimum_size = PORTRAIT_MIN_SIZE
	portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

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
