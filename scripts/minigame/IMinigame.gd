class_name IMinigame
extends Node

signal ended(result: Dictionary)
signal emote_requested(player_id: String, emote_id: String)

func get_game_id() -> String:
	return ""

func get_game_name() -> Dictionary:
	return {
		"en": "",
		"ja": "",
		"zh": ""
	}

func get_version() -> String:
	return "1.0.0"

func get_author() -> String:
	return ""

func get_game_mode_id() -> String:
	return "casual_activity"

func get_runtime_contract() -> Dictionary:
	return {
		"camera": "contained",
		"input_profile": "tap_timing",
		"network_profile": "offline_optional"
	}

func on_start(_context: Dictionary) -> void:
	pass

func on_end() -> Dictionary:
	return {}

func on_pause() -> void:
	pass

func on_resume() -> void:
	pass

func on_player_join(_player_id: String) -> void:
	pass

func on_player_leave(_player_id: String) -> void:
	pass

func on_sync_state() -> Dictionary:
	return {}

func request_emote(player_id: String, emote_id: String) -> void:
	emote_requested.emit(player_id, emote_id)
