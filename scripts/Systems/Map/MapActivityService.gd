class_name MapActivityService
extends Node

signal activity_completed(result: Dictionary)
signal activity_state_changed(action_id: String, state: Dictionary)

const COOLDOWN_PROFILE_KEY := "map_activity_cooldowns"
const DAILY_PROFILE_KEY := "map_activity_daily_claims"
const MapActivityProgressScript := preload("res://scripts/Systems/Map/MapActivityProgress.gd")
const MapActivityRewardTextScript := preload("res://scripts/Systems/Map/MapActivityRewardText.gd")

var current_map_id := "city_forest_dawn_v1"
var metadata
var chat_service: Node
var hud: Node
var _config: Dictionary = {}
var _actions: Dictionary = {}

func _ready() -> void:
	initialize()

func initialize() -> void:
	if not _actions.is_empty():
		return
	_config = ConfigLoader.load_config("map_activities")
	_actions = _config.get("actions", {}) as Dictionary

func bind(new_chat_service: Node, new_hud: Node) -> void:
	chat_service = new_chat_service
	hud = new_hud

func set_context(map_id: String, new_metadata = null) -> void:
	current_map_id = map_id if not map_id.is_empty() else current_map_id
	metadata = new_metadata

func action_ids() -> Array:
	initialize()
	return _actions.keys()

func has_action(action_id: String) -> bool:
	initialize()
	return _actions.has(action_id)

func cooldown_remaining(action_id: String) -> int:
	return _cooldown_remaining(action_id)

func activity_state(action_id: String) -> Dictionary:
	initialize()
	if not _actions.has(action_id):
		return {"state": "disabled", "seconds": 0}
	var record := _action_record(action_id)
	if _daily_limit_reached(action_id, record):
		return {"state": "disabled", "seconds": 0}
	var remaining := _cooldown_remaining(action_id)
	if remaining > 0:
		return {"state": "cooldown", "seconds": remaining}
	return {"state": "ready", "seconds": 0}

func perform_activity(action_id: String) -> Dictionary:
	initialize()
	var record := _action_record(action_id)
	if record.is_empty():
		_add_feedback(App.t_key("map_activity.unknown"))
		_emit_activity_state(action_id)
		return _result(false, action_id, 0, "unknown")
	if _can_claim_online():
		var online := await _claim_online(action_id, record)
		if bool(online.get("handled", false)):
			return online.get("result", {}) as Dictionary
	return _claim_local(action_id, record)

func _claim_local(action_id: String, record: Dictionary) -> Dictionary:
	if _daily_limit_reached(action_id, record):
		_add_feedback(App.t_key("map_activity.daily_limit"))
		_emit_activity_state(action_id)
		return _result(false, action_id, 0, "daily_limit")
	var remaining := _cooldown_remaining(action_id)
	if remaining > 0:
		_add_feedback(App.format_key("map_activity.cooldown", {"seconds": remaining}))
		_emit_activity_state(action_id)
		return _result(false, action_id, 0, "cooldown")
	var reward := int(record.get("reward_coins", 0))
	if reward > 0:
		SaveSystem.grant_coins(reward, _source_id(record, action_id))
		_increment_daily_claim(action_id, record)
	_set_cooldown(action_id, int(record.get("cooldown_seconds", _default_cooldown())))
	SaveSystem.save_profile()
	_refresh_hud_coin()
	var result := _result(true, action_id, reward, "")
	_apply_local_gameplay_rewards(result, record)
	_add_success_feedback(record, result)
	activity_completed.emit(result)
	_emit_activity_state(action_id)
	return result

