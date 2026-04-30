class_name ChatService
extends Node

signal message_added(message: Dictionary)
signal message_rejected(reason_key: String)
signal report_submitted(report: Dictionary)
signal report_failed(reason_key: String)

const MAX_LOCAL_MESSAGES := 50
const FALLBACK_CHANNEL_ID := "global"

var channels: Array[Dictionary] = []
var channels_by_id: Dictionary = {}
var messages: Array[Dictionary] = []
var default_channel_id := FALLBACK_CHANNEL_ID
var active_view_channel_id := FALLBACK_CHANNEL_ID
var room_id := "world_town_square"
var _message_ids := {}

func initialize() -> void:
	channels.clear()
	channels_by_id.clear()
	messages.clear()
	_message_ids.clear()
	default_channel_id = FALLBACK_CHANNEL_ID
	active_view_channel_id = FALLBACK_CHANNEL_ID
	var config: Dictionary = ConfigLoader.load_config("chat_channels")
	for channel in config.get("channels", []):
		if typeof(channel) == TYPE_DICTIONARY:
			var channel_record: Dictionary = channel as Dictionary
			var channel_id: String = str(channel_record.get("id", ""))
			if channel_id.is_empty():
				continue
			channels.append(channel_record)
			channels_by_id[channel_id] = channel_record
			if bool(channel_record.get("default_join", false)) and bool(channel_record.get("player_can_post", false)):
				default_channel_id = channel_id

	if not channels_by_id.has(default_channel_id) and not channels.is_empty():
		default_channel_id = str(channels.front().get("id", FALLBACK_CHANNEL_ID))
	active_view_channel_id = default_channel_id

func send_local_message(channel_id: String, sender_name: String, body: String, extra: Dictionary = {}) -> bool:
	var channel: Dictionary = get_channel(channel_id)
	if channel.is_empty() or not bool(channel.get("player_can_post", false)):
		message_rejected.emit("error.content_missing")
		return false

	var clean_body: String = body.strip_edges()
	if clean_body.is_empty():
		return false

	var max_length: int = int(channel.get("max_message_length", 180))
	if clean_body.length() > max_length:
		clean_body = clean_body.substr(0, max_length)

	if _online_client_connected():
		_submit_online_message(channel_id, sender_name, clean_body, extra)
		return true

	var message: Dictionary = {
		"id": "%s-%d" % [channel_id, Time.get_ticks_msec()],
		"room_id": room_id,
		"channel_id": channel_id,
		"sender_id": SaveSystem.get_player_id(),
		"sender_name": sender_name,
		"body": clean_body,
		"created_at": int(Time.get_unix_time_from_system())
	}
	_apply_message_extra(message, extra)
	_add_message(message)
	return true

func load_history(new_room_id: String, channel_id: String = "", limit: int = 40) -> void:
	room_id = new_room_id if not new_room_id.is_empty() else room_id
	if not _online_client_connected():
		return
	var active_channel := channel_id if not channel_id.is_empty() else default_channel_id
	var response: Dictionary = await _online_client().call("fetch_chat_history", room_id, active_channel, limit)
	if not bool(response.get("ok", false)):
		return
	for message in (response.get("data", {}) as Dictionary).get("messages", []):
		if typeof(message) == TYPE_DICTIONARY:
			_add_message(message as Dictionary)

func ingest_remote_message(payload: Dictionary) -> void:
	var message: Variant = payload.get("message", payload)
	if typeof(message) == TYPE_DICTIONARY:
		_add_message(message as Dictionary)

func add_system_message(sender_name: String, body: String) -> void:
	var clean_body := body.strip_edges()
	if clean_body.is_empty():
		return
	_add_message({
		"id": "system-%d" % Time.get_ticks_usec(),
		"room_id": room_id,
		"channel_id": "system",
		"sender_id": "system",
		"sender_name": sender_name,
		"body": clean_body,
		"created_at": int(Time.get_unix_time_from_system())
	})

func get_recent_messages(limit: int = 20) -> Array[Dictionary]:
	var start_index: int = max(0, messages.size() - limit)
	return messages.slice(start_index, messages.size())

func get_visible_messages(limit: int = 20) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index in range(messages.size() - 1, -1, -1):
		var message: Dictionary = messages[index]
		var channel_id := str(message.get("channel_id", ""))
		if channel_id == "system" or channel_id == active_view_channel_id:
			rows.push_front(message)
		if rows.size() >= limit:
			break
	return rows

