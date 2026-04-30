extends Node

signal connection_changed(is_connected: bool)
signal request_failed(route: String, message: String)

const OnlineClientEndpointsScript := preload("res://scripts/Network/Client/OnlineClientEndpoints.gd")
const OnlineClientSessionScript := preload("res://scripts/Network/Client/OnlineClientSession.gd")
const OnlineClientAdminScript := preload("res://scripts/Network/Client/OnlineClientAdmin.gd")
const OnlineClientRequestScript := preload("res://scripts/Network/Client/OnlineClientRequest.gd")

var base_url := "http://127.0.0.1:8787"
var online_enabled := true
var offline_fallback_enabled := true
var timeout_seconds := 0.75
var is_connected := false
var access_token := ""
var refresh_token := ""
var player_id := "offline-player"
var _has_manual_config := false
var _endpoints
var _session
var _admin
var _requester

func _ready() -> void:
	_endpoints = OnlineClientEndpointsScript.new(self)
	_session = OnlineClientSessionScript.new(self)
	_requester = OnlineClientRequestScript.new(self)
	_connect_app_config_signal()
	configure()
	_auth().restore_session()

func configure(config: Dictionary = {}) -> void:
	_configure(config, not config.is_empty())

func _configure(config: Dictionary = {}, manual: bool = true) -> void:
	if config.is_empty() and _has_manual_config:
		return
	var source_config := config
	if source_config.is_empty() and has_node("/root/App"):
		source_config = (get_node("/root/App") as Node).get("app_config") as Dictionary
	elif manual:
		_has_manual_config = true

	var network: Dictionary = source_config.get("network", {}) as Dictionary
	base_url = str(network.get("base_url", base_url)).trim_suffix("/")
	online_enabled = bool(network.get("online_enabled", online_enabled))
	offline_fallback_enabled = bool(source_config.get("offline_mode_enabled", true))
	timeout_seconds = float(network.get("http_timeout_seconds", timeout_seconds))

func _connect_app_config_signal() -> void:
	if not has_node("/root/App"):
		return
	var app := get_node("/root/App")
	var callback := Callable(self, "_on_app_config_changed")
	if not app.is_connected("config_changed", callback):
		app.connect("config_changed", callback)

func _on_app_config_changed(config: Dictionary) -> void:
	if _has_manual_config:
		return
	_configure(config, false)

func guest_login(display_name: String) -> Dictionary:
	return await _auth().guest_login(display_name)

func refresh_session() -> Dictionary:
	return await _auth().refresh_session()

func upgrade_guest_account(request: Dictionary) -> Dictionary:
	return await _auth().upgrade_guest_account(request)

func fetch_profile() -> Dictionary:
	return await _auth().fetch_profile()

func fetch_housing_layout(owner_id: String = "") -> Dictionary:
	return await _api().fetch_housing_layout(owner_id)

func place_housing_item(
	owner_id: String,
	item_id: String,
	tile: Vector2i,
	rotation: int = 0
) -> Dictionary:
	return await _api().place_housing_item(owner_id, item_id, tile, rotation)

func apply_housing_style(owner_id: String, category: String, item_id: String) -> Dictionary:
	return await _api().apply_housing_style(owner_id, category, item_id)

func move_housing_item(
	owner_id: String,
	item: Dictionary,
	target_tile: Vector2i,
	target_rotation: int
) -> Dictionary:
	return await _api().move_housing_item(owner_id, item, target_tile, target_rotation)

func remove_housing_item(owner_id: String, item: Dictionary) -> Dictionary:
	return await _api().remove_housing_item(owner_id, item)

func create_housing_invite(owner_id: String = "") -> Dictionary:
	return await _api().create_housing_invite(owner_id)

func visit_housing(owner_id: String) -> Dictionary:
	return await _api().visit_housing(owner_id)

func fetch_coin_ledger(player_id_override: String = "") -> Dictionary:
	return await _api().fetch_coin_ledger(player_id_override)

func send_chat(
	room_id: String,
	channel_id: String,
	sender_name: String,
	body: String,
	extra: Dictionary = {}
) -> Dictionary:
	return await _api().send_chat(room_id, channel_id, sender_name, body, extra)

func fetch_chat_history(room_id: String, channel_id: String, limit: int = 50) -> Dictionary:
	return await _api().fetch_chat_history(room_id, channel_id, limit)

func report_chat_message(message: Dictionary, reason: String = "player_report") -> Dictionary:
	return await _api().report_chat_message(message, reason)

func report_player_profile(profile: Dictionary, reason: String = "profile_report") -> Dictionary:
	return await _api().report_player_profile(profile, reason)

func send_private_message(recipient_id: String, body: String) -> Dictionary:
	return await _api().send_private_message(recipient_id, body)

func fetch_private_conversation(peer_id: String, limit: int = 50) -> Dictionary:
	return await _api().fetch_private_conversation(peer_id, limit)

func fetch_private_conversations(limit: int = 50) -> Dictionary:
	return await _api().fetch_private_conversations(limit)

func mark_private_read(peer_id: String) -> Dictionary:
	return await _api().mark_private_read(peer_id)

func report_private_message(message: Dictionary, reason: String = "player_report") -> Dictionary:
	return await _api().report_private_message(message, reason)

func send_mail(recipient_id: String, subject: String, body: String) -> Dictionary:
	return await _api().send_mail(recipient_id, subject, body)