func _claim_online(action_id: String, record: Dictionary) -> Dictionary:
	var response: Dictionary = await _online_client().call("claim_map_activity", current_map_id, action_id)
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		var result := _apply_server_claim(action_id, record, data)
		return {"handled": true, "result": result}
	if int(response.get("status", 0)) <= 0:
		return {"handled": false, "result": {}}
	var data: Dictionary = response.get("data", {}) as Dictionary
	var error_code := str(response.get("error", data.get("error", "network")))
	if error_code == "activity_cooldown":
		var ready_at := int(data.get("ready_at", 0))
		if ready_at > 0:
			_set_ready_at(action_id, ready_at)
			SaveSystem.save_profile()
		var remaining := int(data.get("ready_in_seconds", _cooldown_remaining(action_id)))
		_add_feedback(App.format_key("map_activity.cooldown", {"seconds": max(1, remaining)}))
		_emit_activity_state(action_id)
		return {"handled": true, "result": _result(false, action_id, 0, "cooldown")}
	if error_code == "activity_daily_limit":
		_record_daily_claim_from_server(action_id, data, record)
		SaveSystem.save_profile()
		_add_feedback(App.t_key("map_activity.daily_limit"))
		_emit_activity_state(action_id)
		return {"handled": true, "result": _result(false, action_id, 0, "daily_limit")}
	if error_code == "unknown_activity" or error_code == "activity_not_on_map":
		_add_feedback(App.t_key("map_activity.unknown"))
		_emit_activity_state(action_id)
		return {"handled": true, "result": _result(false, action_id, 0, "unknown")}
	_add_feedback(App.t_key("error.network"))
	_emit_activity_state(action_id)
	return {"handled": true, "result": _result(false, action_id, 0, error_code)}

func _apply_server_claim(action_id: String, record: Dictionary, data: Dictionary) -> Dictionary:
	var wallet: Dictionary = data.get("wallet", {}) as Dictionary
	var reward := int(data.get("reward_coins", int(wallet.get("delta", 0))))
	if wallet.has("balance"):
		SaveSystem.sync_coin_balance(int(wallet.get("balance", SaveSystem.get_coin_balance())), "server.map_activity")
	var ready_at := int(data.get("ready_at", 0))
	if ready_at > 0:
		_set_ready_at(action_id, ready_at)
	_record_daily_claim_from_server(action_id, data, record)
	SaveSystem.save_profile()
	_refresh_hud_coin()
	var result := _result(true, action_id, reward, "")
	_apply_server_gameplay_rewards(result, data)
	_add_success_feedback(record, result)
	activity_completed.emit(result)
	_emit_activity_state(action_id)
	return result

func _action_record(action_id: String) -> Dictionary:
	if _actions.has(action_id) and typeof(_actions[action_id]) == TYPE_DICTIONARY:
		return _actions[action_id] as Dictionary
	return {}

func _source_id(record: Dictionary, action_id: String) -> String:
	return "%s.%s.%s" % [
		str(record.get("source_id", "map_activity")),
		current_map_id,
		action_id
	]

func _cooldown_remaining(action_id: String) -> int:
	var ready_at := int(_cooldowns().get(_cooldown_key(action_id), 0))
	return max(0, ready_at - int(Time.get_unix_time_from_system()))

func _set_cooldown(action_id: String, seconds: int) -> void:
	_cooldowns()[_cooldown_key(action_id)] = int(Time.get_unix_time_from_system()) + max(0, seconds)

func _set_ready_at(action_id: String, ready_at: int) -> void:
	_cooldowns()[_cooldown_key(action_id)] = max(0, ready_at)

