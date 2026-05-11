class_name OnlineClientRequest
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func request_json(
	method: int,
	path: String,
	payload: Dictionary = {},
	allow_refresh: bool = true
) -> Dictionary:
	if not bool(_client.get("online_enabled")):
		return _client._error("online_disabled", path)

	var request := HTTPRequest.new()
	request.timeout = float(_client.get("timeout_seconds"))
	_client.add_child(request)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if not str(_client.get("access_token")).is_empty():
		headers.append("Authorization: Bearer %s" % str(_client.get("access_token")))

	var body := ""
	if method != HTTPClient.METHOD_GET:
		body = JSON.stringify(payload)

	var error_code := request.request(str(_client.get("base_url")) + path, headers, method, body)
	if error_code != OK:
		request.queue_free()
		_client._mark_disconnected()
		_client.request_failed.emit(path, "request_start_failed")
		return _client._error("request_start_failed", path)

	var completed: Array = await request.request_completed
	request.queue_free()
	var result_code := int(completed[0])
	var response_code := int(completed[1])
	var parsed := _parse_json(completed[3] as PackedByteArray)

	if response_code >= 200 and response_code < 300:
		_client._mark_connected()
		return {"ok": true, "offline": false, "status": response_code, "route": path, "data": parsed}

	if response_code == 401 and allow_refresh and path != "/auth/refresh":
		var refreshed: Dictionary = await _client.refresh_session()
		if bool(refreshed.get("ok", false)):
			return await request_json(method, path, payload, false)

	if response_code == 401 or response_code == 403:
		_client._mark_disconnected()
	elif response_code > 0 and result_code == OK:
		_client._mark_connected()
	else:
		_client._mark_disconnected()
	var message := str(parsed.get("error", "http_%d" % response_code))
	_client.request_failed.emit(path, message)
	return {
		"ok": false,
		"offline": false,
		"status": response_code,
		"route": path,
		"error": message,
		"data": parsed
	}

func _parse_json(body_bytes: PackedByteArray) -> Dictionary:
	var body_text := body_bytes.get_string_from_utf8().strip_edges()
	if body_text.is_empty():
		return {}
	var parser := JSON.new()
	if parser.parse(body_text) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
