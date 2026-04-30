class_name OnlineRoomPanelFormatter
extends RefCounted

static func member_rows(members: Array, local_id: String, limit: int) -> String:
	var rows := PackedStringArray()
	for member in members.slice(0, limit):
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var record := member as Dictionary
		var name := str(record.get("display_name", record.get("player_id", "")))
		var seconds := _seconds_since(int(record.get("last_seen_at", 0)))
		var key := "world.room_panel.member_self_format" if str(record.get("player_id", "")) == local_id else "world.room_panel.member_format"
		rows.append(App.format_key(key, {"name": name, "seconds": seconds}))
	return "\n".join(rows) if not rows.is_empty() else App.t_key("world.members_empty")

static func chat_rows(chat_service: Node, limit: int) -> String:
	if chat_service == null:
		return App.t_key("world.chat_empty")
	var rows := PackedStringArray()
	for message in chat_service.get_visible_messages(limit):
		rows.append(App.format_key("chat.message_format", {
			"channel": chat_service.get_channel_name(str(message.get("channel_id", ""))),
			"name": str(message.get("sender_name", "")),
			"body": str(message.get("body", ""))
		}))
	return "\n".join(rows) if not rows.is_empty() else App.t_key("world.chat_empty")

static func session_rows(session_service: Node, sessions: Array, limit: int, presence_service: Node = null) -> String:
	var rows := PackedStringArray()
	for session in sessions.slice(0, limit):
		if typeof(session) != TYPE_DICTIONARY:
			continue
		var record := session as Dictionary
		var game_id := str(record.get("game_id", ""))
		var game: Dictionary = session_service.get_game(game_id) if session_service != null else {}
		var name_key := str(game.get("name_key", game_id))
		var players: Array = record.get("players", []) as Array
		rows.append(App.format_key("world.session_row_format", {
			"name": App.t_key(name_key),
			"host": session_host_text(record, presence_service),
			"players": players.size(),
			"max": int(record.get("max_players", 1)),
			"status": session_status_text(str(record.get("status", "waiting"))),
			"slots": session_slots_text(players.size(), int(record.get("max_players", 1))),
			"ttl": session_ttl_text(int(record.get("expires_at", 0)))
		}))
	return "\n".join(rows) if not rows.is_empty() else App.t_key("world.sessions_empty")

static func invite_chip_text(chat_service: Node, minigame_registry: Node) -> String:
	var invite := latest_join_invite(chat_service)
	if invite.is_empty():
		return ""
	var action: Dictionary = invite.get("action", {}) as Dictionary
	var message: Dictionary = invite.get("message", {}) as Dictionary
	return App.format_key("world.session_invite_chip_format", {
		"name": str(message.get("sender_name", "")),
		"game": _game_name(str(action.get("game_id", "")), minigame_registry)
	})

static func latest_join_invite(chat_service: Node) -> Dictionary:
	if chat_service == null or not chat_service.has_method("get_latest_action"):
		return {}
	return chat_service.call("get_latest_action", "join_minigame") as Dictionary

static func game_catalog(minigame_registry: Node) -> String:
	if minigame_registry == null:
		return App.format_key("minigames.available_format", {"ids": "-"})
	var names := PackedStringArray()
	for game in minigame_registry.get_enabled_minigames():
		names.append(App.t_key(str(game.get("name_key", game.get("id", "")))))
	return App.format_key("minigames.available_format", {
		"ids": ", ".join(names) if not names.is_empty() else "-"
	})

static func heartbeat_text(seconds: int) -> String:
	if seconds < 0:
		return App.t_key("ui.status.offline")
	return App.format_key("world.heartbeat_format", {"seconds": seconds})

static func session_status_text(status: String) -> String:
	match status:
		"active":
			return App.t_key("world.session_status_active")
		"local":
			return App.t_key("world.session_status_local")
		"ended":
			return App.t_key("world.session_status_ended")
		_:
			return App.t_key("world.session_status_waiting")

static func session_host_text(session: Dictionary, presence_service: Node) -> String:
	var host_id := str(session.get("host_player_id", ""))
	if host_id.is_empty() or host_id == SaveSystem.get_player_id():
		return App.t_key("world.session_host_self")
	if presence_service != null:
		for member in presence_service.get_members():
			if typeof(member) == TYPE_DICTIONARY and str((member as Dictionary).get("player_id", "")) == host_id:
				return str((member as Dictionary).get("display_name", host_id))
	return host_id

static func session_slots_text(players: int, max_players: int) -> String:
	var open_slots: int = max(0, max_players - players)
	if open_slots <= 0:
		return App.t_key("world.session_slots_full")
	return App.format_key("world.session_slots_format", {"count": open_slots})

static func session_ttl_text(expires_at: int) -> String:
	if expires_at <= 0:
		return App.t_key("world.session_ttl_unknown")
	var seconds_left: int = max(0, expires_at - int(Time.get_unix_time_from_system()))
	return App.format_key("world.session_ttl_format", {
		"minutes": int(ceil(float(seconds_left) / 60.0))
	})

static func _seconds_since(unix_time: int) -> int:
	if unix_time <= 0:
		return 0
	return max(0, int(Time.get_unix_time_from_system()) - unix_time)

static func _game_name(game_id: String, minigame_registry: Node) -> String:
	if minigame_registry != null:
		var game: Dictionary = minigame_registry.get_minigame(game_id)
		if not game.is_empty():
			return App.t_key(str(game.get("name_key", game_id)))
	return game_id
