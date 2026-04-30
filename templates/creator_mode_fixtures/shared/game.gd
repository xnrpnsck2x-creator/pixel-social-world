extends "res://scripts/minigame/IMinigame.gd"

var _context := {}
var _score := 0

func get_game_id() -> String:
	return "creator_mode_fixture"

func get_game_name() -> Dictionary:
	return {
		"en": "Creator Mode Fixture",
		"ja": "Creator Mode Fixture",
		"zh": "Creator Mode Fixture"
	}

func get_version() -> String:
	return "0.1.0"

func get_author() -> String:
	return "internal_fixture"

func on_start(context: Dictionary) -> void:
	_context = context
	_score = 1

func on_end() -> Dictionary:
	return {
		"score": _score,
		"rewards": {"coin": 0},
		"stats": {"fixture": true}
	}

func on_pause() -> void:
	pass

func on_resume() -> void:
	pass