func fetch_mailbox(limit: int = 50) -> Dictionary:
	return await _api().fetch_mailbox(limit)

func mark_mail_read(mail_id: String) -> Dictionary:
	return await _api().mark_mail_read(mail_id)

func send_presence(room_id: String, display_name: String) -> Dictionary:
	return await _api().send_presence(room_id, display_name)

func fetch_room_members(room_id: String) -> Dictionary:
	return await _api().fetch_room_members(room_id)

func create_minigame_session(game_id: String, room_id: String, max_players: int = 0) -> Dictionary:
	return await _api().create_minigame_session(game_id, room_id, max_players)

func list_minigame_sessions(room_id: String) -> Dictionary:
	return await _api().list_minigame_sessions(room_id)

func join_minigame_session(session_id: String) -> Dictionary:
	return await _api().join_minigame_session(session_id)

func leave_minigame_session(session_id: String) -> Dictionary:
	return await _api().leave_minigame_session(session_id)

func end_minigame_session(session_id: String) -> Dictionary:
	return await _api().end_minigame_session(session_id)

func claim_fishing_catch(session_id: String, request_id: String = "") -> Dictionary:
	return await _api().claim_fishing_catch(session_id, request_id)

func submit_creator_draft(request: Dictionary) -> Dictionary:
	return await _api().submit_creator_draft(request)

func submit_creator_package(request: Dictionary) -> Dictionary:
	return await _api().submit_creator_package(request)

func fetch_creator_submission_status(game_id: String) -> Dictionary:
	return await _api().fetch_creator_submission_status(game_id)

func fetch_creator_submission_history(game_id: String) -> Dictionary:
	return await _api().fetch_creator_submission_history(game_id)

func fetch_utility_panels() -> Dictionary:
	return await _api().fetch_utility_panels()

func fetch_reviewer_dashboard(admin_token: String) -> Dictionary:
	return await _admin_api().fetch_reviewer_dashboard(admin_token)

func fetch_admin_session(admin_token: String) -> Dictionary:
	return await _admin_api().fetch_admin_session(admin_token)

func fetch_debug_ops_admin(admin_token: String) -> Dictionary:
	return await _admin_api().fetch_debug_ops(admin_token)

func fetch_debug_rooms_admin(admin_token: String) -> Dictionary:
	return await _admin_api().fetch_debug_rooms(admin_token)

func fetch_reviewer_audit(game_id: String, admin_token: String, filters: Dictionary = {}) -> Dictionary:
	return await _admin_api().fetch_reviewer_audit(game_id, admin_token, filters)

func export_reviewer_audit_admin(game_id: String, admin_token: String, filters: Dictionary = {}) -> Dictionary:
	return await _admin_api().export_reviewer_audit(game_id, admin_token, filters)

func fetch_chat_reports_admin(admin_token: String, status: String = "open") -> Dictionary:
	return await _admin_api().fetch_chat_reports(admin_token, status)

func review_chat_report_admin(report_id: String, status: String, admin_token: String, note: String = "") -> Dictionary:
	return await _admin_api().review_chat_report(report_id, status, admin_token, note)

func fetch_chat_moderation_admin(admin_token: String, target_player_id: String = "", action: String = "", offset: int = 0) -> Dictionary:
	return await _admin_api().fetch_chat_moderation(admin_token, target_player_id, action, offset)

func export_chat_moderation_admin(admin_token: String, target_player_id: String = "", action: String = "", offset: int = 0) -> Dictionary:
	return await _admin_api().export_chat_moderation(admin_token, target_player_id, action, offset)

func apply_chat_moderation_admin(request: Dictionary, admin_token: String) -> Dictionary:
	return await _admin_api().apply_chat_moderation(request, admin_token)

func review_minigame_admin(game_id: String, action: String, admin_token: String, confirm: bool = false, note: String = "") -> Dictionary:
	return await _admin_api().review_minigame(game_id, action, admin_token, confirm, note)

func _api():
	if _endpoints == null:
		_endpoints = OnlineClientEndpointsScript.new(self)
	return _endpoints

func _auth():
	if _session == null:
		_session = OnlineClientSessionScript.new(self)
	return _session

func _admin_api():
	if _admin == null:
		_admin = OnlineClientAdminScript.new(self)
	return _admin

func _request_transport():
	if _requester == null:
		_requester = OnlineClientRequestScript.new(self)
	return _requester

func _request_json(method: int, path: String, payload: Dictionary = {}, allow_refresh: bool = true) -> Dictionary:
	return await _request_transport().request_json(method, path, payload, allow_refresh)

func _owner_or_player(owner_id: String) -> String:
	if not owner_id.is_empty():
		return owner_id
	if not player_id.is_empty():
		return player_id
	return str(_save_system().call("get_player_id"))

func _room_or_default(room_id: String) -> String:
	if room_id.is_empty():
		return "world_town_square"
	return room_id

func _mark_connected() -> void:
	if is_connected:
		return
	is_connected = true
	connection_changed.emit(is_connected)

func _mark_disconnected() -> void:
	if not is_connected:
		return
	is_connected = false
	connection_changed.emit(is_connected)

func _error(message: String, route: String) -> Dictionary:
	return {
		"ok": false,
		"offline": false,
		"route": route,
		"error": message,
		"data": {}
	}

func _save_system() -> Node:
	return get_node("/root/SaveSystem")
