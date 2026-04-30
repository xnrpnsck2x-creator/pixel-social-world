extends SceneTree

const WS_URL := "ws://127.0.0.1:18787/ws/city"
const HTTP_URL := "http://127.0.0.1:18787"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var room_a1 := WebSocketPeer.new()
	var room_a2 := WebSocketPeer.new()
	var room_b := WebSocketPeer.new()
	var session_a1: Dictionary = await _guest_login("A1", failures)
	var session_a2: Dictionary = await _guest_login("A2", failures)
	var session_b: Dictionary = await _guest_login("B1", failures)

	for socket in [room_a1, room_a2, room_b]:
		var error_code: int = socket.connect_to_url(WS_URL)
		if error_code != OK:
			failures.append("connect_to_url failed: %d" % error_code)

	var sockets := [room_a1, room_a2, room_b]
	if failures.is_empty():
		await _wait_all_open(sockets, failures)

	if failures.is_empty():
		_send(room_a1, "world.join", _join_payload(session_a1, "room_a", "A1"), failures)
		_send(room_a2, "world.join", _join_payload(session_a2, "room_a", "A2"), failures)
		_send(room_b, "world.join", _join_payload(session_b, "room_b", "B1"), failures)
		await _drain_for(sockets, 100)

		var chat_body := "realtime chat %d" % Time.get_ticks_msec()
		var chat_response := await _post_json("/chat/send", {
			"room_id": "room_a",
			"channel_id": "global",
			"sender_id": str(session_a1.get("player_id", "")),
			"sender_name": "A1",
			"body": chat_body,
			"action": {
				"type": "join_minigame",
				"game_id": "fishing",
				"session_id": "session_realtime"
			}
		}, str(session_a1.get("access_token", "")), failures)
		if int(chat_response.get("status", 0)) != 200:
			failures.append("chat send returned status %d." % int(chat_response.get("status", 0)))

		var chat_message: Dictionary = await _read_until(room_a2, sockets, "chat.message", 1000)
		if chat_message.is_empty():
			failures.append("room_a2 did not receive chat.message.")
		else:
			var chat_payload: Dictionary = chat_message.get("payload", {}) as Dictionary
			var message: Dictionary = chat_payload.get("message", {}) as Dictionary
			if str(message.get("body", "")) != chat_body:
				failures.append("room_a2 received the wrong chat.message body.")
			if str(message.get("sender_id", "")) != str(session_a1.get("player_id", "")):
				failures.append("room_a2 received a spoofed chat.message sender.")
			var action: Dictionary = message.get("action", {}) as Dictionary
			if str(action.get("type", "")) != "join_minigame" or str(action.get("session_id", "")) != "session_realtime":
				failures.append("room_a2 did not receive chat.message join_minigame action.")

		var leaked_chat: Dictionary = await _read_until(room_b, sockets, "chat.message", 120)
		if not leaked_chat.is_empty():
			failures.append("room_b received room_a chat.message.")

		_send(room_a1, "player.move", {
			"player_id": "spoofed-player",
			"room_id": "room_b",
			"position": {"x": 9000, "y": -9000},
			"velocity": {"x": 1, "y": 0},
			"facing": "right",
			"is_sitting": false,
			"is_attacking": false
		}, failures)
		await _pump_for(sockets, 40)

		var move_message: Dictionary = await _read_until(room_a2, sockets, "player.move", 1000)
		if move_message.is_empty():
			failures.append("room_a2 did not receive player.move.")
		else:
			var move_payload: Dictionary = move_message.get("payload", {}) as Dictionary
			if str(move_payload.get("player_id", "")) != str(session_a1.get("player_id", "")):
				failures.append("room_a2 received a spoofed player.move player_id.")
			if str(move_payload.get("room_id", "")) != "room_a":
				failures.append("room_a2 received a spoofed player.move room_id.")
			var position: Dictionary = move_payload.get("position", {}) as Dictionary
			if float(position.get("x", 0)) != 480.0 or float(position.get("y", 0)) != -300.0:
				failures.append("room_a2 received unclamped player.move position.")

		var leaked: Dictionary = await _read_until(room_b, sockets, "player.move", 120)
		if not leaked.is_empty():
			failures.append("room_b received room_a player.move.")

		_send(room_a2, "world.snapshot", {}, failures)
		var snapshot_message: Dictionary = await _read_until(room_a2, sockets, "world.snapshot", 1000)
		if snapshot_message.is_empty():
			failures.append("room_a2 did not receive world.snapshot.")
		elif not _snapshot_has_player(snapshot_message, str(session_a1.get("player_id", ""))):
			failures.append("world.snapshot did not include room_a1's last move.")

		_send(room_a2, "emote.send", {
			"player_id": "spoofed-player",
			"room_id": "room_b",
			"emote_id": "emote.exclamation"
		}, failures)
		var emote_message: Dictionary = await _read_until(room_a1, sockets, "emote.event", 1000)
		if emote_message.is_empty():
			failures.append("room_a1 did not receive emote.event.")
		else:
			var emote_payload: Dictionary = emote_message.get("payload", {}) as Dictionary
			if str(emote_payload.get("emote_id", "")) != "emote.exclamation":
				failures.append("room_a1 received the wrong emote.event payload.")
			if str(emote_payload.get("player_id", "")) != str(session_a2.get("player_id", "")):
				failures.append("room_a1 received a spoofed emote.event player_id.")

		var leaked_emote: Dictionary = await _read_until(room_b, sockets, "emote.event", 120)
		if not leaked_emote.is_empty():
			failures.append("room_b received room_a emote.event.")

		_send(room_b, "world.join", _join_payload(
			session_b,
			"home:%s" % str(session_a1.get("player_id", "")),
			"B1"
		), failures)
		var home_snapshot: Dictionary = await _read_until(room_b, sockets, "world.snapshot", 1000)
		if home_snapshot.is_empty():
			failures.append("room_b did not receive a home room snapshot.")
		var denied_message: Dictionary = await _read_until(room_b, sockets, "room.denied", 120)
		if not denied_message.is_empty():
			failures.append("room_b was denied from a public MVP home.")

	for socket in [room_a1, room_a2, room_b]:
		socket.close()

	if failures.is_empty():
		print("realtime backend e2e passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _guest_login(display_name: String, failures: Array[String]) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	var payload := {
		"device_id": "realtime-e2e-%s" % display_name,
		"display_name": display_name
	}
	var error_code := request.request(
		"%s/auth/guest" % HTTP_URL,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error_code != OK:
		request.queue_free()
		failures.append("guest login request failed: %d" % error_code)
		return {}
	var completed: Array = await request.request_completed
	request.queue_free()
	if int(completed[1]) != 200:
		failures.append("guest login returned status %d" % int(completed[1]))
		return {}
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("guest login response was not a dictionary.")
		return {}
	return parsed as Dictionary

func _post_json(path: String, payload: Dictionary, access_token: String, failures: Array[String]) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer %s" % access_token)
	var error_code := request.request(
		"%s%s" % [HTTP_URL, path],
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error_code != OK:
		request.queue_free()
		failures.append("post %s failed: %d" % [path, error_code])
		return {"status": 0}
	var completed: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}
	return {
		"status": int(completed[1]),
		"body": parsed
	}

func _join_payload(session: Dictionary, room_id: String, display_name: String) -> Dictionary:
	return {
		"player_id": str(session.get("player_id", "")),
		"access_token": str(session.get("access_token", "")),
		"room_id": room_id,
		"display_name": display_name
	}

func _snapshot_has_player(snapshot_message: Dictionary, player_id: String) -> bool:
	var payload: Dictionary = snapshot_message.get("payload", {}) as Dictionary
	for player_state in payload.get("players", []):
		if typeof(player_state) == TYPE_DICTIONARY:
			if str((player_state as Dictionary).get("player_id", "")) == player_id:
				return true
	return false

func _send(socket: WebSocketPeer, message_type: String, payload: Dictionary, failures: Array[String]) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		failures.append(
			"send %s failed because websocket state was %s, close=%d %s."
			% [
				message_type,
				_state_label(socket),
				socket.get_close_code(),
				socket.get_close_reason()
			]
		)
		return
	var error_code: int = socket.send_text(JSON.stringify({
		"schema_version": 1,
		"type": message_type,
		"sent_at": int(Time.get_unix_time_from_system()),
		"payload": payload
	}))
	if error_code != OK:
		failures.append("send %s failed: %d" % [message_type, error_code])

func _wait_all_open(sockets: Array, failures: Array[String]) -> void:
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		var open_count := 0
		for socket in sockets:
			(socket as WebSocketPeer).poll()
			if (socket as WebSocketPeer).get_ready_state() == WebSocketPeer.STATE_OPEN:
				open_count += 1
		if open_count == sockets.size():
			return
		await process_frame
	failures.append("websockets did not all open.")

func _read_until(socket: WebSocketPeer, all_sockets: Array, message_type: String, timeout_msec: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		for peer in all_sockets:
			(peer as WebSocketPeer).poll()
		while socket.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var envelope: Dictionary = parsed as Dictionary
			if str(envelope.get("type", "")) == message_type:
				return envelope
		await process_frame
	return {}

func _pump_for(sockets: Array, duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		for socket in sockets:
			(socket as WebSocketPeer).poll()
		await process_frame

func _drain_for(sockets: Array, duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		for socket in sockets:
			var peer := socket as WebSocketPeer
			peer.poll()
			while peer.get_available_packet_count() > 0:
				peer.get_packet()
		await process_frame

func _state_label(socket: WebSocketPeer) -> String:
	match socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return "connecting"
		WebSocketPeer.STATE_OPEN:
			return "open"
		WebSocketPeer.STATE_CLOSING:
			return "closing"
		WebSocketPeer.STATE_CLOSED:
			return "closed"
		_:
			return "unknown"
