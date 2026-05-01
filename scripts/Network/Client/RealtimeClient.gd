extends Node

signal message_received(message_type: String, payload: Dictionary)
signal connection_changed(is_connected: bool)
signal room_denied(room_id: String, error: String)

const MessageTypesScript := preload("res://scripts/Network/Protocol/MessageTypes.gd")

var websocket_url := "ws://127.0.0.1:8787/ws/city"
var online_enabled := true
var reconnect_attempts := 3
var is_connected := false
var _socket := WebSocketPeer.new()
var _joined := false
var _room_id := "world_town_square"
var _confirmed_room_id := "world_town_square"
var _pending_room_id := ""
var _player_id := ""
var _display_name := ""
var _access_token := ""
var _has_manual_config := false
var _should_reconnect := false
var _reconnect_attempt := 0
var _next_reconnect_msec := 0

func _ready() -> void:
	_connect_app_config_signal()
	configure()

func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN and not is_connected:
		is_connected = true
		_reconnect_attempt = 0
		connection_changed.emit(true)
		if not _joined and not _player_id.is_empty():
			_joined = true
			send_join(_room_id, _player_id, _display_name)
			request_snapshot()
	elif state != WebSocketPeer.STATE_OPEN and is_connected:
		is_connected = false
		_joined = false
		connection_changed.emit(false)
		_schedule_reconnect()
	elif state == WebSocketPeer.STATE_CLOSED:
		if _should_reconnect and _next_reconnect_msec <= 0:
			_schedule_reconnect()
		_try_reconnect()

	while _socket.get_available_packet_count() > 0:
		_receive_packet(_socket.get_packet().get_string_from_utf8())

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
	websocket_url = str(network.get("websocket_url", websocket_url))
	online_enabled = bool(network.get("online_enabled", online_enabled))
	reconnect_attempts = int(network.get("reconnect_attempts", reconnect_attempts))

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

func connect_city(room_id: String, player_id: String, display_name: String, access_token: String = "") -> void:
	configure()
	_room_id = room_id
	_player_id = player_id
	_display_name = display_name
	_access_token = access_token if not access_token.is_empty() else _resolve_access_token()
	_should_reconnect = online_enabled
	if not online_enabled:
		return
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		send_join(_room_id, _player_id, _display_name)
		request_snapshot()
		return
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_CLOSING:
		return
	_joined = false
	var error_code := _socket.connect_to_url(websocket_url)
	if error_code != OK:
		is_connected = false
		connection_changed.emit(false)
		_schedule_reconnect()

func disconnect_city() -> void:
	_should_reconnect = false
	_joined = false
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()

func pause_realtime() -> void:
	_should_reconnect = false
	_joined = false
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()

func resume_realtime() -> void:
	if not online_enabled or _player_id.is_empty():
		return
	_reconnect_attempt = 0
	_next_reconnect_msec = 0
	_socket = WebSocketPeer.new()
	connect_city(_room_id, _player_id, _display_name, _access_token)

func switch_room(room_id: String) -> void:
	_room_id = room_id
	_joined = false
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_joined = true
		send_join(_room_id, _player_id, _display_name)
		request_snapshot()

func send_join(room_id: String, player_id: String, display_name: String) -> void:
	_pending_room_id = room_id
	send_envelope(MessageTypesScript.WORLD_JOIN, {
		"room_id": room_id,
		"player_id": player_id,
		"display_name": display_name,
		"access_token": _access_token
	})

func send_player_move(payload: Dictionary) -> void:
	send_envelope(MessageTypesScript.PLAYER_MOVE, payload)

func request_snapshot() -> void:
	send_envelope(MessageTypesScript.WORLD_SNAPSHOT, {"room_id": _room_id})

func send_envelope(message_type: String, payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var envelope := {
		"schema_version": 1,
		"type": message_type,
		"sent_at": int(Time.get_unix_time_from_system()),
		"payload": payload
	}
	_socket.send_text(JSON.stringify(envelope))

func _receive_packet(packet_text: String) -> void:
	var parsed: Variant = JSON.parse_string(packet_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var envelope: Dictionary = parsed as Dictionary
	var payload: Dictionary = {}
	if typeof(envelope.get("payload", {})) == TYPE_DICTIONARY:
		payload = envelope.get("payload", {}) as Dictionary
	var message_type := str(envelope.get("type", ""))
	message_received.emit(message_type, payload)
	if message_type == MessageTypesScript.AUTH_FAILED:
		_should_reconnect = false
		disconnect_city()
	elif message_type == MessageTypesScript.ROOM_DENIED:
		var denied_room := str(payload.get("room_id", _pending_room_id))
		_room_id = _confirmed_room_id
		_pending_room_id = ""
		room_denied.emit(denied_room, str(payload.get("error", "room_denied")))
	elif message_type == MessageTypesScript.WORLD_JOIN:
		if str(payload.get("player_id", "")) == _player_id:
			_confirmed_room_id = str(payload.get("room_id", _room_id))
			_room_id = _confirmed_room_id
			_pending_room_id = ""

func _schedule_reconnect() -> void:
	if not _should_reconnect or not online_enabled or _player_id.is_empty():
		return
	if reconnect_attempts <= 0 or _reconnect_attempt >= reconnect_attempts:
		return
	var delay_seconds: float = min(8.0, 0.5 * pow(2.0, float(_reconnect_attempt)))
	_reconnect_attempt += 1
	_next_reconnect_msec = Time.get_ticks_msec() + int(delay_seconds * 1000.0)

func _try_reconnect() -> void:
	if not _should_reconnect or _next_reconnect_msec <= 0:
		return
	if Time.get_ticks_msec() < _next_reconnect_msec:
		return
	_next_reconnect_msec = 0
	_joined = false
	_socket = WebSocketPeer.new()
	var error_code := _socket.connect_to_url(websocket_url)
	if error_code != OK:
		_schedule_reconnect()

func _resolve_access_token() -> String:
	if has_node("/root/OnlineClient"):
		var online_client := get_node("/root/OnlineClient")
		var token := str(online_client.get("access_token"))
		if not token.is_empty():
			return token
	if has_node("/root/SaveSystem"):
		if has_node("/root/SessionTokenStore"):
			return str(get_node("/root/SessionTokenStore").call("get_access_token", ""))
		return str(get_node("/root/SaveSystem").call("get_profile_value", "access_token", ""))
	return ""
