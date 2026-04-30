class_name OnlineRoomPanelActions
extends RefCounted

signal emote_requested(emote_id: String)
signal home_invite_requested
signal home_visit_requested(owner_id: String)

var presence_service: Node
var chat_service: Node
var minigame_registry: Node
var session_service: Node

func bind_buttons(
	laugh_button: Button,
	heart_button: Button,
	exclamation_button: Button,
	host_fishing_button: Button,
	join_session_button: Button,
	invite_home_button: Button,
	visit_home_button: Button
) -> void:
	laugh_button.pressed.connect(func() -> void: emote_requested.emit("emote.laugh"))
	heart_button.pressed.connect(func() -> void: emote_requested.emit("emote.heart"))
	exclamation_button.pressed.connect(func() -> void: emote_requested.emit("emote.exclamation"))
	host_fishing_button.pressed.connect(host_fishing)
	join_session_button.pressed.connect(join_preferred_session)
	invite_home_button.pressed.connect(func() -> void: home_invite_requested.emit())
	visit_home_button.pressed.connect(visit_first_member_home)

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

func host_fishing() -> void:
	if session_service == null:
		return
	var response: Dictionary = await session_service.create_session("fishing")
	if not bool(response.get("ok", false)):
		return
	var session: Dictionary = response.get("data", {}) as Dictionary
	announce_game_invite("fishing", str(session.get("id", "")))
	session_service.launch_game("fishing")

func announce_game_invite(game_id: String, session_id: String = "") -> void:
	if chat_service == null or minigame_registry == null:
		return
	var game: Dictionary = minigame_registry.get_minigame(game_id)
	var game_name := App.t_key(str(game.get("name_key", game_id)))
	var target_session_id := session_id if not session_id.is_empty() else _find_session_id_for_game(game_id)
	var body := App.format_key("world.session_invite_chat_format", {
		"name": SaveSystem.get_display_name(),
		"game": game_name
	})
	chat_service.send_local_message(
		chat_service.get_active_view_channel_id(),
		SaveSystem.get_display_name(),
		body,
		{"action": {
			"type": "join_minigame",
			"game_id": game_id,
			"session_id": target_session_id
		}}
	)

func join_preferred_session() -> void:
	if session_service == null:
		return
	var invite := _latest_join_invite()
	if not invite.is_empty():
		var session_id := str(invite.get("session_id", ""))
		var game_id := str(invite.get("game_id", ""))
		if not session_id.is_empty():
			var joined_invite := await _join_session(session_id, game_id)
			if joined_invite:
				return
	var sessions: Array = session_service.get_sessions()
	if sessions.is_empty():
		await host_fishing()
		return
	var session: Dictionary = sessions.front()
	await _join_session(str(session.get("id", "")), str(session.get("game_id", "fishing")))

func visit_first_member_home() -> void:
	var members: Array = presence_service.get_members() if presence_service != null else []
	var local_id := SaveSystem.get_player_id()
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var owner_id := str((member as Dictionary).get("player_id", ""))
		if not owner_id.is_empty() and owner_id != local_id:
			home_visit_requested.emit(owner_id)
			return
	home_visit_requested.emit(local_id)

func _latest_join_invite() -> Dictionary:
	if chat_service == null or not chat_service.has_method("get_latest_action"):
		return {}
	var result: Dictionary = chat_service.call("get_latest_action", "join_minigame")
	var action: Variant = result.get("action", {})
	if typeof(action) == TYPE_DICTIONARY:
		return action as Dictionary
	return {}

func _find_session_id_for_game(game_id: String) -> String:
	if session_service == null:
		return ""
	for session in session_service.get_sessions():
		if typeof(session) == TYPE_DICTIONARY and str((session as Dictionary).get("game_id", "")) == game_id:
			return str((session as Dictionary).get("id", ""))
	return ""

func _join_session(session_id: String, fallback_game_id: String) -> bool:
	var response: Dictionary = await session_service.join_session(session_id)
	if not bool(response.get("ok", false)):
		return false
	var session: Dictionary = response.get("data", {}) as Dictionary
	var game_id := str(session.get("game_id", fallback_game_id))
	session_service.launch_game(game_id if not game_id.is_empty() else "fishing")
	return true
