class_name OnlineRoomPanel
extends PanelContainer

signal close_requested
signal home_invite_requested
signal home_visit_requested(owner_id: String)
signal emote_requested(emote_id: String)
signal profile_requested(profile: Dictionary)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const Formatter := preload("res://scripts/UI/Panels/OnlineRoomPanelFormatter.gd")
const Actions := preload("res://scripts/UI/Panels/OnlineRoomPanelActions.gd")
const Members := preload("res://scripts/UI/Panels/OnlineRoomPanelMembers.gd")
const Layout := preload("res://scripts/UI/Panels/OnlineRoomPanelLayout.gd")

var presence_service: Node
var chat_service: Node
var minigame_registry: Node
var session_service: Node
var _actions := Actions.new()
var _members := Members.new()
var _layout := Layout.new()

@onready var title_label: Label = %TitleLabel
@onready var refresh_button: Button = %RefreshButton
@onready var report_button: Button = %ReportButton
@onready var close_button: Button = %CloseButton
@onready var status_dot: ColorRect = %StatusDot
@onready var member_count_label: Label = %MemberCountLabel
@onready var heartbeat_label: Label = %HeartbeatLabel
@onready var quick_emote_row: HBoxContainer = %QuickEmoteRow
@onready var laugh_emote_button: Button = %LaughEmoteButton
@onready var heart_emote_button: Button = %HeartEmoteButton
@onready var exclamation_emote_button: Button = %ExclamationEmoteButton
@onready var members_title_label: Label = %MembersTitleLabel
@onready var members_label: Label = %MembersLabel
@onready var members_list: ItemList = %MembersList
@onready var private_member_button: Button = %PrivateMemberButton
@onready var chat_title_label: Label = %ChatTitleLabel
@onready var chat_preview_label: Label = %ChatPreviewLabel
@onready var panel_invite_button: Button = %PanelInviteButton
@onready var room_chat_row: HBoxContainer = %RoomChatRow
@onready var room_chat_input: LineEdit = %RoomChatInput
@onready var room_send_button: Button = %RoomSendButton
@onready var games_title_label: Label = %GamesTitleLabel
@onready var game_catalog_label: Label = %GameCatalogLabel
@onready var sessions_label: Label = %SessionsLabel
@onready var host_fishing_button: Button = %HostFishingButton
@onready var join_session_button: Button = %JoinSessionButton
@onready var home_title_label: Label = %HomeTitleLabel
@onready var invite_home_button: Button = %InviteHomeButton
@onready var visit_home_button: Button = %VisitHomeButton

func _ready() -> void:
	_bind_layout()
	_apply_image2_style()
	_layout.apply_session_text_limits()
	for label in [members_label, chat_preview_label, game_catalog_label, sessions_label]:
		label.clip_text = true
	refresh_button.pressed.connect(_refresh_now)
	report_button.pressed.connect(_report_latest_chat)
	close_button.pressed.connect(close_requested.emit)
	panel_invite_button.pressed.connect(_join_first_session)
	room_send_button.pressed.connect(_send_room_chat)
	room_chat_input.text_submitted.connect(func(_text: String) -> void: _send_room_chat())
	_actions.bind_buttons(
		laugh_emote_button,
		heart_emote_button,
		exclamation_emote_button,
		host_fishing_button,
		join_session_button,
		invite_home_button,
		visit_home_button
	)
	_actions.emote_requested.connect(func(emote_id: String) -> void: emote_requested.emit(emote_id))
	_actions.home_invite_requested.connect(func() -> void: home_invite_requested.emit())
	_actions.home_visit_requested.connect(func(owner_id: String) -> void: home_visit_requested.emit(owner_id))
	_members.bind(members_label, members_list, private_member_button)
	_members.profile_requested.connect(func(profile: Dictionary) -> void: profile_requested.emit(profile))
	App.locale_changed.connect(_on_locale_changed)
	_refresh_text()

