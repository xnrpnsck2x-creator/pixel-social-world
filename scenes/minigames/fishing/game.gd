extends "res://scripts/minigame/IMinigame.gd"

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PANEL_MAX_WIDTH := 760.0
const PANEL_COMPACT_MAX_WIDTH := 600.0

var context: Dictionary = {}
var fish_records: Array = []
var rarity_records: Dictionary = {}
var bite_timing: Dictionary = {}
var total_coins := 0
var total_catches := 0
var rng := RandomNumberGenerator.new()
var _last_catch_name_key := ""
var _last_catch_rarity := ""
var _last_catch_coins := 0

@onready var title_label: Label = %TitleLabel
@onready var root_margin: MarginContainer = $RootMargin
@onready var layout_box: VBoxContainer = $RootMargin/Layout
@onready var pond_panel: PanelContainer = %PondPanel
@onready var pond_margin: MarginContainer = $RootMargin/Layout/PondPanel/PondMargin
@onready var pond_rows: VBoxContainer = $RootMargin/Layout/PondPanel/PondMargin/PondRows
@onready var status_label: Label = %StatusLabel
@onready var reward_label: Label = %RewardLabel
@onready var reward_panel: PanelContainer = %RewardPanel
@onready var cast_button: Button = %CastButton
@onready var end_button: Button = %EndButton

func _ready() -> void:
	rng.randomize()
	cast_button.pressed.connect(_catch_fish)
	end_button.pressed.connect(_finish_game)
	reward_panel.connect("cast_again_requested", _catch_fish)
	App.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_apply_layout_density)
	_apply_image2_style()
	_apply_layout_density()
	_load_fish()
	_refresh_text()

func get_game_id() -> String:
	return "fishing"

func get_game_name() -> Dictionary:
	return {
		"en": "Fishing",
		"ja": "釣り",
		"zh": "钓鱼"
	}

func get_version() -> String:
	return "1.0.0"

func get_author() -> String:
	return "official"

func get_runtime_contract() -> Dictionary:
	return {
		"camera": "contained",
		"input_profile": "tap_timing",
		"network_profile": "offline_optional",
		"supports_emotes": true
	}

func on_start(new_context: Dictionary) -> void:
	context = new_context
	_load_fish()
	_refresh_text()

func on_end() -> Dictionary:
	return {
		"score": total_coins,
		"rewards": {"coin": total_coins},
		"stats": {
			"catches": total_catches,
			"game_id": get_game_id()
		}
	}

func on_pause() -> void:
	cast_button.disabled = true
	reward_panel.call("set_busy", true)

func on_resume() -> void:
	cast_button.disabled = false
	reward_panel.call("set_busy", false)

func on_sync_state() -> Dictionary:
	return {
		"total_coins": total_coins,
		"total_catches": total_catches
	}

func _load_fish() -> void:
	var config: Dictionary = ConfigLoader.load_config("fishing")
	fish_records = config.get("fish", [])
	bite_timing = config.get("bite_timing", {})
	rarity_records.clear()
	for record in config.get("rarities", []):
		if typeof(record) == TYPE_DICTIONARY and record.has("id"):
			rarity_records[str(record.get("id", ""))] = record

func _catch_fish() -> void:
	if cast_button.disabled:
		return
	if fish_records.is_empty():
		status_label.text = App.t_key("fishing.no_fish")
		return

	cast_button.disabled = true
	reward_panel.call("set_busy", true)
	reward_panel.call("hide_reward")
	await _run_bite_timing()
	if _should_claim_online():
		var response: Dictionary = await _online_client().call("claim_fishing_catch", _session_id(), _catch_request_id())
		if bool(response.get("ok", false)):
			_apply_server_catch(response.get("data", {}) as Dictionary)
		else:
			status_label.text = App.t_key("fishing.reward_failed")
		cast_button.disabled = false
		reward_panel.call("set_busy", false)
		return

	var fish: Dictionary = _pick_fish()
	_apply_local_catch(fish)
	cast_button.disabled = false
	reward_panel.call("set_busy", false)

func _finish_game() -> void:
	ended.emit(on_end())

func _apply_server_catch(data: Dictionary) -> void:
	var coins := int(data.get("reward_coin", 0))
	var name_key := str(data.get("fish_name_key", ""))
	var rarity := str(data.get("rarity", ""))
	if rarity.is_empty():
		rarity = _fish_rarity_id(name_key)
	total_coins += coins
	total_catches += 1
	if data.has("balance"):
		SaveSystem.sync_coin_balance(int(data.get("balance", SaveSystem.get_coin_balance())), "server.fishing")
	_show_catch(name_key, rarity, coins)

func _apply_local_catch(fish: Dictionary) -> void:
	var coins := int(fish.get("sell_value", 0))
	total_coins += coins
	total_catches += 1
	SaveSystem.grant_coins(coins, "local.fishing")
	_show_catch(str(fish.get("name_key", "")), str(fish.get("rarity", "")), coins)