func get_latest_reportable_message() -> Dictionary:
	var local_id := SaveSystem.get_player_id()
	for index in range(messages.size() - 1, -1, -1):
		var message: Dictionary = messages[index]
		var channel_id := str(message.get("channel_id", ""))
		if channel_id == "system" or channel_id != active_view_channel_id:
			continue
		if str(message.get("sender_id", "")) == local_id:
			continue
		if str(message.get("id", "")).is_empty():
			continue
		return message
	return {}

func get_latest_action(action_type: String) -> Dictionary:
	for index in range(messages.size() - 1, -1, -1):
		var message: Dictionary = messages[index]
		var action: Variant = message.get("action", {})
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_record := action as Dictionary
		if str(action_record.get("type", "")) == action_type:
			return {
				"message": message.duplicate(true),
				"action": action_record.duplicate(true)
			}
	return {}

func can_report_latest_visible_message() -> bool:
	return _online_client_connected() and not get_latest_reportable_message().is_empty()

func report_latest_visible_message() -> bool:
	var message := get_latest_reportable_message()
	if message.is_empty():
		add_system_message(App.t_key("chat.system.name"), App.t_key("chat.report.empty"))
		report_failed.emit("chat.report.empty")
		return false
	if not _online_client_connected():
		add_system_message(App.t_key("chat.system.name"), App.t_key("chat.report.unavailable"))
		report_failed.emit("chat.report.unavailable")
		return false
	var response: Dictionary = await _online_client().call("report_chat_message", message, "player_report")
	if bool(response.get("ok", false)):
		add_system_message(App.t_key("chat.system.name"), App.t_key("chat.report.sent"))
		report_submitted.emit(response.get("data", {}) as Dictionary)
		return true
	var reason_key := "chat.report.failed"
	add_system_message(App.t_key("chat.system.name"), App.t_key(reason_key))
	report_failed.emit(reason_key)
	return false

func set_view_channel(channel_id: String) -> void:
	if channels_by_id.has(channel_id):
		active_view_channel_id = channel_id

func get_channel_name(channel_id: String) -> String:
	var channel: Dictionary = get_channel(channel_id)
	if channel.is_empty():
		return channel_id
	return App.t_key(str(channel.get("name_key", channel_id)))

func get_default_channel_id() -> String:
	return default_channel_id

func get_active_view_channel_id() -> String:
	return active_view_channel_id if not active_view_channel_id.is_empty() else default_channel_id

func get_postable_channels() -> Array[Dictionary]:
	var postable: Array[Dictionary] = []
	for channel in channels:
		if bool(channel.get("player_can_post", false)):
			postable.append(channel)
	return postable

func get_channel(channel_id: String) -> Dictionary:
	if channels_by_id.has(channel_id):
		return channels_by_id[channel_id] as Dictionary
	return {}

func _submit_online_message(channel_id: String, sender_name: String, body: String, extra: Dictionary = {}) -> void:
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call("send_chat", room_id, channel_id, sender_name, body, extra)
	if bool(response.get("ok", false)):
		var message: Dictionary = response.get("data", {}) as Dictionary
		_apply_message_extra(message, extra)
		_add_message(message)
	else:
		var reason_key := _rejection_key(str(response.get("error", "error.content_missing")))
		add_system_message(App.t_key("chat.system.name"), App.t_key(reason_key))
		message_rejected.emit(reason_key)

func _apply_message_extra(message: Dictionary, extra: Dictionary) -> void:
	if extra.is_empty():
		return
	for key in extra.keys():
		var key_name := str(key)
		if ["id", "room_id", "channel_id", "sender_id", "sender_name", "body", "created_at"].has(key_name):
			continue
		message[key_name] = extra[key]

func _add_message(message: Dictionary) -> void:
	var message_id := str(message.get("id", ""))
	if not message_id.is_empty() and _message_ids.has(message_id):
		return
	if not message_id.is_empty():
		_message_ids[message_id] = true
	messages.append(message)
	messages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("created_at", 0)) < int(b.get("created_at", 0))
	)
	while messages.size() > MAX_LOCAL_MESSAGES:
		var removed: Dictionary = messages.pop_front()
		_message_ids.erase(str(removed.get("id", "")))
	message_added.emit(message)

func _online_client_connected() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("is_connected"))

func _online_client() -> Node:
	if not has_node("/root/OnlineClient"):
		return null
	return get_node("/root/OnlineClient")

func _rejection_key(error: String) -> String:
	match error:
		"rate_limited":
			return "chat.send.rate_limited"
		"chat_muted":
			return "chat.send.muted"
		"chat_banned":
			return "chat.send.banned"
		"body_too_long":
			return "chat.send.too_long"
		_:
			return "chat.send.failed"
