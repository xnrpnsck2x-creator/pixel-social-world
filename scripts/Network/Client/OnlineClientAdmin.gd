class_name OnlineClientAdmin
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func fetch_reviewer_dashboard(admin_token: String) -> Dictionary:
	return await _request_admin_json(HTTPClient.METHOD_GET, "/admin/reviewer-dashboard", {}, admin_token)

func fetch_admin_session(admin_token: String) -> Dictionary:
	return await _request_admin_json(HTTPClient.METHOD_GET, "/admin/session", {}, admin_token)

func fetch_debug_ops(admin_token: String) -> Dictionary:
	return await _request_admin_json(HTTPClient.METHOD_GET, "/debug/ops", {}, admin_token)

func fetch_debug_rooms(admin_token: String) -> Dictionary:
	return await _request_admin_json(HTTPClient.METHOD_GET, "/debug/rooms", {}, admin_token)

func fetch_inventory_audit(player_id: String, admin_token: String) -> Dictionary:
	return await _request_admin_json(HTTPClient.METHOD_GET, "/admin/inventory/audit?player_id=%s" % player_id.uri_encode(), {}, admin_token)

func fetch_admin_action_audit(admin_token: String, filters: Dictionary = {}) -> Dictionary:
	var query_filters := filters.duplicate()
	if not query_filters.has("limit"):
		query_filters["limit"] = 25
	return await _request_admin_json(
		HTTPClient.METHOD_GET,
		"/admin/action-audit%s" % _query_string(query_filters),
		{},
		admin_token
	)

func fetch_trade_history_audit(admin_token: String, filters: Dictionary = {}) -> Dictionary:
	var query_filters := filters.duplicate()
	if not query_filters.has("limit"):
		query_filters["limit"] = 25
	return await _request_admin_json(
		HTTPClient.METHOD_GET,
		"/admin/trade/history%s" % _query_string(query_filters),
		{},
		admin_token
	)

func export_trade_history_audit(admin_token: String, filters: Dictionary = {}) -> Dictionary:
	var export_filters := filters.duplicate()
	if not export_filters.has("limit"):
		export_filters["limit"] = 25
	export_filters["format"] = "csv"
	return await _request_admin_text(
		HTTPClient.METHOD_GET,
		"/admin/trade/history%s" % _query_string(export_filters),
		{},
		admin_token
	)

func fetch_reviewer_audit(game_id: String, admin_token: String, filters: Dictionary = {}) -> Dictionary:
	return await _request_admin_json(
		HTTPClient.METHOD_GET,
		"/admin/reviewer-audit/%s%s" % [game_id.uri_encode(), _query_string(filters)],
		{},
		admin_token
	)

func export_reviewer_audit(game_id: String, admin_token: String, filters: Dictionary = {}) -> Dictionary:
	var export_filters := filters.duplicate()
	export_filters["format"] = "csv"
	return await _request_admin_text(
		HTTPClient.METHOD_GET,
		"/admin/reviewer-audit/%s%s" % [game_id.uri_encode(), _query_string(export_filters)],
		{},
		admin_token
	)

func fetch_chat_reports(admin_token: String, status: String = "open") -> Dictionary:
	var query := "?status=%s" % status.uri_encode() if not status.is_empty() else ""
	return await _request_admin_json(HTTPClient.METHOD_GET, "/admin/chat-reports%s" % query, {}, admin_token)

func review_chat_report(report_id: String, status: String, admin_token: String, note: String = "") -> Dictionary:
	return await _request_admin_json(
		HTTPClient.METHOD_POST,
		"/admin/chat-reports/%s/review" % report_id.uri_encode(),
		{"status": status, "note": note},
		admin_token
	)

func fetch_chat_moderation(
	admin_token: String,
	target_player_id: String = "",
	action: String = "",
	offset: int = 0
) -> Dictionary:
	var query := _query_string({"target_player_id": target_player_id, "action": action, "offset": offset})
	return await _request_admin_json(HTTPClient.METHOD_GET, "/admin/chat-moderation/actions%s" % query, {}, admin_token)

