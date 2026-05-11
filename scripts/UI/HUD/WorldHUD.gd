class_name WorldHUD
extends CanvasLayer
signal emote_requested(emote_id: String)
signal npc_primary_action(action_id: String)
signal home_invite_requested
signal home_visit_requested(owner_id: String)
signal map_travel_requested(map_id: String)
const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const WorldHUDChatControllerScript := preload("res://scripts/UI/HUD/WorldHUDChatController.gd")
const WorldHUDActionsControllerScript := preload("res://scripts/UI/HUD/WorldHUDActionsController.gd")
const WorldHUDEmotePaletteScript := preload("res://scripts/UI/HUD/WorldHUDEmotePalette.gd")
const WorldHUDLayoutControllerScript := preload("res://scripts/UI/HUD/WorldHUDLayoutController.gd")
const WorldHUDMobileInputControllerScript := preload("res://scripts/UI/HUD/WorldHUDMobileInputController.gd")
const WorldHUDStatusPresenterScript := preload("res://scripts/UI/HUD/WorldHUDStatusPresenter.gd")
const WorldHUDFirstSessionGuideScript := preload("res://scripts/UI/HUD/WorldHUDFirstSessionGuide.gd")
const WorldHUDBarDensityControllerScript := preload("res://scripts/UI/HUD/WorldHUDBarDensityController.gd")
var chat_service: Node
var housing_service: Node
var minigame_registry: Node
var presence_service: Node
var minigame_session_service: Node
var player_name := ""
var world_title := ""
var chat_controller
var action_controller
var layout_controller
var mobile_input_controller
var status_presenter
var first_session_guide
var bar_density_controller
var _emote_palette_controller
@onready var title_label: Label = %TitleLabel
@onready var player_label: Label = %PlayerLabel
@onready var coin_label: Label = %CoinLabel
@onready var map_button: Button = %MapButton
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
@onready var social_facility_panel: PanelContainer = %SocialFacilityPanel
@onready var player_profile_card: PanelContainer = %PlayerProfileCard
@onready var first_session_panel: PanelContainer = %FirstSessionGuidePanel
@onready var first_session_title: Label = %FirstSessionGuideTitle
@onready var first_session_body: Label = %FirstSessionGuideBody
@onready var first_session_progress: Label = %FirstSessionGuideProgress
func _ready() -> void:
	App.locale_changed.connect(_on_locale_changed)
	status_presenter = WorldHUDStatusPresenterScript.new()
	status_presenter.bind_ui(title_label, player_label, coin_label, presence_dot, presence_label, status_label)
	chat_controller = WorldHUDChatControllerScript.new()
	chat_controller.bind_ui(chat_log, chat_invite_button, channel_picker, chat_input, send_button)
	chat_controller.join_invite_requested.connect(_on_chat_join_invite_requested)
	action_controller = WorldHUDActionsControllerScript.new()
	action_controller.bind_ui(
		emote_button,
		map_button,
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
	action_controller.map_travel_requested.connect(_on_map_travel_requested)
	action_controller.npc_primary_action.connect(_on_npc_primary_action)
	action_controller.home_invite_requested.connect(_on_home_invite_requested)
	action_controller.home_visit_requested.connect(_on_home_visit_requested)
	action_controller.first_session_event.connect(_on_first_session_guide_event)
	action_controller.overlay_layout_requested.connect(_layout_overlay_panels)
	layout_controller = WorldHUDLayoutControllerScript.new()
	status_presenter.set_layout_controller(layout_controller)
	layout_controller.bind_ui(
		title_label,
		player_label,
		coin_label,
		presence_label,
		online_room_panel,
		utility_panel,
		social_messages_panel,
		social_facility_panel,
		player_profile_card
	)
	layout_controller.compact_changed.connect(func(_compact: bool) -> void:
		status_presenter.refresh_player_label()
		status_presenter.refresh_presence_pill()
		bar_density_controller.refresh()
	)
	bar_density_controller = WorldHUDBarDensityControllerScript.new()
	bar_density_controller.bind(top_bar, bottom_bar, status_label, chat_log, chat_invite_button, channel_picker, layout_controller)
	status_presenter.layout_refresh_requested.connect(bar_density_controller.refresh)
	chat_controller.layout_refresh_requested.connect(bar_density_controller.refresh)
	first_session_guide = WorldHUDFirstSessionGuideScript.new()
	first_session_guide.bind_ui(first_session_panel, first_session_title, first_session_body, first_session_progress)
	first_session_guide.reward_granted.connect(_on_first_session_reward_granted)
	mobile_input_controller = WorldHUDMobileInputControllerScript.new()
	mobile_input_controller.bind(bottom_bar, _mobile_text_inputs(), [online_room_panel, social_messages_panel, social_facility_panel])
	social_facility_panel.text_input_added.connect(func(input: LineEdit) -> void:
		mobile_input_controller.track_input(input)
	)
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
	new_minigame_session_service: Node = null,
	new_social_facility_service: Node = null
) -> void:
	chat_service = new_chat_service
	housing_service = new_housing_service
	minigame_registry = new_minigame_registry
	presence_service = new_presence_service
	minigame_session_service = new_minigame_session_service
	status_presenter.set_presence_service(presence_service)
	chat_controller.bind_service(chat_service)
	first_session_guide.bind_chat_service(chat_service)
	chat_controller.bind_minigame_registry(minigame_registry)
	if presence_service != null:
		presence_service.presence_updated.connect(_on_presence_updated)
	social_facility_panel.call("bind_service", new_social_facility_service)
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
	status_presenter.set_player_name(player_name)
func set_world_title(title: String) -> void:
	world_title = title
	status_presenter.set_world_title(world_title)
func refresh_coin() -> void:
	status_presenter.refresh_coin()
