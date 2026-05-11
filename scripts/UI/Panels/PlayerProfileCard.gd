class_name PlayerProfileCard
extends PanelContainer

signal close_requested
signal private_chat_requested(peer_id: String)
signal home_visit_requested(owner_id: String)
signal emote_requested(emote_id: String)
signal report_requested(profile: Dictionary)
signal follow_requested(profile: Dictionary)
signal block_requested(profile: Dictionary)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PlayerAvatarConfigScript := preload("res://scripts/Entities/Player/PlayerAvatarConfig.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CHARACTER_CONFIG := "player_animations"

var _profile := {}
var _compact := false

@onready var name_label: Label = %NameLabel
@onready var id_label: Label = %IdLabel
@onready var role_label: Label = %RoleLabel
@onready var header_row: HBoxContainer = get_node("Margin/Rows/HeaderRow") as HBoxContainer
@onready var action_grid: GridContainer = get_node("Margin/Rows/ActionGrid") as GridContainer
@onready var avatar_preview: TextureRect = get_node_or_null("%AvatarPreview") as TextureRect
@onready var close_button: Button = %CloseButton
@onready var private_button: Button = %PrivateButton
@onready var visit_button: Button = %VisitButton
@onready var emote_button: Button = %EmoteButton
@onready var report_button: Button = %ReportButton
@onready var follow_button: Button = %FollowButton
@onready var block_button: Button = %BlockButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: close_requested.emit())
	private_button.pressed.connect(_request_private)
	visit_button.pressed.connect(_request_visit)
	emote_button.pressed.connect(func() -> void: emote_requested.emit("emote.laugh"))
	report_button.pressed.connect(_request_report)
	follow_button.pressed.connect(func() -> void: follow_requested.emit(_profile.duplicate(true)))
	block_button.pressed.connect(func() -> void: block_requested.emit(_profile.duplicate(true)))
	_apply_image2_style()
	_refresh_text()

func show_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	visible = true
	_refresh_text()

func hide_card() -> void:
	visible = false

func set_compact_layout(enabled: bool) -> void:
	_compact = enabled
	custom_minimum_size = Vector2(252, 174) if _compact else Vector2(300, 210)
	header_row.add_theme_constant_override("separation", 6 if _compact else 8)
	action_grid.add_theme_constant_override("h_separation", 6 if _compact else 8)
	action_grid.add_theme_constant_override("v_separation", 6 if _compact else 8)
	if avatar_preview != null:
		avatar_preview.custom_minimum_size = Vector2(42, 42) if _compact else Vector2(58, 58)
	close_button.custom_minimum_size = Vector2(28, 28) if _compact else Vector2(36, 36)
	_apply_label_density()
	for button in _action_buttons():
		button.custom_minimum_size = Vector2(0, 30) if _compact else Vector2(0, 36)

func _refresh_text() -> void:
	var player_id := str(_profile.get("player_id", ""))
	var display_name := str(_profile.get("display_name", player_id))
	var is_self := player_id == SaveSystem.get_player_id()
	name_label.text = display_name if not display_name.is_empty() else App.t_key("profile.unknown")
	id_label.text = App.format_key("profile.id_format", {"id": player_id})
	var role_text := _role_text()
	role_label.text = role_text
	role_label.visible = not role_text.is_empty()
	private_button.text = App.t_key("profile.private")
	visit_button.text = App.t_key("profile.visit_home")
	emote_button.text = App.t_key("profile.emote")
	report_button.text = App.t_key("profile.report")
	follow_button.text = App.t_key("profile.follow")
	block_button.text = App.t_key("profile.block")
	close_button.text = ""
	close_button.tooltip_text = App.t_key("ui.action.close")
	private_button.disabled = is_self or player_id.is_empty()
	visit_button.disabled = player_id.is_empty()
	report_button.disabled = is_self or player_id.is_empty()
	follow_button.disabled = is_self or player_id.is_empty()
	block_button.disabled = is_self or player_id.is_empty()
	report_button.tooltip_text = App.t_key("profile.report_tooltip")
	follow_button.tooltip_text = App.t_key("profile.follow_tooltip")
	block_button.tooltip_text = App.t_key("profile.block_tooltip")
	_refresh_avatar_preview()

