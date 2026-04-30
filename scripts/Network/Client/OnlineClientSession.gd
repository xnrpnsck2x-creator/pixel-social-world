class_name OnlineClientSession
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func guest_login(display_name: String) -> Dictionary:
	_client.configure()
	var payload := {
		"device_id": _device_id(),
		"display_name": display_name
	}
	if bool(_client.get("online_enabled")):
		var response: Dictionary = await _client._request_json(HTTPClient.METHOD_POST, "/auth/guest", payload)
		if bool(response.get("ok", false)):
			_apply_session(response.get("data", {}) as Dictionary)
			return response

	if bool(_client.get("offline_fallback_enabled")):
		_client._mark_disconnected()
		_client.set("player_id", "offline-player")
		return {
			"ok": true,
			"offline": true,
			"route": "/auth/guest",
			"data": {
				"player_id": _client.get("player_id"),
				"display_name": display_name
			}
		}
	return _client._error("offline_disabled", "/auth/guest")

func refresh_session() -> Dictionary:
	var saved_token := SessionTokenStore.get_refresh_token(str(_client.get("refresh_token")))
	if str(_client.get("player_id")).is_empty() or saved_token.is_empty():
		return _client._error("missing_refresh_token", "/auth/refresh")
	var response: Dictionary = await _client._request_json(HTTPClient.METHOD_POST, "/auth/refresh", {
		"player_id": _client.get("player_id"),
		"refresh_token": saved_token
	}, false)
	if bool(response.get("ok", false)):
		_apply_session(response.get("data", {}) as Dictionary)
	return response

func upgrade_guest_account(request: Dictionary) -> Dictionary:
	_client.configure()
	var payload := request.duplicate(true)
	payload["player_id"] = str(payload.get("player_id", _client.get("player_id")))
	if str(payload.get("platform", "")).is_empty():
		payload["platform"] = _auth_platform()
	if not bool(_client.get("online_enabled")):
		return _client._error("online_disabled", "/auth/upgrade")
	var response: Dictionary = await _client._request_json(HTTPClient.METHOD_POST, "/auth/upgrade", payload)
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		_apply_session(data.get("session", {}) as Dictionary)
		var linked_account: Dictionary = data.get("linked_account", {}) as Dictionary
		if not linked_account.is_empty():
			_save_system().call("set_profile_value", "linked_account", linked_account)
			_save_system().call("save_profile")
	return response

func fetch_profile() -> Dictionary:
	var player_id := str(_client.get("player_id"))
	var response: Dictionary = await _client._request_json(HTTPClient.METHOD_GET, "/me?player_id=%s" % player_id.uri_encode())
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		var wallet: Dictionary = data.get("wallet", {}) as Dictionary
		if wallet.has("coin"):
			_save_system().call("sync_coin_balance", int(wallet.get("coin", 0)), "server.profile")
	return response

func restore_session() -> void:
	var session := SessionTokenStore.load_session()
	_client.set("player_id", str(session.get("player_id", _client.get("player_id"))))
	_client.set("access_token", str(session.get("access_token", _client.get("access_token"))))
	_client.set("refresh_token", str(session.get("refresh_token", _client.get("refresh_token"))))

func _apply_session(session: Dictionary) -> void:
	_client.set("player_id", str(session.get("player_id", _client.get("player_id"))))
	_client.set("access_token", str(session.get("access_token", _client.get("access_token"))))
	_client.set("refresh_token", str(session.get("refresh_token", _client.get("refresh_token"))))
	SessionTokenStore.save_session(session)
	_client._mark_connected()

func _device_id() -> String:
	var existing := str(_save_system().call("get_profile_value", "device_id", ""))
	if not existing.is_empty():
		return existing
	var platform_id := "web" if OS.get_name() == "Web" else OS.get_unique_id()
	if platform_id.is_empty():
		platform_id = "device"
	var generated := "%s-%d" % [platform_id, int(Time.get_unix_time_from_system())]
	_save_system().call("set_profile_value", "device_id", generated)
	_save_system().call("save_profile")
	return generated

func _auth_platform() -> String:
	if OS.has_feature("web") or OS.get_name() == "Web":
		return "h5"
	if OS.get_name() == "iOS":
		return "ios"
	if OS.get_name() == "Android":
		return "android"
	return "desktop"

func _save_system() -> Node:
	return _client.get_node("/root/SaveSystem")
