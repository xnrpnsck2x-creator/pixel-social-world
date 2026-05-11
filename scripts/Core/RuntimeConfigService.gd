extends Node

signal runtime_config_loaded(config: Dictionary)
signal runtime_config_failed(reason: String)

const ALLOWED_NETWORK_KEYS := [
	"environment",
	"online_enabled",
	"base_url",
	"websocket_url",
	"http_timeout_seconds",
	"presence_tick_seconds",
	"reconnect_attempts"
]
const ALLOWED_TOP_LEVEL_KEYS := ["maintenance", "min_client_version", "web_build"]

func resolve_app_config(app_config: Dictionary) -> Dictionary:
	var runtime: Dictionary = app_config.get("runtime_config", {}) as Dictionary
	if not bool(runtime.get("enabled", false)):
		return app_config.duplicate(true)

	var overrides: Dictionary = {}
	var url := _normalize_url(str(runtime.get("url", "")).strip_edges())
	if not url.is_empty():
		var fetched: Dictionary = await _fetch_json(url, float(runtime.get("timeout_seconds", 0.75)))
		if bool(fetched.get("ok", false)):
			overrides = fetched.get("data", {}) as Dictionary
		else:
			runtime_config_failed.emit(str(fetched.get("error", "fetch_failed")))

	if overrides.is_empty():
		var fallback_path := str(runtime.get("local_fallback_path", "")).strip_edges()
		if not fallback_path.is_empty():
			overrides = _load_json_path(fallback_path)

	var resolved := apply_overrides(app_config, overrides)
	runtime_config_loaded.emit(resolved.duplicate(true))
	return resolved

func apply_overrides(app_config: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := app_config.duplicate(true)
	if overrides.is_empty():
		return result

	if typeof(overrides.get("network", {})) == TYPE_DICTIONARY:
		var network: Dictionary = result.get("network", {}) as Dictionary
		network = network.duplicate(true)
		var incoming: Dictionary = overrides.get("network", {}) as Dictionary
		for key in ALLOWED_NETWORK_KEYS:
			if incoming.has(key):
				network[key] = incoming[key]
		result["network"] = network

	if typeof(overrides.get("feature_flags", {})) == TYPE_DICTIONARY:
		var flags: Dictionary = result.get("feature_flags", {}) as Dictionary
		flags = flags.duplicate(true)
		var incoming_flags: Dictionary = overrides.get("feature_flags", {}) as Dictionary
		for key in incoming_flags.keys():
			if typeof(incoming_flags[key]) == TYPE_BOOL:
				flags[key] = incoming_flags[key]
		result["feature_flags"] = flags

	for key in ALLOWED_TOP_LEVEL_KEYS:
		if overrides.has(key):
			result[key] = overrides[key]
	return result

func _fetch_json(url: String, timeout_seconds: float) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = timeout_seconds
	add_child(request)
	var error_code := request.request(url, PackedStringArray(["Accept: application/json"]))
	if error_code != OK:
		request.queue_free()
		return {"ok": false, "error": "request_start_failed"}

	var completed: Array = await request.request_completed
	request.queue_free()
	var result_code := int(completed[0])
	var response_code := int(completed[1])
	if result_code != OK or response_code < 200 or response_code >= 300:
		return {"ok": false, "error": "http_%d" % response_code}

	var parsed: Variant = JSON.parse_string((completed[3] as PackedByteArray).get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json"}
	return {"ok": true, "data": parsed as Dictionary}

func _load_json_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		runtime_config_failed.emit("missing_fallback")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		runtime_config_failed.emit("invalid_fallback_json")
		return {}
	return parsed as Dictionary

func _normalize_url(url: String) -> String:
	if url.begins_with("http://") or url.begins_with("https://"):
		return url
	if url.begins_with("/"):
		var origin := _get_web_origin()
		if not origin.is_empty():
			return origin.trim_suffix("/") + url
		if _can_try_relative_web_url():
			return url
	return ""

func _get_web_origin() -> String:
	if OS.get_name() != "Web":
		return ""
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var origin: Variant = JavaScriptBridge.eval("window.location.origin", true)
	if typeof(origin) == TYPE_STRING:
		return str(origin)
	return ""

func _can_try_relative_web_url() -> bool:
	return OS.get_name() == "Web"
