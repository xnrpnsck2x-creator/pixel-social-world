extends Node2D
const MainCityRemotePlayersScript := preload("res://scripts/main_city/MainCityRemotePlayers.gd")
const MainCityInteractionControllerScript := preload("res://scripts/main_city/MainCityInteractionController.gd")
const MainCityMapRuntimeScript := preload("res://scripts/main_city/MainCityMapRuntime.gd")
const MainCityMapTravelControllerScript := preload("res://scripts/main_city/MainCityMapTravelController.gd")
const MainCityMapUnlockerScript := preload("res://scripts/main_city/MainCityMapUnlocker.gd")
const MainCityMapNoticeScript := preload("res://scripts/main_city/MainCityMapNotice.gd")
const MainCityTapMoveControllerScript := preload("res://scripts/main_city/MainCityTapMoveController.gd")
const MapActivityServiceScript := preload("res://scripts/Systems/Map/MapActivityService.gd")
const MainCityPresenceAnnouncerScript := preload("res://scripts/main_city/MainCityPresenceAnnouncer.gd")
const MainCityLocalDebugScript := preload("res://scripts/main_city/MainCityLocalDebug.gd")
const MainCityDepthSorterScript := preload("res://scripts/main_city/MainCityDepthSorter.gd")
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
@onready var social_facility_service: Node = %SocialFacilityService
@onready var emote_sync: Node = %EmoteSync
var _remote_player_sync
var _presence_announcer
var _interaction_controller
var _map_runtime
var _map_travel_controller
var _map_unlocker
var _map_notice
var _tap_move_controller: Node
var _map_activity_service
var _depth_sorter: Node
var _map_metadata
var _world_sync: Node
var _move_timer: Timer
var _realtime_client: Node
func _ready() -> void:
	var display_name: String = SaveSystem.get_display_name()
	if display_name.is_empty():
		display_name = App.t_key("login.default_name")
	chat_service.initialize()
	housing_service.initialize()
	minigame_registry.initialize()
	presence_service.initialize(display_name)
	minigame_session_service.initialize(minigame_registry)
	social_facility_service.initialize()
	hud.bind_services(
		chat_service,
		housing_service,
		minigame_registry,
		presence_service,
		minigame_session_service,
		social_facility_service
	)
	hud.set_player_name(display_name)
	hud.emote_requested.connect(_on_emote_requested)
	hud.home_invite_requested.connect(_on_home_invite_requested)
	hud.home_visit_requested.connect(_on_home_visit_requested)
	hud.map_travel_requested.connect(_on_map_travel_requested)
	emote_sync.bind_room(ROOM_ID)
	emote_sync.emote_received.connect(_on_emote_received)
	presence_service.presence_updated.connect(_on_presence_updated)
	player.display_name = display_name
	player.input_enabled = true
	_setup_map_metadata()
	_setup_tap_move()
	_setup_map_activity()
	_remote_player_sync = MainCityRemotePlayersScript.new()
	_remote_player_sync.bind(remote_players, player)
	_remote_player_sync.profile_requested.connect(_on_remote_profile_requested)
	_presence_announcer = MainCityPresenceAnnouncerScript.new()
	_presence_announcer.bind(_remote_player_sync, chat_service)
	_setup_interactions()
	_setup_depth_sorter()
	_setup_realtime(display_name)
	call_deferred("_sync_map_discovery")
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
	_sync_realtime_map_context()
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
	_presence_announcer.apply(members)
	_remote_player_sync.sync_members(members, SaveSystem.get_player_id())
func _setup_interactions() -> void:
	_interaction_controller = MainCityInteractionControllerScript.new()
	_interaction_controller.name = "InteractionController"
	add_child(_interaction_controller)
	_interaction_controller.fishing_requested.connect(_open_fishing)
	_interaction_controller.home_requested.connect(_open_home)
	_interaction_controller.games_requested.connect(_open_games)
	_interaction_controller.shop_requested.connect(_open_shop)
	_interaction_controller.trade_requested.connect(_open_trade)
	_interaction_controller.guild_requested.connect(_open_guild)
	_interaction_controller.workshop_requested.connect(_open_workshop)
	_interaction_controller.mine_requested.connect(_open_mine)
	_interaction_controller.city_requested.connect(_open_city)
	_interaction_controller.map_unlock_requested.connect(_on_map_unlock_requested)
	_interaction_controller.map_activity_requested.connect(_map_activity_service.perform_activity)
	_interaction_controller.bind(self, npc_root, hud, chat_service, _map_metadata)
	if _tap_move_controller != null and not _tap_move_controller.hotspot_requested.is_connected(_interaction_controller.route_touch_hotspot_action):
		_tap_move_controller.hotspot_requested.connect(_interaction_controller.route_touch_hotspot_action)
	_map_travel_controller = MainCityMapTravelControllerScript.new()
	_map_travel_controller.bind(_map_runtime, _interaction_controller, chat_service)
func _setup_map_metadata() -> void:
	_map_runtime = MainCityMapRuntimeScript.new()
	_map_runtime.bind(self, player, hud)
	_map_unlocker = MainCityMapUnlockerScript.new()
	_map_unlocker.bind(_map_runtime)
	_map_notice = MainCityMapNoticeScript.new()
	_map_notice.bind(_map_runtime, chat_service, hud)
	_map_metadata = _map_runtime.load_map()
