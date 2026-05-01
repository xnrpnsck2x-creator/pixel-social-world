extends Node

signal room_changed(room_id: String)

const MAIN_CITY_ROOM := "world_town_square"

var current_room_id := MAIN_CITY_ROOM
var _previous_room_id := MAIN_CITY_ROOM

func _ready() -> void:
	current_room_id = str(SaveSystem.get_profile_value("current_room_id", MAIN_CITY_ROOM))
	_previous_room_id = current_room_id
	var realtime := _realtime_client()
	if realtime != null and realtime.has_signal("room_denied"):
		var callback := Callable(self, "_on_room_denied")
		if not realtime.is_connected("room_denied", callback):
			realtime.connect("room_denied", callback)

func enter_main_city(display_name: String = "") -> void:
	enter_room(MAIN_CITY_ROOM, _display_name(display_name))

func enter_housing(owner_id: String = "", display_name: String = "") -> void:
	var safe_owner := owner_id if not owner_id.is_empty() else SaveSystem.get_player_id()
	enter_room("home:%s" % safe_owner, _display_name(display_name))

func enter_minigame(game_id: String, session_id: String = "", display_name: String = "") -> void:
	var safe_game := game_id if not game_id.is_empty() else "fishing"
	var safe_session := session_id if not session_id.is_empty() else "local"
	enter_room("minigame:%s:%s" % [safe_game, safe_session], _display_name(display_name))

func enter_room(room_id: String, display_name: String = "") -> void:
	if room_id.is_empty():
		room_id = MAIN_CITY_ROOM
	_previous_room_id = current_room_id
	current_room_id = room_id
	SaveSystem.set_profile_value("current_room_id", current_room_id)
	SaveSystem.save_profile()
	var realtime := _realtime_client()
	if realtime == null:
		room_changed.emit(current_room_id)
		return
	if bool(realtime.get("is_connected")):
		realtime.switch_room(current_room_id)
	else:
		realtime.connect_city(current_room_id, SaveSystem.get_player_id(), _display_name(display_name))
	room_changed.emit(current_room_id)

func _on_room_denied(room_id: String, _error: String) -> void:
	if room_id != current_room_id:
		return
	current_room_id = _previous_room_id if not _previous_room_id.is_empty() else MAIN_CITY_ROOM
	SaveSystem.set_profile_value("current_room_id", current_room_id)
	SaveSystem.save_profile()
	room_changed.emit(current_room_id)

func _display_name(display_name: String) -> String:
	if not display_name.is_empty():
		return display_name
	var saved_name := SaveSystem.get_display_name()
	if not saved_name.is_empty():
		return saved_name
	return App.t_key("login.default_name")

func _realtime_client() -> Node:
	if not has_node("/root/RealtimeClient"):
		return null
	return get_node("/root/RealtimeClient")
