class_name ChatActionRouter
extends RefCounted

signal action_failed(reason: String)

var minigame_session_service: Node

func bind_minigame_session_service(new_minigame_session_service: Node) -> void:
	minigame_session_service = new_minigame_session_service

func handle_action(action: Dictionary) -> bool:
	match str(action.get("type", "")):
		"join_minigame":
			return await _join_minigame(action)
		_:
			action_failed.emit("unsupported_action")
			return false

func _join_minigame(action: Dictionary) -> bool:
	if minigame_session_service == null:
		action_failed.emit("missing_minigame_session_service")
		return false
	var session_id := str(action.get("session_id", ""))
	var fallback_game_id := str(action.get("game_id", "fishing"))
	if session_id.is_empty():
		action_failed.emit("missing_session")
		return false
	var response: Dictionary = await minigame_session_service.join_session(session_id)
	if not bool(response.get("ok", false)):
		action_failed.emit(str(response.get("error", "join_failed")))
		return false
	var session: Dictionary = response.get("data", {}) as Dictionary
	var game_id := str(session.get("game_id", fallback_game_id))
	minigame_session_service.launch_game(game_id if not game_id.is_empty() else "fishing")
	return true