func show_status_message(message: String) -> void:
	status_presenter.show_status_message(message)
func set_first_session_guide_enabled(enabled: bool) -> void:
	if first_session_guide != null:
		first_session_guide.set_enabled(enabled and bool((App.app_config.get("feature_flags", {}) as Dictionary).get("first_session_guide", false)))
func show_room_panel() -> void:
	social_facility_panel.call("hide_panel")
	action_controller.show_room_panel()
	_layout_overlay_panels()
func show_utility_panel(panel_id: String) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	social_facility_panel.call("hide_panel")
	action_controller.show_utility_panel(panel_id)
	_layout_overlay_panels()
func show_social_facility_panel(facility_id: String) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	action_controller.hide_room_panel()
	action_controller.hide_utility_panel()
	action_controller.hide_messages_panel()
	action_controller.hide_profile_card()
	_hide_npc_dialog()
	social_facility_panel.call("show_facility", facility_id)
	_layout_overlay_panels()
	if facility_id == "trade":
		first_session_guide.record_event("trade_opened")
func show_messages_panel(tab_id: String = "mail") -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	social_facility_panel.call("hide_panel")
	action_controller.show_messages_panel(tab_id)
	_layout_overlay_panels()
func show_player_profile(profile: Dictionary) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	social_facility_panel.call("hide_panel")
	action_controller.show_player_profile(profile)
	_layout_overlay_panels()
func show_npc_dialog(record: Dictionary) -> void:
	if _emote_palette_controller != null:
		_emote_palette_controller.hide()
	social_facility_panel.call("hide_panel")
	action_controller.show_npc_dialog(record)
	first_session_guide.record_event("npc_met")
func _hide_npc_dialog() -> void:
	action_controller.hide_npc_dialog()
func _on_npc_primary_action(action_id: String) -> void:
	npc_primary_action.emit(action_id)
func _on_home_invite_requested() -> void:
	home_invite_requested.emit()
func _on_home_visit_requested(owner_id: String) -> void:
	home_visit_requested.emit(owner_id)

func _on_map_travel_requested(map_id: String) -> void:
	map_travel_requested.emit(map_id)

func _on_chat_join_invite_requested(action: Dictionary) -> void:
	action_controller.join_chat_invite(action)

func _on_first_session_guide_event(event_id: String) -> void:
	first_session_guide.record_event(event_id)

func _on_first_session_reward_granted(_coins: int) -> void:
	status_presenter.refresh_coin()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	status_presenter.refresh_text()
	chat_controller.refresh_text()
	action_controller.refresh_text()
	first_session_guide.refresh_text()
	_emote_palette_controller.refresh_tooltips()

func _on_presence_updated(_members: Array[Dictionary], _is_online: bool, _seconds: int) -> void:
	status_presenter.refresh_presence_pill()

func _apply_hud_icons() -> void:
	action_controller.apply_icons()
	chat_controller.apply_icon()

func _apply_image2_frames() -> void:
	WorldHUDAssetsScript.configure_hud_shell_frame(top_bar)
	WorldHUDAssetsScript.configure_hud_shell_frame(bottom_bar)
	WorldHUDAssetsScript.configure_compact_panel_frame(emote_palette)
	WorldHUDAssetsScript.configure_compact_panel_frame(first_session_panel)
	WorldHUDAssetsScript.configure_button_frame(channel_picker)
	WorldHUDAssetsScript.configure_line_edit_frame(chat_input)
func _layout_overlay_panels() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(DisplayServer.window_get_size())
	if _emote_palette_controller != null and (npc_dialog.visible or online_room_panel.visible or utility_panel.visible or social_messages_panel.visible or social_facility_panel.visible or player_profile_card.visible): _emote_palette_controller.hide()
	layout_controller.layout_overlay_panels(viewport_size)
	first_session_guide.layout(viewport_size)
	bar_density_controller.refresh()
func _toggle_emote_palette() -> void:
	if not emote_palette.visible: action_controller.hide_npc_dialog()
	if not emote_palette.visible: action_controller.hide_room_panel()
	if not emote_palette.visible: action_controller.hide_utility_panel()
	if not emote_palette.visible: action_controller.hide_messages_panel()
	if not emote_palette.visible: action_controller.hide_profile_card()
	if not emote_palette.visible: social_facility_panel.call("hide_panel")
	_emote_palette_controller.toggle()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_overlay = %s" % JSON.stringify("emote" if emote_palette.visible else ""), true)
func _on_palette_emote_selected(emote_id: String) -> void:
	emote_requested.emit(emote_id)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _close_top_overlay():
		get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _close_top_overlay():
		get_viewport().set_input_as_handled()
		return
	_emote_palette_controller.handle_input(event)
func _mobile_text_inputs() -> Array:
	return [chat_input, online_room_panel.get_node("%RoomChatInput"), social_messages_panel.get_node("%PeerInput"), social_messages_panel.get_node("%PrivateInput")]
func _close_top_overlay() -> bool:
	if _emote_palette_controller != null and emote_palette.visible: _emote_palette_controller.hide(); return true
	if social_facility_panel.visible: social_facility_panel.call("hide_panel"); _layout_overlay_panels(); return true
	if utility_panel.visible: action_controller.hide_utility_panel(); _layout_overlay_panels(); return true
	if social_messages_panel.visible: action_controller.hide_messages_panel(); _layout_overlay_panels(); return true
	if online_room_panel.visible: action_controller.hide_room_panel(); _layout_overlay_panels(); return true
	if player_profile_card.visible: action_controller.hide_profile_card(); _layout_overlay_panels(); return true
	if npc_dialog.visible: action_controller.hide_npc_dialog(); _layout_overlay_panels(); return true
	return false