func set_report_busy(enabled: bool) -> void:
	report_button.disabled = enabled
	report_button.tooltip_text = App.t_key("profile.report_sending" if enabled else "profile.report_tooltip")

func mark_report_sent(success: bool) -> void:
	report_button.disabled = success
	report_button.tooltip_text = App.t_key("profile.report_sent" if success else "profile.report_failed")

func mark_social_action(action: String, success: bool) -> void:
	if action == "follow":
		follow_button.disabled = success
	elif action == "block":
		block_button.disabled = success
		private_button.disabled = success or private_button.disabled

func _request_private() -> void:
	var player_id := str(_profile.get("player_id", ""))
	if not player_id.is_empty():
		private_chat_requested.emit(player_id)

func _request_visit() -> void:
	var player_id := str(_profile.get("player_id", ""))
	if not player_id.is_empty():
		home_visit_requested.emit(player_id)

func _request_report() -> void:
	if not report_button.disabled:
		report_requested.emit(_profile.duplicate(true))

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	PanelTextThemeScript.apply_primary([name_label])
	PanelTextThemeScript.apply_muted([id_label, role_label])
	_apply_label_density()
	for button in [close_button] + _action_buttons():
		WorldHUDAssetsScript.configure_button_frame(button)
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.expand_icon = true

func _action_buttons() -> Array[Button]:
	return [private_button, visit_button, emote_button, report_button, follow_button, block_button]

func _role_text() -> String:
	var config := PlayerAvatarConfigScript.new().avatar_config(str(_profile.get("character_variant_id", "")))
	var key := str(_profile.get("character_name_key", ""))
	if key.is_empty():
		key = str(config.get("name_key", ""))
	var role := App.t_key(key)
	if role.is_empty():
		role = str(_profile.get("character_variant_id", ""))
	if role.is_empty():
		return ""
	var range_text := _range_text(str(_profile.get("class_id", config.get("class_id", ""))))
	if not range_text.is_empty():
		if _compact:
			return App.format_key("profile.role_compact_detail_format", {
				"role": _compact_role_label(config, role),
				"range": range_text
			})
		return App.format_key("profile.role_detail_format", {"role": role, "range": range_text})
	if _compact:
		return App.format_key("profile.role_compact_format", {"role": _compact_role_label(config, role)})
	return App.format_key("profile.role_format", {"role": role})

func _compact_role_label(config: Dictionary, fallback: String) -> String:
	var gender_id := str(config.get("gender_id", _profile.get("gender_id", "")))
	var gender := App.t_key("character.gender.%s" % gender_id) if not gender_id.is_empty() else ""
	return gender if not gender.is_empty() and not gender.begins_with("character.gender.") else fallback

func _range_text(class_id: String) -> String:
	var data: Dictionary = ConfigLoader.load_config(CHARACTER_CONFIG)
	for record in data.get("classes", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var class_record := record as Dictionary
		if str(class_record.get("id", "")) != class_id:
			continue
		var range_id := str(class_record.get("range", ""))
		if not range_id.is_empty():
			return App.t_key("character.range.%s" % range_id)
	return ""

func _refresh_avatar_preview() -> void:
	if avatar_preview == null:
		return
	var config := PlayerAvatarConfigScript.new().avatar_config(str(_profile.get("character_variant_id", "")))
	avatar_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_preview.texture = _avatar_idle_texture(config)
	avatar_preview.visible = avatar_preview.texture != null

func _apply_label_density() -> void:
	name_label.add_theme_font_size_override("font_size", 12 if _compact else 16)
	id_label.add_theme_font_size_override("font_size", 10 if _compact else 14)
	role_label.add_theme_font_size_override("font_size", 10 if _compact else 14)

func _avatar_idle_texture(config: Dictionary) -> Texture2D:
	var animations: Dictionary = config.get("animations", {}) as Dictionary
	var idle: Dictionary = animations.get("idle_down", {}) as Dictionary
	for frame_path in idle.get("frames", []):
		var texture := ResourceLoader.load(str(frame_path))
		if texture is Texture2D:
			return texture as Texture2D
	return null
