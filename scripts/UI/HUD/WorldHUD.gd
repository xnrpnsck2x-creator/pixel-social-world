class_name WorldHUD
extends CanvasLayer

signal emote_requested(emote_id: String)
signal npc_primary_action(action_id: String)
signal home_invite_requested
signal home_visit_requested(owner_id: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const WorldHUDChatControllerScript := preload("res://scripts/UI/HUD/WorldHUDChatController.gd")
const WorldHUDActionsControllerScript := preload("res://scripts/UI/HUD/WorldHUDActionsController.gd")
const WorldHUDEmotePaletteScript := preload("res://scripts/UI/HUD/WorldHUDEmotePalette.gd")
const WorldHUDLayoutControllerScript := preload("res://scripts/UI/HUD/WorldHUDLayoutController.gd")
const WorldHUDMobileInputControllerScript := preload("res://scripts/UI/HUD/WorldHUDMobileInputController.gd")

var chat_service: Node
var housing_service: Node
var minigame_registry: Node
var presence_service: Node
var minigame_session_service: Node
var player_name := ""
var chat_controller
var action_controller
var layout_controller
var mobile_input_controller
var _emote_palette_controller

@onready var title_label: Label = %TitleLabel
@onready var player_label: Label = %PlayerLabel
@onready var coin_label: Label = %CoinLabel
@onready var presence_dot: ColorRect = %PresenceDot
@onready var presence_label: Label = %PresenceLabel
@onready var status_label: Label = %StatusLabel
@onready var chat_log: Label = %ChatLog
@onready var chat_invite_button: Button = %ChatInviteButton
@onready var channel_picker: OptionButton = %ChannelPicker
@onready var chat_input: LineEdit = %ChatInput
@onready var emote_button: Button = %EmoteButton
@onready var send_button: Button = %SendButton
@onready var fishing_button: Button = %FishingButton
@onready var home_button: Button = %HomeButton
@onready var inventory_button: Button = %InventoryButton
@onready var minigames_button: Button = %MinigamesButton
@onready var social_button: Button = %SocialButton
@onready var mail_unread_badge: Label = %MailUnreadBadge
@onready var top_bar: PanelContainer = %TopBar
@onready var bottom_bar: PanelContainer = %BottomBar
@onready var emote_palette: PanelContainer = %EmotePalette
@onready var emote_grid: GridContainer = %EmoteGrid
@onready var npc_dialog: PanelContainer = %MainCityNPCDialog
@onready var online_room_panel: PanelContainer = %OnlineRoomPanel
@onready var utility_panel: PanelContainer = %WorldUtilityPanel
@onready var social_messages_panel: PanelContainer = %SocialMessagesPanel
@onready var player_profile_card: PanelContainer = %PlayerProfileCard

func _ready() -> void:
	App.locale_changed.connect(_on_locale_changed)
	chat_controller = WorldHUDChatControllerScript.new()
	chat_controller.bind_ui(chat_log, chat_invite_button, channel_picker, chat_input, send_button)
	chat_controller.join_invite_requested.connect(_on_chat_join_invite_requested)
	action_controller = WorldHUDActionsControllerScript.new()
	action_controller.bind_ui(
		emote_button,
		fishing_button,
		home_button,
		inventory_button,
		minigames_button,
		npc_dialog,
		online_room_panel,
		utility_panel,
		social_button,
		mail_unread_badge,
		social_messages_panel,
		player_profile_card
	)
	action_controller.emote_button_pressed.connect(_toggle_emote_palette)
	action_controller.room_emote_requested.connect(_on_palette_emote_selected)
	action_controller.npc_primary_action.connect(_on_npc_primary_action)
	action_controller.home_invite_requested.connect(_on_home_invite_requested)
	action_controller.home_visit_requested.connect(_on_home_visit_requested)
	layout_controller = WorldHUDLayoutControllerScript.new()
	layout_controller.bind_ui(
		title_label,
		player_label,
		coin_label,
		presence_label,
		online_room_panel,
		utility_panel,
		social_messages_panel,
		player_profile_card
	)
	layout_controller.compact_changed.connect(func(_compact: bool) -> void:
		_refresh_player_label()
		_refresh_presence_pill()
	)
	mobile_input_controller = WorldHUDMobileInputControllerScript.new()
	mobile_input_controller.bind(bottom_bar, _mobile_text_inputs(), [online_room_panel, social_messages_panel])
	_emote_palette_controller = WorldHUDEmotePaletteScript.new()
	_emote_palette_controller.bind(emote_palette, emote_grid)
	_emote_palette_controller.emote_selected.connect(_on_palette_emote_selected)
	_emote_palette_controller.build()
	_apply_image2_frames()
	_apply_hud_icons()
	_refresh_text()
	get_viewport().size_changed.connect(_layout_overlay_panels)
	call_deferred("_layout_overlay_panels")

func bind_services(
	new_chat_service: Node,
	new_housing_service: Node,
	new_minigame_registry: Node,
	new_presence_service: Node = null,
	new_minigame_session_service: Node = null
) -> void:
	chat_service = new_chat_service
	housing_service = new_housing_service
	minigame_registry = new_minigame_registry
	presence_service = new_presence_service
	minigame_session_service = new_minigame_session_service
	chat_controller.bind_service(chat_service)
	chat_controller.bind_minigame_registry(minigame_registry)
	if presence_service != null:
		presence_service.presence_updated.connect(_on_presence_updated)
	action_controller.bind_services(
		presence_service,
		chat_service,
		minigame_registry,
		minigame_session_service,
		housing_service
	)
	_refresh_text()

func set_player_name(display_name: String) -> void:
	player_name = display_name
	chat_controller.set_player_name(player_name)
	_refresh_player_label()
	_refresh_coin()

func show_room_panel() -> void:
	action_controller.show_room_panel()

func show_utility_panel(panel_id: String) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	action_controller.show_utility_panel(panel_id)

func show_messages_panel(tab_id: String = "mail") -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	action_controller.show_messages_panel(tab_id)

func show_player_profile(profile: Dictionary) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	action_controller.show_player_profile(profile)

func _hide_room_panel() -> void:
	action_controller.hide_room_panel()

func show_npc_dialog(record: Dictionary) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	action_controller.show_npc_dialog(record)

func _hide_npc_dialog() -> void:
	action_controller.hide_npc_dialog()

func _on_npc_primary_action(action_id: String) -> void:
	npc_primary_action.emit(action_id)

func _on_home_invite_requested() -> void:
	home_invite_requested.emit()

func _on_home_visit_requested(owner_id: String) -> void:
	home_visit_requested.emit(owner_id)

func _on_chat_join_invite_requested(action: Dictionary) -> void:
	action_controller.join_chat_invite(action)

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	title_label.text = App.t_key("world.title")
	_refresh_player_label()
	_refresh_coin()
	status_label.text = App.t_key("world.status_ready")
	_refresh_presence_pill()
	chat_controller.refresh_text()
	action_controller.refresh_text()
	_emote_palette_controller.refresh_tooltips()

func _refresh_coin() -> void:
	if coin_label == null:
		return
	coin_label.text = App.format_key("world.coin_format", {
		"coins": SaveSystem.get_coin_balance()
	})

func _refresh_player_label() -> void:
	if player_label == null:
		return
	var display_name: String = player_name
	if layout_controller != null:
		display_name = layout_controller.trim_player_name(player_name)
	var player_format_key := "world.player_format"
	if layout_controller != null and layout_controller.is_compact():
		player_format_key = "world.player_compact_format"
	player_label.text = App.format_key(player_format_key, {"name": display_name})
	player_label.tooltip_text = App.format_key("world.player_format", {"name": player_name})

func _refresh_presence_pill() -> void:
	var online: bool = presence_service != null and presence_service.is_online()
	var stale: bool = presence_service != null and bool(presence_service.call("is_stale"))
	if online and stale:
		presence_dot.color = Color(0.95, 0.72, 0.22, 1.0)
	elif online:
		presence_dot.color = Color(0.24, 0.76, 0.38, 1.0)
	else:
		presence_dot.color = Color(0.54, 0.55, 0.55, 1.0)
	var seconds: int = presence_service.seconds_since_heartbeat() if presence_service != null else -1
	var count: int = presence_service.get_members().size() if presence_service != null else 1
	var state_key := "ui.status.stale" if online and stale else ("ui.status.online" if online else "ui.status.offline")
	var room_id := str(presence_service.call("get_room_id")) if presence_service != null else "local"
	var presence_format_key := "world.presence_format"
	if layout_controller != null and layout_controller.is_compact():
		presence_format_key = "world.presence_compact_format"
	presence_label.text = App.format_key(presence_format_key, {
		"state": App.t_key(state_key),
		"seconds": max(0, seconds),
		"count": count
	})
	var tooltip := App.format_key("world.presence_tooltip_format", {
		"room": room_id,
		"seconds": max(0, seconds),
		"state": App.t_key(state_key)
	})
	presence_dot.tooltip_text = tooltip
	presence_label.tooltip_text = tooltip

func _on_presence_updated(_members: Array[Dictionary], _is_online: bool, _seconds: int) -> void:
	_refresh_presence_pill()

func _apply_hud_icons() -> void:
	action_controller.apply_icons()
	chat_controller.apply_icon()

func _apply_image2_frames() -> void:
	WorldHUDAssetsScript.configure_panel_frame(top_bar)
	WorldHUDAssetsScript.configure_panel_frame(bottom_bar)
	WorldHUDAssetsScript.configure_panel_frame(emote_palette)
	WorldHUDAssetsScript.configure_button_frame(channel_picker)
	WorldHUDAssetsScript.configure_line_edit_frame(chat_input)

func _layout_overlay_panels() -> void:
	var viewport_size := Vector2(DisplayServer.window_get_size())
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport().get_visible_rect().size
	layout_controller.layout_overlay_panels(viewport_size)

func _toggle_emote_palette() -> void:
	_emote_palette_controller.toggle()

func _on_palette_emote_selected(emote_id: String) -> void:
	emote_requested.emit(emote_id)

func _unhandled_input(event: InputEvent) -> void:
	_emote_palette_controller.handle_input(event)

func _mobile_text_inputs() -> Array:
	return [
		chat_input,
		online_room_panel.get_node("%RoomChatInput"),
		social_messages_panel.get_node("%PeerInput"),
		social_messages_panel.get_node("%PrivateInput")
	]