func export_chat_moderation(
	admin_token: String,
	target_player_id: String = "",
	action: String = "",
	offset: int = 0
) -> Dictionary:
	var query := _query_string({
		"target_player_id": target_player_id,
		"action": action,
		"offset": offset,
		"format": "csv"
	})
	return await _request_admin_text(HTTPClient.METHOD_GET, "/admin/chat-moderation/actions%s" % query, {}, admin_token)

func apply_chat_moderation(request: Dictionary, admin_token: String) -> Dictionary:
	return await _request_admin_json(
		HTTPClient.METHOD_POST,
		"/admin/chat-moderation/actions",
		request,
		admin_token
	)

func review_minigame(game_id: String, action: String, admin_token: String, confirm: bool = false, note: String = "") -> Dictionary:
	return await _request_admin_json(
		HTTPClient.METHOD_POST,
		"/minigames/%s/review" % game_id.uri_encode(),
		{"action": action, "confirm": confirm, "note": note},
		admin_token
	)

func _request_admin_json(method: int, path: String, payload: Dictionary, admin_token: String) -> Dictionary:
	_client.configure()
	if not bool(_client.get("online_enabled")):
		return _client._error("online_disabled", path)

	var request := HTTPRequest.new()
	request.timeout = float(_client.get("timeout_seconds"))
	_client.add_child(request)

	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append("X-Admin-Client: godot-reviewer-console")
	if not admin_token.is_empty():
		headers.append("Authorization: Bearer %s" % admin_token)

	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var request_error := request.request(str(_client.get("base_url")) + path, headers, method, body)
	if request_error != OK:
		request.queue_free()
		_client._mark_disconnected()
		_client.request_failed.emit(path, "request_start_failed")
		return _client._error("request_start_failed", path)

	var completed: Array = await request.request_completed
	request.queue_free()
	var response_code := int(completed[1])
	var body_text := (completed[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(body_text) if not body_text.is_empty() else {}
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = {}

	if response_code >= 200 and response_code < 300:
		_client._mark_connected()
		return {"ok": true, "offline": false, "status": response_code, "route": path, "data": parsed}

	_client._mark_connected()
	var message := str((parsed as Dictionary).get("error", "http_%d" % response_code))
	_client.request_failed.emit(path, message)
	return {
		"ok": false,
		"offline": false,
		"status": response_code,
		"route": path,
		"error": message,
		"data": parsed
	}

func _request_admin_text(method: int, path: String, payload: Dictionary, admin_token: String) -> Dictionary:
	_client.configure()
	if not bool(_client.get("online_enabled")):
		return _client._error("online_disabled", path)

	var request := HTTPRequest.new()
	request.timeout = float(_client.get("timeout_seconds"))
	_client.add_child(request)

	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append("X-Admin-Client: godot-reviewer-console")
	if not admin_token.is_empty():
		headers.append("Authorization: Bearer %s" % admin_token)

	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var request_error := request.request(str(_client.get("base_url")) + path, headers, method, body)
	if request_error != OK:
		request.queue_free()
		_client._mark_disconnected()
		_client.request_failed.emit(path, "request_start_failed")
		return _client._error("request_start_failed", path)

	var completed: Array = await request.request_completed
	request.queue_free()
	var response_code := int(completed[1])
	var body_text := (completed[3] as PackedByteArray).get_string_from_utf8()
	if response_code >= 200 and response_code < 300:
		_client._mark_connected()
		return {
			"ok": true,
			"offline": false,
			"status": response_code,
			"route": path,
			"data": {"text": body_text, "bytes": body_text.length()}
		}

	_client._mark_connected()
	var parsed: Variant = JSON.parse_string(body_text) if not body_text.is_empty() else {}
	var message := "http_%d" % response_code
	if typeof(parsed) == TYPE_DICTIONARY:
		message = str((parsed as Dictionary).get("error", message))
	_client.request_failed.emit(path, message)
	return {"ok": false, "offline": false, "status": response_code, "route": path, "error": message, "data": {}}

func _query_string(filters: Dictionary) -> String:
	var parts: Array[String] = []
	for key in filters.keys():
		var value := str(filters[key])
		if value.is_empty() or value == "0":
			continue
		parts.append("%s=%s" % [str(key).uri_encode(), value.uri_encode()])
	if parts.is_empty():
		return ""
	return "?%s" % "&".join(parts)
