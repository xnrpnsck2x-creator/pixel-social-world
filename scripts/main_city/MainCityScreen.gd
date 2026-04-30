extends Node2D

const MainCityRemotePlayersScript := preload("res://scripts/main_city/MainCityRemotePlayers.gd")
const MainCityInteractionControllerScript := preload("res://scripts/main_city/MainCityInteractionController.gd")
const WorldStateSyncScript := preload("res://scripts/Network/Sync/WorldStateSync.gd")
const MessageTypesScript := preload("res://scripts/Network/Protocol/MessageTypes.gd")
const ROOM_ID := "world_town_square"
const MOVE_SEND_SECONDS := 0.12

@onready var player: CharacterBody2D = %LocalPlayer
@onready var npc_root: Node2D = %NPCRoot
@onready var remote_players: Node2D = %RemotePlayers
@onready var hud: CanvasLayer = %WorldHUD
@onready var chat_service: Node = %ChatService
@onready var housing_service: Node = %HousingService
@onready var minigame_registry: Node = %MinigameRegistry
@onready var presence_service: Node = %PresenceService
@onready var minigame_session_service: Node = %MinigameSessionService
@onready var emote_sync: Node = %EmoteSync

var _known_member_names: Dictionary = {}
var _remote_player_sync
var _interaction_controller
var _world_sync: Node
var _move_timer: Timer
var _realtime_client: Node
var _presence_seeded := false

func _ready() -> void:
	var display_name: String = SaveSystem.get_display_name()
	if display_name.is_empty():
		display_name = App.t_key("login.default_name")

	chat_service.initialize()
	housing_service.initialize()
	minigame_registry.initialize()
	presence_service.initialize(display_name)
	minigame_session_service.initialize(minigame_registry)
	hud.bind_services(
		chat_service,
		housing_service,
		minigame_registry,
		presence_service,
		minigame_session_service
	)
	hud.set_player_name(display_name)
	hud.emote_requested.connect(_on_emote_requested)
	hud.home_invite_requested.connect(_on_home_invite_requested)
	hud.home_visit_requested.connect(_on_home_visit_requested)
	emote_sync.bind_room(ROOM_ID)
	emote_sync.emote_received.connect(_on_emote_received)
	presence_service.presence_updated.connect(_on_presence_updated)
	player.display_name = display_name
	player.input_enabled = true
	_remote_player_sync = MainCityRemotePlayersScript.new()
	_remote_player_sync.bind(remote_players, player)
	_remote_player_sync.profile_requested.connect(_on_remote_profile_requested)
	_setup_interactions()
	_setup_realtime(display_name)
	call_deferred("_apply_local_web_debug_panel")

func _exit_tree() -> void:
	if _realtime_client != null:
		if _realtime_client.message_received.is_connected(_on_realtime_message):
			_realtime_client.message_received.disconnect(_on_realtime_message)

func _on_emote_requested(emote_id: String) -> void:
	emote_sync.send_emote(SaveSystem.get_player_id(), emote_id)

func _on_emote_received(player_id: String, emote_id: String) -> void:
	if player_id == SaveSystem.get_player_id() and player.has_method("show_emote"):
		player.show_emote(emote_id)
		return
	_remote_player_sync.show_emote(player_id, emote_id)

func _setup_realtime(display_name: String) -> void:
	_world_sync = WorldStateSyncScript.new()
	_world_sync.bind_local_player(player, ROOM_ID)
	add_child(_world_sync)
	if has_node("/root/RealtimeClient"):
		_realtime_client = get_node("/root/RealtimeClient")
		if not _realtime_client.message_received.is_connected(_on_realtime_message):
			_realtime_client.message_received.connect(_on_realtime_message)
	if has_node("/root/RoomLifecycle"):
		get_node("/root/RoomLifecycle").call("enter_main_city", display_name)
	elif _realtime_client != null:
		_realtime_client.connect_city(ROOM_ID, SaveSystem.get_player_id(), display_name)
	_move_timer = Timer.new()
	_move_timer.one_shot = false
	_move_timer.wait_time = MOVE_SEND_SECONDS
	_move_timer.timeout.connect(_send_move_snapshot)
	add_child(_move_timer)
	_move_timer.start()
	chat_service.load_history(ROOM_ID, chat_service.get_default_channel_id())

func _send_move_snapshot() -> void:
	if _world_sync == null or not has_node("/root/RealtimeClient"):
		return
	var realtime := get_node("/root/RealtimeClient")
	if not bool(realtime.get("is_connected")):
		return
	var payload: Dictionary = _world_sync.build_player_move_payload()
	realtime.send_player_move(payload)

func _on_realtime_message(message_type: String, payload: Dictionary) -> void:
	if message_type == MessageTypesScript.PLAYER_MOVE:
		_remote_player_sync.apply_move(payload, SaveSystem.get_player_id())
	elif message_type == MessageTypesScript.EMOTE_EVENT:
		_apply_remote_emote(payload)
	elif message_type == MessageTypesScript.CHAT_MESSAGE:
		chat_service.ingest_remote_message(payload)
	elif message_type == MessageTypesScript.WORLD_SNAPSHOT:
		_remote_player_sync.apply_snapshot(payload, SaveSystem.get_player_id())
	elif message_type == MessageTypesScript.WORLD_LEAVE:
		_remote_player_sync.remove(str(payload.get("player_id", "")))

