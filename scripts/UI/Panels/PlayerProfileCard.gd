class_name PlayerProfileCard
extends PanelContainer

signal close_requested
signal private_chat_requested(peer_id: String)
signal home_visit_requested(owner_id: String)
signal emote_requested(emote_id: String)
signal report_requested(profile: Dictionary)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var _profile := {}
var _compact := false

@onready var name_label: Label = %NameLabel
@onready var id_label: Label = %IdLabel
@onready var close_button: Button = %CloseButton
@onready var private_button: Button = %PrivateButton
@onready var visit_button: Button = %VisitButton
@onready var emote_button: Button = %EmoteButton
@onready var report_button: Button = %ReportButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: close_requested.emit())
	private_button.pressed.connect(_request_private)
	visit_button.pressed.connect(_request_visit)
	emote_button.pressed.connect(func() -> void: emote_requested.emit("emote.laugh"))
	report_button.pressed.connect(_request_report)
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
	for button in [private_button, visit_button, emote_button, report_button]:
		button.custom_minimum_size = Vector2(0, 30) if _compact else Vector2(0, 36)

func _refresh_text() -> void:
	var player_id := str(_profile.get("player_id", ""))
	var display_name := str(_profile.get("display_name", player_id))
	var is_self := player_id == SaveSystem.get_player_id()
	name_label.text = display_name if not display_name.is_empty() else App.t_key("profile.unknown")
	id_label.text = App.format_key("profile.id_format", {"id": player_id})
	private_button.text = App.t_key("profile.private")
	visit_button.text = App.t_key("profile.visit_home")
	emote_button.text = App.t_key("profile.emote")
	report_button.text = App.t_key("profile.report")
	close_button.text = ""
	close_button.tooltip_text = App.t_key("ui.action.close")
	private_button.disabled = is_self or player_id.is_empty()
	visit_button.disabled = player_id.is_empty()
	report_button.disabled = is_self or player_id.is_empty()
	report_button.tooltip_text = App.t_key("profile.report_tooltip")

func set_report_busy(enabled: bool) -> void:
	report_button.disabled = enabled
	report_button.tooltip_text = App.t_key("profile.report_sending" if enabled else "profile.report_tooltip")

func mark_report_sent(success: bool) -> void:
	report_button.disabled = success
	report_button.tooltip_text = App.t_key("profile.report_sent" if success else "profile.report_failed")

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
	for button in [close_button, private_button, visit_button, emote_button, report_button]:
		WorldHUDAssetsScript.configure_button_frame(button)
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	close_button.custom_minimum_size = Vector2(36, 36)
	close_button.expand_icon = true