func _setup_map_activity() -> void:
	_map_activity_service = MapActivityServiceScript.new()
	add_child(_map_activity_service)
	_map_activity_service.bind(chat_service, hud)
	_map_activity_service.activity_state_changed.connect(func(_action_id: String, _state: Dictionary) -> void: _map_runtime.refresh_activity_hotspots(_map_activity_service))
	_sync_map_activity_context()
func _setup_depth_sorter() -> void:
	_depth_sorter = MainCityDepthSorterScript.new()
	add_child(_depth_sorter)
	_depth_sorter.call("bind", player, npc_root, remote_players)
func _sync_map_activity_context() -> void:
	if _map_activity_service != null:
		_map_activity_service.set_context(_map_runtime.current_map_id, _map_metadata)
		_map_runtime.refresh_activity_hotspots(_map_activity_service)

func _sync_realtime_map_context() -> void:
	if _map_runtime == null:
		return
	var current_map_id := str(_map_runtime.get("current_map_id"))
	if _world_sync != null and _world_sync.has_method("set_current_map_id"):
		_world_sync.call("set_current_map_id", current_map_id)
	if _remote_player_sync != null and _remote_player_sync.has_method("set_current_map_id"):
		_remote_player_sync.call("set_current_map_id", current_map_id)
func _setup_tap_move() -> void:
	_tap_move_controller = MainCityTapMoveControllerScript.new()
	add_child(_tap_move_controller)
	_tap_move_controller.call("bind", player)
func _open_fishing() -> void:
	if _map_runtime.current_map_id != "life_fishing_riverbend_v1":
		_switch_world_map("life_fishing_riverbend_v1", "world.map_enter_fishing")
		return
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
	if _map_runtime.current_map_id != "social_housing_district_v1":
		_switch_world_map("social_housing_district_v1", "world.map_enter_home")
		return
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_home_open"))
	_prepare_home_route(SaveSystem.get_player_id(), false)
	SceneRouter.route_to("home_edit")
func _open_games() -> void:
	if _map_runtime.current_map_id != "social_minigame_arcade_hall_v1":
		_switch_world_map("social_minigame_arcade_hall_v1", "world.map_enter_games")
		return
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_games_open"))
	hud.show_room_panel()
func _open_shop() -> void:
	if _map_runtime.current_map_id != "city_port_market_v1":
		_switch_world_map("city_port_market_v1", "world.map_enter_port")
		return
	hud.show_utility_panel("shop")
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_shop_soon"))
func _open_trade() -> void:
	if _map_runtime.current_map_id != "social_trade_market_v1":
		_switch_world_map("social_trade_market_v1", "world.map_enter_trade")
		return
	hud.show_social_facility_panel("trade")
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_trade_open"))
func _open_guild() -> void:
	if _map_runtime.current_map_id != "social_guild_garden_v1":
		_switch_world_map("social_guild_garden_v1", "world.map_enter_guild")
		return
	hud.show_social_facility_panel("guild")
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_guild_open"))
func _open_workshop() -> void:
	if _map_runtime.current_map_id != "city_spring_workshop_v1":
		_switch_world_map("city_spring_workshop_v1", "world.map_enter_workshop")
		return
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_workshop_open"))
func _open_mine() -> void:
	if _map_runtime.current_map_id != "life_crystal_mine_v1":
		_switch_world_map("life_crystal_mine_v1", "world.map_enter_mine")
		return
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key("world.hotspot_mine_open"))
func _open_city() -> void:
	_switch_world_map("city_forest_dawn_v1", "world.map_enter_city", "south_pier")
func _on_map_travel_requested(map_id: String) -> void:
	var next_metadata = _map_travel_controller.request_directory_travel(map_id)
	if next_metadata != null:
		_map_metadata = next_metadata
		_sync_map_activity_context()
		_sync_realtime_map_context()
		_push_current_map_discovery(false)
func _switch_world_map(map_id: String, message_key: String, spawn_id := "default") -> void:
	var first_unlock := not bool(_map_runtime.discovery.is_discovered(map_id))
	var next_metadata = _map_travel_controller.switch_world_map(map_id, message_key, "arrival", spawn_id)
	if next_metadata != null:
		_map_metadata = next_metadata
		_sync_map_activity_context()
		_sync_realtime_map_context()
		_push_current_map_discovery(first_unlock)
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
	MainCityLocalDebugScript.new().apply(self, hud, minigame_session_service)
func _sync_map_discovery() -> void:
	if _map_unlocker == null:
		return
	await _map_unlocker.sync_from_backend()
func _push_current_map_discovery(force_notice: bool = false) -> void:
	if _map_runtime == null or _map_unlocker == null:
		return
	var result: Dictionary = await _map_unlocker.unlock_map(_map_runtime.current_map_id)
	result["unlocked"] = true if force_notice else result.get("unlocked", false)
	_map_notice.show_unlocked(result)
func _on_map_unlock_requested(map_id: String, source: String) -> void:
	if _map_unlocker == null:
		return
	var result: Dictionary = await _map_unlocker.unlock_map(map_id, source)
	_map_notice.show_unlocked(result)
