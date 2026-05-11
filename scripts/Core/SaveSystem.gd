extends Node

const SAVE_PATH := "user://player_profile.json"

var profile: Dictionary = {}

func load_profile() -> Dictionary:
	if FileAccess.file_exists(SAVE_PATH):
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			profile = parsed as Dictionary
			_apply_defaults()
			return profile

	profile = _default_profile()
	_apply_defaults()
	save_profile()
	return profile

func save_profile() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write save file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(profile, "\t"))

func get_locale() -> String:
	return str(profile.get("locale", "en"))

func set_locale(locale: String) -> void:
	profile["locale"] = locale
	save_profile()

func get_display_name() -> String:
	return str(profile.get("display_name", ""))

func get_player_id() -> String:
	return str(profile.get("id", "offline-player"))

func get_coin_balance() -> int:
	return int(profile.get("coin_balance", 0))

func grant_coins(amount: int, source_id: String = "local_reward") -> void:
	if amount <= 0:
		return
	profile["coin_balance"] = get_coin_balance() + amount
	_append_coin_event("grant", source_id, amount)
	save_profile()

func spend_coins(amount: int, source_id: String = "local_spend") -> bool:
	if amount <= 0:
		return true
	if get_coin_balance() < amount:
		return false
	profile["coin_balance"] = get_coin_balance() - amount
	_append_coin_event("spend", source_id, -amount)
	save_profile()
	return true

func sync_coin_balance(balance: int, source_id: String = "server_wallet") -> void:
	var delta := balance - get_coin_balance()
	if delta == 0:
		return
	profile["coin_balance"] = balance
	_append_coin_event("server.sync", source_id, delta)
	save_profile()

func get_coin_ledger() -> Array:
	var ledger: Variant = profile.get("coin_ledger", [])
	if typeof(ledger) == TYPE_ARRAY:
		return (ledger as Array).duplicate(true)
	return []

func validate_coin_ledger() -> bool:
	var ledger := get_coin_ledger()
	var running_balance := 0
	var previous_checksum := ""
	for event in ledger:
		if typeof(event) != TYPE_DICTIONARY:
			return false
		var event_dict: Dictionary = event as Dictionary
		if str(event_dict.get("previous_checksum", "")) != previous_checksum:
			return false
		if str(event_dict.get("checksum", "")) != _coin_event_checksum(event_dict):
			return false
		running_balance += int(event_dict.get("delta", 0))
		if running_balance != int(event_dict.get("balance_after", 0)):
			return false
		previous_checksum = str(event_dict.get("checksum", ""))
	return running_balance == get_coin_balance()

func set_profile_value(key: String, value: Variant) -> void:
	profile[key] = value

func get_profile_value(key: String, fallback: Variant = null) -> Variant:
	return profile.get(key, fallback)

func _default_profile() -> Dictionary:
	return {
		"id": "offline-player",
		"device_id": "",
		"network_mode": "offline",
		"display_name": "",
		"gender_id": "male",
		"class_id": "melee",
		"avatar_id": "male_melee_v1",
		"character_variant_id": "male_melee_v0",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"map_activity_cooldowns": {},
		"map_activity_daily_claims": {},
		"map_activity_inventory": {},
		"map_activity_skill_xp": {},
		"current_route": "login",
		"current_world_map_id": "city_forest_dawn_v1",
		"discovered_world_map_ids": ["city_forest_dawn_v1"],
		"discovered_world_map_records": [{"map_id": "city_forest_dawn_v1", "source": "default", "discovered_at": 0}],
		"current_room_id": "world_town_square",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	}

func _apply_defaults() -> void:
	var defaults: Dictionary = _default_profile()
	for key in defaults.keys():
		if not profile.has(key):
			profile[key] = defaults[key]
	_ensure_coin_ledger()

func _ensure_coin_ledger() -> void:
	if typeof(profile.get("coin_ledger", [])) != TYPE_ARRAY:
		profile["coin_ledger"] = []
	if (profile["coin_ledger"] as Array).is_empty() and get_coin_balance() > 0:
		_append_coin_event("system.init", "profile_init", get_coin_balance())

func _append_coin_event(event_type: String, source_id: String, delta: int) -> void:
	var ledger: Array = profile.get("coin_ledger", [])
	var previous_checksum := ""
	if not ledger.is_empty():
		previous_checksum = str((ledger.back() as Dictionary).get("checksum", ""))
	var event := {
		"id": "%s-%d-%d" % [event_type, Time.get_ticks_usec(), ledger.size()],
		"type": event_type,
		"source_id": source_id,
		"delta": delta,
		"balance_after": get_coin_balance(),
		"created_at": int(Time.get_unix_time_from_system()),
		"previous_checksum": previous_checksum
	}
	event["checksum"] = _coin_event_checksum(event)
	ledger.append(event)
	profile["coin_ledger"] = ledger

func _coin_event_checksum(event: Dictionary) -> String:
	var payload := event.duplicate(true)
	payload.erase("checksum")
	return JSON.stringify(payload).sha256_text()