func _apply_remote_emote(payload: Dictionary) -> void:
	var player_id := str(payload.get("player_id", ""))
	var emote_id := str(payload.get("emote_id", ""))
	if player_id.is_empty() or player_id == SaveSystem.get_player_id() or emote_id.is_empty():
		return
	_on_emote_received(player_id, emote_id)

func _on_presence_updated(members: Array, _is_online: bool, _seconds: int) -> void:
	_apply_presence_announcements(members)
	_remote_player_sync.sync_members(members, SaveSystem.get_player_id())

func _apply_presence_announcements(members: Array) -> void:
	var local_id := SaveSystem.get_player_id()
	var next_member_names := {}
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var player_id := str((member as Dictionary).get("player_id", ""))
		if player_id.is_empty() or player_id == local_id:
			continue
		next_member_names[player_id] = _remote_player_sync.display_name_for(member as Dictionary, player_id)

	if not _presence_seeded:
		_known_member_names = next_member_names
		_presence_seeded = true
		return

	for player_id in next_member_names:
		if not _known_member_names.has(player_id):
			chat_service.add_system_message(App.t_key("chat.system.name"), App.format_key(
				"world.player_joined",
				{"name": str(next_member_names[player_id])}
			))

	for player_id in _known_member_names:
		if not next_member_names.has(player_id):
			chat_service.add_system_message(App.t_key("chat.system.name"), App.format_key(
				"world.player_left",
				{"name": str(_known_member_names[player_id])}
			))

	_known_member_names = next_member_names

func _setup_interactions() -> void:
	_interaction_controller = MainCityInteractionControllerScript.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)
	_interaction_controller.fishing_requested.connect(_open_fishing)
	_interaction_controller.home_requested.connect(_open_home)
	_interaction_controller.games_requested.connect(_open_games)
	_interaction_controller.bind(self, npc_root, hud, chat_service)

func _open_fishing() -> void:
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_fishing_open"))
	if minigame_session_service != null:
		var response: Dictionary = await minigame_session_service.create_session("fishing")
		if bool(response.get("ok", false)):
			minigame_session_service.launch_game("fishing")
		return
	SaveSystem.set_profile_value("pending_minigame_id", "fishing")
	SaveSystem.save_profile()
	SceneRouter.route_to("minigame_fishing")

func _open_home() -> void:
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_home_open"))
	_prepare_home_route(SaveSystem.get_player_id(), false)
	SceneRouter.route_to("home_edit")

func _open_games() -> void:
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_games_open"))
	hud.show_room_panel()

func _on_home_invite_requested() -> void:
	var owner_id := SaveSystem.get_player_id()
	if has_node("/root/OnlineClient") and bool(get_node("/root/OnlineClient").get("is_connected")):
		var response: Dictionary = await get_node("/root/OnlineClient").call("create_housing_invite", owner_id)
		if not bool(response.get("ok", false)):
			chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("error.network"))
			return
	chat_service.send_local_message("house", player.display_name, App.format_key("housing.invite_chat_format", {
		"name": player.display_name,
		"owner": owner_id
	}))
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("housing.invite_sent"))

func _on_home_visit_requested(owner_id: String) -> void:
	var target_owner := owner_id if not owner_id.is_empty() else SaveSystem.get_player_id()
	if has_node("/root/OnlineClient") and bool(get_node("/root/OnlineClient").get("is_connected")):
		var response: Dictionary = await get_node("/root/OnlineClient").call("visit_housing", target_owner)
		if not bool(response.get("ok", false)):
			chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("error.network"))
			return
	_prepare_home_route(target_owner, target_owner != SaveSystem.get_player_id())
	SceneRouter.route_to("home_edit")

func _on_remote_profile_requested(profile: Dictionary) -> void:
	hud.show_player_profile(profile)

func _prepare_home_route(owner_id: String, visit_mode: bool) -> void:
	SaveSystem.set_profile_value("active_home_owner_id", owner_id)
	SaveSystem.set_profile_value("active_home_visit_mode", visit_mode)
	SaveSystem.save_profile()

func _apply_local_web_debug_panel() -> void:
	var panel_id := _local_web_debug_panel()
	match panel_id:
		"messages":
			hud.show_messages_panel("mail")
		"messages_private":
			hud.show_messages_panel("private")
		"inventory", "shop", "mail", "notice", "creator":
			hud.show_utility_panel(panel_id)
		"room":
			hud.show_room_panel()
		"room_invite":
			_show_debug_room_invite()
		"profile":
			_show_debug_profile()

func _show_debug_room_invite() -> void:
	hud.show_room_panel()
	var response: Dictionary = await minigame_session_service.create_session("fishing")
	var session: Dictionary = response.get("data", {}) as Dictionary
	hud.get_node("Root/OnlineRoomPanel").call("_announce_game_invite", "fishing", str(session.get("id", "")))

func _show_debug_profile() -> void:
	hud.show_player_profile({
		"player_id": "peer-h5-profile",
		"display_name": "Peer City"
	})

func _local_web_debug_panel() -> String:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var network: Dictionary = App.app_config.get("network", {}) as Dictionary
	if str(network.get("environment", "")) != "local_dev":
		return ""
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var value: Variant = bridge.call("eval", "new URLSearchParams(window.location.search).get('psw_panel') || ''", true)
	if typeof(value) != TYPE_STRING:
		return ""
	return str(value)
