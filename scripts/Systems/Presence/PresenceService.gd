class_name PresenceService
extends Node

signal presence_updated(members: Array[Dictionary], is_online: bool, seconds_since_heartbeat: int)

const DEFAULT_ROOM_ID := "world_town_square"

var room_id := DEFAULT_ROOM_ID
var display_name := ""
var members: Array[Dictionary] = []
var _last_heartbeat_msec := 0
var _tick_seconds := 10
var _timer: Timer

func initialize(new_display_name: String, new_room_id: String = DEFAULT_ROOM_ID) -> void:
	display_name = new_display_name
	room_id = new_room_id if not new_room_id.is_empty() else DEFAULT_ROOM_ID
	_tick_seconds = int(ConfigLoader.get_value("app", ["network", "presence_tick_seconds"], 10))
	_ensure_timer()
	_timer.start(max(2.0, float(_tick_seconds)))
	refresh_now()

func refresh_now() -> void:
	if _online_client_connected():
		await _refresh_online()
	else:
		_set_local_member()
	presence_updated.emit(members.duplicate(true), is_online(), seconds_since_heartbeat())

func get_members() -> Array[Dictionary]:
	return members.duplicate(true)

func is_online() -> bool:
	return _online_client_connected() and _last_heartbeat_msec > 0

func is_stale() -> bool:
	var seconds := seconds_since_heartbeat()
	return seconds >= max(15, _tick_seconds * 2)

func get_room_id() -> String:
	return room_id

func seconds_since_heartbeat() -> int:
	if _last_heartbeat_msec <= 0:
		return -1
	return int((Time.get_ticks_msec() - _last_heartbeat_msec) / 1000)

func _refresh_online() -> void:
	var client := _online_client()
	var heartbeat: Dictionary = await client.call("send_presence", room_id, display_name)
	if bool(heartbeat.get("ok", false)):
		_last_heartbeat_msec = Time.get_ticks_msec()

	var response: Dictionary = await client.call("fetch_room_members", room_id)
	if not bool(response.get("ok", false)):
		if members.is_empty():
			_set_local_member()
		return

	var data: Dictionary = response.get("data", {}) as Dictionary
	var next_members: Array[Dictionary] = []
	for member in data.get("members", []):
		if typeof(member) == TYPE_DICTIONARY:
			next_members.append(member as Dictionary)
	members = next_members
	if members.is_empty():
		_set_local_member()

func _set_local_member() -> void:
	members = [{
		"player_id": SaveSystem.get_player_id(),
		"room_id": room_id,
		"display_name": display_name,
		"last_seen_at": int(Time.get_unix_time_from_system())
	}]

func _ensure_timer() -> void:
	if _timer != null:
		return
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_presence_tick)
	add_child(_timer)

func _on_presence_tick() -> void:
	refresh_now()

func _online_client_connected() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("is_connected"))

func _online_client() -> Node:
	if not has_node("/root/OnlineClient"):
		return null
	return get_node("/root/OnlineClient")
