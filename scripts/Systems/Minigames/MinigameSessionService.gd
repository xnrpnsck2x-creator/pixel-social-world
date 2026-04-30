class_name MinigameSessionService
extends Node

signal sessions_updated(sessions: Array[Dictionary])
signal session_action_finished(ok: bool, message: String)

const DEFAULT_ROOM_ID := "world_town_square"
const LOCAL_SESSION_PREFIX := "local_"

var room_id := DEFAULT_ROOM_ID
var registry: Node
var sessions: Array[Dictionary] = []

func initialize(new_registry: Node, new_room_id: String = DEFAULT_ROOM_ID) -> void:
	registry = new_registry
	room_id = new_room_id if not new_room_id.is_empty() else DEFAULT_ROOM_ID
	refresh_sessions()

func refresh_sessions() -> void:
	if _online_client_connected():
		await _refresh_online_sessions()
	else:
		_build_local_sessions()
	sessions_updated.emit(sessions.duplicate(true))

func get_sessions() -> Array[Dictionary]:
	return sessions.duplicate(true)

func create_session(game_id: String) -> Dictionary:
	var game := get_game(game_id)
	if game.is_empty():
		session_action_finished.emit(false, "unknown_game")
		return {"ok": false, "error": "unknown_game"}

	if not _online_client_connected():
		var local_session := _local_session_for(game)
		_remember_pending_session(game_id, str(local_session.get("id", "")))
		await refresh_sessions()
		session_action_finished.emit(true, "")
		return {"ok": true, "offline": true, "data": local_session}

	var max_players := int(game.get("max_players", 1))
	var response: Dictionary = await _online_client().call(
		"create_minigame_session",
		game_id,
		room_id,
		max_players
	)
	session_action_finished.emit(bool(response.get("ok", false)), str(response.get("error", "")))
	if bool(response.get("ok", false)):
		var session: Dictionary = response.get("data", {}) as Dictionary
		_remember_pending_session(game_id, str(session.get("id", "local")))
	await refresh_sessions()
	return response

func join_session(session_id: String) -> Dictionary:
	if session_id.is_empty():
		session_action_finished.emit(false, "missing_session")
		return {"ok": false, "error": "missing_session"}

	if not _online_client_connected():
		if sessions.is_empty():
			_build_local_sessions()
		var local_session := _find_session(session_id)
		if local_session.is_empty():
			session_action_finished.emit(false, "missing_session")
			return {"ok": false, "error": "missing_session"}
		_remember_pending_session(str(local_session.get("game_id", "")), session_id)
		session_action_finished.emit(true, "")
		return {"ok": true, "offline": true, "data": local_session}

	var response: Dictionary = await _online_client().call("join_minigame_session", session_id)
	session_action_finished.emit(bool(response.get("ok", false)), str(response.get("error", "")))
	if bool(response.get("ok", false)):
		var session: Dictionary = response.get("data", {}) as Dictionary
		_remember_pending_session(str(session.get("game_id", "")), session_id)
	await refresh_sessions()
	return response

func launch_game(game_id: String) -> void:
	var game := get_game(game_id)
	if game.is_empty():
		return
	SaveSystem.set_profile_value("pending_minigame_id", game_id)
	if str(SaveSystem.get_profile_value("pending_minigame_session_id", "")).is_empty():
		SaveSystem.set_profile_value("pending_minigame_session_id", "local")
	SaveSystem.save_profile()
	SceneRouter.route_to(str(game.get("route_id", "minigame_lobby")))

func get_game(game_id: String) -> Dictionary:
	if registry == null:
		return {}
	return registry.get_minigame(game_id)

func _refresh_online_sessions() -> void:
	var response: Dictionary = await _online_client().call("list_minigame_sessions", room_id)
	if not bool(response.get("ok", false)):
		_build_local_sessions()
		return

	var data: Dictionary = response.get("data", {}) as Dictionary
	var next_sessions: Array[Dictionary] = []
	for session in data.get("sessions", []):
		if typeof(session) == TYPE_DICTIONARY:
			next_sessions.append(session as Dictionary)
	sessions = next_sessions

func _build_local_sessions() -> void:
	sessions.clear()
	if registry == null:
		return
	for game in registry.get_enabled_minigames():
		sessions.append(_local_session_for(game))

func _local_session_for(game: Dictionary) -> Dictionary:
	var game_id := str(game.get("id", ""))
	return {
		"id": "%s%s" % [LOCAL_SESSION_PREFIX, game_id],
		"game_id": game_id,
		"room_id": room_id,
		"host_player_id": SaveSystem.get_player_id(),
		"status": "local",
		"players": [SaveSystem.get_player_id()],
		"max_players": int(game.get("max_players", 1))
	}

func _find_session(session_id: String) -> Dictionary:
	for session in sessions:
		if str(session.get("id", "")) == session_id:
			return session.duplicate(true)
	return {}

func _remember_pending_session(game_id: String, session_id: String) -> void:
	if not game_id.is_empty():
		SaveSystem.set_profile_value("pending_minigame_id", game_id)
	SaveSystem.set_profile_value("pending_minigame_session_id", session_id)
	SaveSystem.save_profile()

func _online_client_connected() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("is_connected"))

func _online_client() -> Node:
	if not has_node("/root/OnlineClient"):
		return null
	return get_node("/root/OnlineClient")