func _cooldowns() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(COOLDOWN_PROFILE_KEY, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	var empty := {}
	SaveSystem.set_profile_value(COOLDOWN_PROFILE_KEY, empty)
	return empty

func _daily_claims() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(DAILY_PROFILE_KEY, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	var empty := {}
	SaveSystem.set_profile_value(DAILY_PROFILE_KEY, empty)
	return empty

func _cooldown_key(action_id: String) -> String:
	return "%s:%s" % [current_map_id, action_id]

func _daily_claim_key(action_id: String) -> String:
	return "%s:%s" % [_date_key(), action_id]

func _date_key() -> String:
	var date := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]

func _daily_limit(record: Dictionary) -> int:
	if int(record.get("reward_coins", 0)) <= 0:
		return 0
	var fallback := int(_config.get("default_daily_reward_limit", 0))
	return max(0, int(record.get("daily_reward_limit", fallback)))

func _daily_claim_count(action_id: String) -> int:
	return int(_daily_claims().get(_daily_claim_key(action_id), 0))

func _daily_limit_reached(action_id: String, record: Dictionary) -> bool:
	var limit := _daily_limit(record)
	return limit > 0 and _daily_claim_count(action_id) >= limit

func _increment_daily_claim(action_id: String, record: Dictionary) -> void:
	var limit := _daily_limit(record)
	if limit <= 0:
		return
	var key := _daily_claim_key(action_id)
	_daily_claims()[key] = min(limit, _daily_claim_count(action_id) + 1)

func _record_daily_claim_from_server(action_id: String, data: Dictionary, record: Dictionary) -> void:
	var limit := int(data.get("daily_reward_limit", _daily_limit(record)))
	if limit <= 0:
		return
	var count := int(data.get("daily_reward_count", 0))
	if count <= 0 and bool(data.get("claimed", false)):
		count = _daily_claim_count(action_id) + 1
	if count <= 0 and str(data.get("error", "")) == "activity_daily_limit":
		count = limit
	_daily_claims()[_daily_claim_key(action_id)] = min(limit, max(0, count))

func _default_cooldown() -> int:
	return int(_config.get("default_cooldown_seconds", 45))

func _apply_local_gameplay_rewards(result: Dictionary, record: Dictionary) -> void:
	result["skill_id"] = str(record.get("skill_id", ""))
	result["skill_xp"] = int(record.get("skill_xp", 0))
	var drops: Array = record.get("drops", []) as Array
	result["drops"] = drops.duplicate(true)
	MapActivityProgressScript.apply_result(result)

func _apply_server_gameplay_rewards(result: Dictionary, data: Dictionary) -> void:
	result["skill_id"] = str(data.get("skill_id", ""))
	result["skill_xp"] = int(data.get("skill_xp", 0))
	var drops: Array = data.get("drops", []) as Array
	result["drops"] = drops.duplicate(true)
	if data.has("rare_event"):
		result["rare_event"] = data.get("rare_event")
	MapActivityProgressScript.apply_result(result)
	var drop_ids := []
	for drop in drops:
		if typeof(drop) == TYPE_DICTIONARY:
			drop_ids.append(str((drop as Dictionary).get("item_id", "")))
	var inventory_items: Array = data.get("inventory_items", []) as Array
	MapActivityProgressScript.sync_inventory_items(inventory_items, drop_ids)

func _can_claim_online() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("online_enabled")) and not str(client.get("access_token")).is_empty() and client.has_method("claim_map_activity")

func _online_client() -> Node:
	if has_node("/root/OnlineClient"):
		return get_node("/root/OnlineClient")
	return null

func _refresh_hud_coin() -> void:
	if hud != null and hud.has_method("refresh_coin"):
		hud.call("refresh_coin")

func _add_feedback(body: String) -> void:
	_add_system_text(body)
	if hud != null and hud.has_method("show_status_message"):
		hud.call("show_status_message", body)

func _add_success_feedback(record: Dictionary, result: Dictionary) -> void:
	var base := App.format_key(str(record.get("success_key", "map_activity.generic.success")), {
		"coins": int(result.get("reward_coins", 0))
	})
	_add_feedback(MapActivityRewardTextScript.success_message(base, result))

func _emit_activity_state(action_id: String) -> void:
	activity_state_changed.emit(action_id, activity_state(action_id))

func _add_system_text(body: String) -> void:
	if chat_service != null:
		chat_service.add_system_message(App.t_key("chat.system.name"), body)

func _result(ok: bool, action_id: String, reward: int, error: String) -> Dictionary:
	return {
		"ok": ok,
		"map_id": current_map_id,
		"action_id": action_id,
		"reward_coins": reward,
		"error": error
	}