func bind_services(
	new_presence_service: Node,
	new_chat_service: Node,
	new_minigame_registry: Node,
	new_session_service: Node
) -> void:
	presence_service = new_presence_service
	chat_service = new_chat_service
	minigame_registry = new_minigame_registry
	session_service = new_session_service
	_actions.bind_services(presence_service, chat_service, minigame_registry, session_service)
	if presence_service != null:
		presence_service.presence_updated.connect(_on_presence_updated)
	if session_service != null:
		session_service.sessions_updated.connect(_on_sessions_updated)
	if chat_service != null:
		chat_service.message_added.connect(_on_chat_message_added)
	_refresh_all()

func _refresh_now() -> void:
	if presence_service != null:
		presence_service.refresh_now()
	if session_service != null:
		session_service.refresh_sessions()
	_refresh_chat_preview()

func _refresh_all() -> void:
	_refresh_presence()
	_refresh_chat_preview()
	_refresh_game_catalog()
	_refresh_sessions()

func _refresh_text() -> void:
	title_label.text = App.t_key("world.room_panel.title")
	refresh_button.text = App.t_key("ui.action.refresh")
	report_button.text = App.t_key("chat.report.button")
	close_button.text = App.t_key("ui.action.close")
	members_title_label.text = App.t_key("world.room_panel.section_members")
	chat_title_label.text = App.t_key("world.room_panel.section_chat")
	room_chat_input.placeholder_text = App.t_key("world.room_panel.chat_placeholder")
	room_send_button.text = App.t_key("world.send_button")
	panel_invite_button.tooltip_text = App.t_key("world.session_invite_chip_tooltip")
	laugh_emote_button.tooltip_text = App.t_key("emote.name.laugh")
	heart_emote_button.tooltip_text = App.t_key("emote.name.heart")
	exclamation_emote_button.tooltip_text = App.t_key("emote.name.exclamation")
	games_title_label.text = App.t_key("world.room_panel.section_games")
	host_fishing_button.text = App.t_key("world.session_host_fishing")
	join_session_button.text = App.t_key("world.session_join")
	home_title_label.text = App.t_key("world.room_panel.section_home")
	invite_home_button.text = App.t_key("housing.invite_button")
	visit_home_button.text = App.t_key("housing.visit_button")
	_members.refresh_text()
	_layout.apply_text()
	_refresh_all()

func set_compact_layout(enabled: bool) -> void:
	if not _layout.set_compact(enabled):
		return
	_refresh_all()

func _bind_layout() -> void:
	_layout.bind(
		self,
		[members_title_label, chat_title_label, games_title_label, home_title_label],
		chat_preview_label,
		game_catalog_label,
		panel_invite_button,
		room_chat_row,
		quick_emote_row,
		members_label,
		room_chat_input,
		sessions_label,
		[
			refresh_button,
			report_button,
			close_button,
			room_send_button,
			host_fishing_button,
			join_session_button,
			invite_home_button,
			visit_home_button
		]
	)

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_button_frame(refresh_button)
	WorldHUDAssetsScript.configure_button_frame(report_button)
	WorldHUDAssetsScript.configure_button_frame(close_button)
	WorldHUDAssetsScript.configure_line_edit_frame(room_chat_input)
	WorldHUDAssetsScript.configure_item_list_frame(members_list)
	WorldHUDAssetsScript.configure_button_frame(room_send_button)
	WorldHUDAssetsScript.configure_button_frame(private_member_button)
	WorldHUDAssetsScript.configure_button_frame(panel_invite_button)
	WorldHUDAssetsScript.configure_action_button(laugh_emote_button, "emote.laugh", Vector2(40, 40))
	WorldHUDAssetsScript.configure_action_button(heart_emote_button, "emote.heart", Vector2(40, 40))
	WorldHUDAssetsScript.configure_action_button(exclamation_emote_button, "emote.exclamation", Vector2(40, 40))
	WorldHUDAssetsScript.configure_button_frame(host_fishing_button)
	WorldHUDAssetsScript.configure_button_frame(join_session_button)
	WorldHUDAssetsScript.configure_button_frame(invite_home_button)
	WorldHUDAssetsScript.configure_button_frame(visit_home_button)