func _show_catch(name_key: String, rarity_id: String, coins: int) -> void:
	var fish_name: String = App.t_key(name_key)
	_last_catch_name_key = name_key
	_last_catch_rarity = rarity_id
	_last_catch_coins = coins
	status_label.text = App.format_key("fishing.catch_result_format", {
		"fish": fish_name,
		"coins": coins
	})
	reward_panel.call(
		"show_reward",
		name_key,
		coins,
		_fish_icon_path(name_key),
		_rarity_name_key(rarity_id),
		_rarity_color(rarity_id)
	)
	request_emote(SaveSystem.get_player_id(), "emote.fishing_bite")
	_refresh_reward()

func _run_bite_timing() -> void:
	status_label.text = App.t_key("fishing.casting")
	await _wait_seconds(_timing_value("cast_delay_seconds", 0.35))
	status_label.text = App.t_key("fishing.waiting_bite")
	await _wait_seconds(_timing_value("bite_delay_seconds", 0.55))
	status_label.text = App.t_key("fishing.bite")
	await _wait_seconds(_timing_value("reel_delay_seconds", 0.35))
	status_label.text = App.t_key("fishing.reeling")

func _pick_fish() -> Dictionary:
	var total_weight := 0
	for record in fish_records:
		if typeof(record) == TYPE_DICTIONARY:
			total_weight += max(1, int(record.get("weight", 1)))

	var roll: int = rng.randi_range(1, max(1, total_weight))
	var cursor := 0
	for record in fish_records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var fish: Dictionary = record as Dictionary
		cursor += max(1, int(fish.get("weight", 1)))
		if roll <= cursor:
			return fish

	return fish_records.front() as Dictionary

func _should_claim_online() -> bool:
	var client := _online_client()
	return client != null \
		and not _session_id().begins_with("local") \
		and bool(client.get("online_enabled")) \
		and not str(client.get("access_token")).is_empty()

func _online_client() -> Node:
	var client: Variant = context.get("online_client", null)
	if client is Node:
		return client as Node
	return null

func _session_id() -> String:
	return str(context.get("session_id", "local"))

func _catch_request_id() -> String:
	return "%s-%s-%d" % [SaveSystem.get_player_id(), _session_id(), Time.get_ticks_usec()]

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	title_label.text = App.t_key("minigame.fishing.name")
	if _last_catch_name_key.is_empty():
		status_label.text = App.t_key("fishing.ready")
	else:
		status_label.text = App.format_key("fishing.catch_result_format", {
			"fish": App.t_key(_last_catch_name_key),
			"coins": _last_catch_coins
		})
	cast_button.text = App.t_key("fishing.cast_button")
	end_button.text = App.t_key("fishing.end_button")
	_refresh_reward()

func _refresh_reward() -> void:
	reward_label.text = App.format_key("fishing.total_format", {
		"catches": total_catches,
		"coins": total_coins
	})

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(pond_panel)
	WorldHUDAssetsScript.configure_button_frame(cast_button)
	WorldHUDAssetsScript.configure_button_frame(end_button)
	status_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1.0))
	reward_label.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 1.0))

func _apply_layout_density(force_compact: Variant = null) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact: bool = bool(force_compact) if force_compact != null else viewport_size.y <= 430.0
	var side_margin := 10.0 if compact else 24.0
	root_margin.offset_left = side_margin
	root_margin.offset_top = 10.0 if compact else 16.0
	root_margin.offset_right = -side_margin
	root_margin.offset_bottom = -side_margin
	layout_box.add_theme_constant_override("separation", 6 if compact else 8)
	pond_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pond_panel.custom_minimum_size.x = minf(viewport_size.x - side_margin * 2.0, PANEL_COMPACT_MAX_WIDTH if compact else PANEL_MAX_WIDTH)
	var inner_margin := 8 if compact else 12
	pond_margin.add_theme_constant_override("margin_left", inner_margin)
	pond_margin.add_theme_constant_override("margin_top", inner_margin)
	pond_margin.add_theme_constant_override("margin_right", inner_margin)
	pond_margin.add_theme_constant_override("margin_bottom", inner_margin)
	pond_rows.add_theme_constant_override("separation", 5 if compact else 6)
	var button_height := 32.0 if compact else 36.0
	cast_button.custom_minimum_size.y = button_height
	end_button.custom_minimum_size.y = button_height
	reward_panel.call("set_compact_layout", compact)

func _fish_icon_path(name_key: String) -> String:
	for record in fish_records:
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("name_key", "")) == name_key:
			return str((record as Dictionary).get("icon_path", ""))
	return ""

func _fish_rarity_id(name_key: String) -> String:
	for record in fish_records:
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("name_key", "")) == name_key:
			return str((record as Dictionary).get("rarity", "common"))
	return "common"

func _rarity_name_key(rarity_id: String) -> String:
	var rarity: Dictionary = rarity_records.get(rarity_id, {})
	return str(rarity.get("name_key", "fishing.rarity.common"))

func _rarity_color(rarity_id: String) -> Color:
	var rarity: Dictionary = rarity_records.get(rarity_id, {})
	return Color.from_string(str(rarity.get("color", "#d8caa7")), Color(0.85, 0.79, 0.65))

func _timing_value(key: String, fallback: float) -> float:
	return maxf(0.0, float(bite_timing.get(key, fallback)))

func _wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
