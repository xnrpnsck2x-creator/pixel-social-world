class_name OnlineClientEndpoints
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func fetch_housing_layout(owner_id: String = "") -> Dictionary:
	var safe_owner: String = _client._owner_or_player(owner_id).uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, "/housing/layout/%s" % safe_owner)

func place_housing_item(owner_id: String, item_id: String, tile: Vector2i, rotation: int = 0) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/place", {
		"owner_id": _client._owner_or_player(owner_id),
		"player_id": _client.player_id,
		"item_id": item_id,
		"tile_x": tile.x,
		"tile_y": tile.y,
		"rotation": rotation
	})

func apply_housing_style(owner_id: String, category: String, item_id: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/style", {
		"owner_id": _client._owner_or_player(owner_id),
		"player_id": _client.player_id,
		"category": category,
		"item_id": item_id
	})

func move_housing_item(
	owner_id: String,
	item: Dictionary,
	target_tile: Vector2i,
	target_rotation: int
) -> Dictionary:
	var tile: Dictionary = item.get("tile", {}) as Dictionary
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/move", {
		"owner_id": _client._owner_or_player(owner_id),
		"player_id": _client.player_id,
		"item_id": str(item.get("item_id", "")),
		"tile_x": int(tile.get("x", 0)),
		"tile_y": int(tile.get("y", 0)),
		"rotation": int(item.get("rotation", 0)),
		"target_tile_x": target_tile.x,
		"target_tile_y": target_tile.y,
		"target_rotation": target_rotation
	})

func remove_housing_item(owner_id: String, item: Dictionary) -> Dictionary:
	var tile: Dictionary = item.get("tile", {}) as Dictionary
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/remove", {
		"owner_id": _client._owner_or_player(owner_id),
		"player_id": _client.player_id,
		"item_id": str(item.get("item_id", "")),
		"tile_x": int(tile.get("x", 0)),
		"tile_y": int(tile.get("y", 0)),
		"rotation": int(item.get("rotation", 0))
	})

func create_housing_invite(owner_id: String = "") -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/invite", {
		"owner_id": _client._owner_or_player(owner_id),
		"sender_id": _client.player_id
	})

func visit_housing(owner_id: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/housing/visit", {
		"owner_id": _client._owner_or_player(owner_id),
		"visitor_id": _client.player_id
	})

func fetch_coin_ledger(player_id_override: String = "") -> Dictionary:
	var safe_player: String = _client._owner_or_player(player_id_override).uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, "/economy/ledger/%s" % safe_player)

func send_chat(
	room_id: String,
	channel_id: String,
	sender_name: String,
	body: String,
	extra: Dictionary = {}
) -> Dictionary:
	var payload := {
		"room_id": _client._room_or_default(room_id),
		"channel_id": channel_id,
		"sender_id": _client.player_id,
		"sender_name": sender_name,
		"body": body
	}
	if extra.has("action") and typeof(extra.get("action")) == TYPE_DICTIONARY:
		payload["action"] = extra.get("action")
	return await _client._request_json(HTTPClient.METHOD_POST, "/chat/send", payload)

func fetch_chat_history(room_id: String, channel_id: String, limit: int = 50) -> Dictionary:
	var route := "/chat/history/%s/%s?limit=%d" % [
		_client._room_or_default(room_id).uri_encode(),
		channel_id.uri_encode(),
		limit
	]
	route += "&player_id=%s" % _client.player_id.uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func report_chat_message(message: Dictionary, reason: String = "player_report") -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/chat/report", {
		"message_id": str(message.get("id", "")),
		"room_id": _client._room_or_default(str(message.get("room_id", ""))),
		"channel_id": str(message.get("channel_id", "")),
		"reporter_id": _client.player_id,
		"reason": reason
	})

func report_player_profile(profile: Dictionary, reason: String = "profile_report") -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/players/report", {
		"target_player_id": str(profile.get("player_id", "")),
		"target_player_name": str(profile.get("display_name", "")),
		"reporter_id": _client.player_id,
		"context_room_id": _client._room_or_default(str(profile.get("room_id", ""))),
		"reason": reason
	})

func social_action(action: String, target_player_id: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/social/%s" % action, {
		"player_id": _client.player_id,
		"target_player_id": target_player_id
	})

