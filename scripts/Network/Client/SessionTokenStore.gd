extends Node

const DEFAULT_WEB_KEY := "pixel_social_world.session.v1"

func load_session() -> Dictionary:
	var web_session := _load_web_session()
	if not web_session.is_empty():
		_save_system_session(web_session)
		return web_session
	return _load_save_system_session()

func save_session(session: Dictionary) -> void:
	_save_system_session(session)
	_save_web_session(session)

func clear_session() -> void:
	for key in ["access_token", "refresh_token", "session_id"]:
		SaveSystem.set_profile_value(key, "")
	SaveSystem.save_profile()
	if _web_available():
		_javascript_bridge().eval(
			"window.localStorage.removeItem(%s)" % JSON.stringify(_web_storage_key()),
			true
		)

func get_access_token(fallback: String = "") -> String:
	var session := load_session()
	return str(session.get("access_token", fallback))

func get_refresh_token(fallback: String = "") -> String:
	var session := load_session()
	return str(session.get("refresh_token", fallback))

func _load_save_system_session() -> Dictionary:
	return {
		"player_id": SaveSystem.get_player_id(),
		"session_id": str(SaveSystem.get_profile_value("session_id", "")),
		"access_token": str(SaveSystem.get_profile_value("access_token", "")),
		"refresh_token": str(SaveSystem.get_profile_value("refresh_token", ""))
	}

func _save_system_session(session: Dictionary) -> void:
	SaveSystem.set_profile_value("id", str(session.get("player_id", SaveSystem.get_player_id())))
	SaveSystem.set_profile_value("session_id", str(session.get("session_id", "")))
	SaveSystem.set_profile_value("access_token", str(session.get("access_token", "")))
	SaveSystem.set_profile_value("refresh_token", str(session.get("refresh_token", "")))
	SaveSystem.set_profile_value("network_mode", "online")
	SaveSystem.save_profile()

func _load_web_session() -> Dictionary:
	if not _web_available():
		return {}
	var raw: Variant = _javascript_bridge().eval(
		"window.localStorage.getItem(%s)" % JSON.stringify(_web_storage_key()),
		true
	)
	if raw == null or str(raw).is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(str(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _save_web_session(session: Dictionary) -> void:
	if not _web_available():
		return
	var payload := JSON.stringify(session)
	_javascript_bridge().eval(
		"window.localStorage.setItem(%s, %s)" % [
			JSON.stringify(_web_storage_key()),
			JSON.stringify(payload)
		],
		true
	)

func _web_storage_key() -> String:
	return str(ConfigLoader.get_value("app", ["network", "web_session_storage_key"], DEFAULT_WEB_KEY))

func _web_available() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

func _javascript_bridge() -> Object:
	return Engine.get_singleton("JavaScriptBridge")