func _refresh_presence() -> void:
	var online: bool = presence_service != null and presence_service.is_online()
	var stale: bool = online and presence_service.has_method("is_stale") and bool(presence_service.call("is_stale"))
	if online and stale:
		status_dot.color = Color(0.95, 0.72, 0.22, 1.0)
	elif online:
		status_dot.color = Color(0.24, 0.76, 0.38, 1.0)
	else:
		status_dot.color = Color(0.54, 0.55, 0.55, 1.0)
	var members: Array = presence_service.get_members() if presence_service != null else []
	member_count_label.text = App.format_key("world.members_format", {"count": members.size()})
	var seconds: int = presence_service.seconds_since_heartbeat() if presence_service != null else -1
	heartbeat_label.text = Formatter.heartbeat_text(seconds)
	var state_key := "ui.status.stale" if online and stale else ("ui.status.online" if online else "ui.status.offline")
	var tooltip := App.format_key("world.presence_tooltip_format", {
		"room": str(presence_service.call("get_room_id")) if presence_service != null else "local",
		"seconds": max(0, seconds),
		"state": App.t_key(state_key)
	})
	status_dot.tooltip_text = tooltip
	member_count_label.tooltip_text = tooltip
	heartbeat_label.tooltip_text = tooltip
	_members.refresh(members, SaveSystem.get_player_id(), _layout.is_compact())

func _refresh_chat_preview() -> void:
	if chat_service == null:
		chat_preview_label.text = App.t_key("world.chat_empty")
		panel_invite_button.visible = false
		panel_invite_button.disabled = true
		report_button.disabled = true
		room_send_button.disabled = true
		return
	chat_preview_label.text = Formatter.chat_rows(chat_service, 4)
	_refresh_invite_chip()
	report_button.disabled = not bool(chat_service.call("can_report_latest_visible_message"))
	room_send_button.disabled = false

func _refresh_sessions() -> void:
	var sessions: Array = session_service.get_sessions() if session_service != null else []
	sessions_label.text = Formatter.session_rows(session_service, sessions, _layout.session_row_limit(), presence_service)

func _refresh_invite_chip() -> void:
	var text := Formatter.invite_chip_text(chat_service, minigame_registry)
	panel_invite_button.visible = not text.is_empty()
	panel_invite_button.disabled = text.is_empty()
	panel_invite_button.text = text

func _refresh_game_catalog() -> void:
	game_catalog_label.text = Formatter.game_catalog(minigame_registry)

func _send_room_chat() -> void:
	if chat_service == null:
		return
	var body := room_chat_input.text.strip_edges()
	if body.is_empty():
		return
	var channel_id: String = chat_service.get_active_view_channel_id()
	if chat_service.send_local_message(channel_id, SaveSystem.get_display_name(), body):
		room_chat_input.clear()

func _announce_game_invite(game_id: String, session_id: String = "") -> void:
	_actions.announce_game_invite(game_id, session_id)

func _join_first_session() -> void:
	await _actions.join_preferred_session()

func _visit_first_member_home() -> void:
	_actions.visit_first_member_home()

func _report_latest_chat() -> void:
	if chat_service == null:
		return
	report_button.disabled = true
	await chat_service.call("report_latest_visible_message")
	_refresh_chat_preview()

func _on_presence_updated(_members: Array[Dictionary], _is_online: bool, _seconds: int) -> void:
	_refresh_presence()

func _on_sessions_updated(_sessions: Array[Dictionary]) -> void:
	_refresh_sessions()

func _on_chat_message_added(_message: Dictionary) -> void:
	_refresh_chat_preview()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