func fetch_social_state(target_player_id: String) -> Dictionary:
	var route := "/social/state/%s?player_id=%s" % [
		target_player_id.uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func send_private_message(recipient_id: String, body: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/private-messages", {
		"sender_id": _client.player_id,
		"recipient_id": recipient_id,
		"body": body
	})

func fetch_private_conversation(peer_id: String, limit: int = 50, offset: int = 0) -> Dictionary:
	var route := "/private-messages/%s?player_id=%s&limit=%d&offset=%d" % [
		peer_id.uri_encode(),
		_client.player_id.uri_encode(),
		limit,
		offset
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_private_conversations(limit: int = 50, offset: int = 0) -> Dictionary:
	var route := "/private-messages?player_id=%s&limit=%d&offset=%d" % [_client.player_id.uri_encode(), limit, offset]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func mark_private_read(peer_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_POST,
		"/private-messages/read/%s" % peer_id.uri_encode(),
		{"player_id": _client.player_id}
	)

func report_private_message(message: Dictionary, reason: String = "player_report") -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/private-messages/report", {
		"message_id": str(message.get("id", "")),
		"reporter_id": _client.player_id,
		"reason": reason
	})

func send_mail(recipient_id: String, subject: String, body: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/mailbox/send", {
		"sender_id": _client.player_id,
		"recipient_id": recipient_id,
		"subject": subject,
		"body": body
	})

func fetch_mailbox(limit: int = 50, offset: int = 0) -> Dictionary:
	var route := "/mailbox/inbox?player_id=%s&limit=%d&offset=%d" % [_client.player_id.uri_encode(), limit, offset]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func mark_mail_read(mail_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_POST,
		"/mailbox/%s/read" % mail_id.uri_encode(),
		{"player_id": _client.player_id}
	)

func send_presence(room_id: String, display_name: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/presence/heartbeat", {
		"player_id": _client.player_id,
		"room_id": _client._room_or_default(room_id),
		"display_name": display_name
	})

func fetch_room_members(room_id: String) -> Dictionary:
	var route := "/rooms/%s/members?player_id=%s" % [
		_client._room_or_default(room_id).uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func create_minigame_session(game_id: String, room_id: String, max_players: int = 0) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/minigame-sessions", {
		"game_id": game_id,
		"room_id": _client._room_or_default(room_id),
		"host_player_id": _client.player_id,
		"max_players": max_players
	})

func list_minigame_sessions(room_id: String) -> Dictionary:
	var route := "/minigame-sessions/%s?player_id=%s" % [
		_client._room_or_default(room_id).uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func join_minigame_session(session_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_POST,
		"/minigame-sessions/%s/join" % session_id.uri_encode(),
		{"player_id": _client.player_id}
	)

func leave_minigame_session(session_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_POST,
		"/minigame-sessions/%s/leave" % session_id.uri_encode(),
		{"player_id": _client.player_id}
	)

func end_minigame_session(session_id: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/minigame-sessions/%s/end" % session_id.uri_encode())

func claim_fishing_catch(session_id: String, request_id: String = "") -> Dictionary:
	if request_id.is_empty():
		request_id = "%s-%d" % [session_id, Time.get_ticks_usec()]
	return await _client._request_json(HTTPClient.METHOD_POST, "/minigames/fishing/catch", {
		"player_id": _client.player_id,
		"session_id": session_id,
		"request_id": request_id
	})

func submit_creator_draft(request: Dictionary) -> Dictionary:
	var payload := request.duplicate(true)
	payload["author"] = _client.player_id
	return await _client._request_json(HTTPClient.METHOD_POST, "/creator-submissions/draft", payload)

func submit_creator_package(request: Dictionary) -> Dictionary:
	var payload := request.duplicate(true)
	payload["author"] = _client.player_id
	return await _client._request_json(HTTPClient.METHOD_POST, "/creator-submissions/package", payload)

func fetch_creator_submission_status(game_id: String) -> Dictionary:
	var route := "/creator-submissions/%s/status?player_id=%s" % [
		game_id.uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_creator_submission_history(game_id: String) -> Dictionary:
	var route := "/creator-submissions/%s/history?player_id=%s" % [
		game_id.uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_utility_panels() -> Dictionary:
	var route := "/utility/panels?player_id=%s" % _client.player_id.uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, route)
