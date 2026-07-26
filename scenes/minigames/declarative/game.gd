extends "res://scripts/minigame/IMinigame.gd"

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var context: Dictionary = {}
var runtime: Dictionary = {}
var definition: Dictionary = {}
var score := 0
var target_score := 12
var remaining_seconds := 60
var running := false

@onready var title_label: Label = %TitleLabel
@onready var mode_label: Label = %ModeLabel
@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var status_label: Label = %StatusLabel
@onready var action_button: Button = %ActionButton
@onready var finish_button: Button = %FinishButton
@onready var game_panel: PanelContainer = %GamePanel
@onready var timer: Timer = %RoundTimer

func _ready() -> void:
	action_button.pressed.connect(_perform_action)
	finish_button.pressed.connect(_finish)
	timer.timeout.connect(_on_tick)
	App.locale_changed.connect(_on_locale_changed)
	_apply_style()
	_refresh_text()

func get_game_id() -> String:
	return str(runtime.get("id", definition.get("game_id", "")))

func get_game_name() -> Dictionary:
	return (runtime.get("name", {}) as Dictionary).duplicate(true)

func get_version() -> String:
	return str(runtime.get("version", "1.0.0"))

func get_author() -> String:
	return str(runtime.get("author", "creator"))

func get_game_mode_id() -> String:
	return str(runtime.get("mode_id", definition.get("mode_id", "casual_activity")))

func get_runtime_contract() -> Dictionary:
	return (runtime.get("runtime_contract", {}) as Dictionary).duplicate(true)

func on_start(new_context: Dictionary) -> void:
	context = new_context.duplicate(true)
	runtime = (context.get("settings", {}) as Dictionary).duplicate(true)
	definition = (runtime.get("runtime_definition", {}) as Dictionary).duplicate(true)
	var settings := definition.get("settings", {}) as Dictionary
	target_score = clampi(int(settings.get("target_score", 12)), 1, 999)
	remaining_seconds = clampi(int(settings.get("duration_seconds", 60)), 10, 600)
	score = 0
	running = true
	timer.start()
	_refresh_text()

func on_end() -> Dictionary:
	return {
		"score": score,
		"rewards": {},
		"stats": {
			"game_id": get_game_id(),
			"mode_id": get_game_mode_id(),
			"target_score": target_score,
			"completed": score >= target_score
		}
	}

func on_pause() -> void:
	running = false
	timer.stop()

func on_resume() -> void:
	if remaining_seconds > 0:
		running = true
		timer.start()

func on_sync_state() -> Dictionary:
	return {
		"score": score,
		"remaining_seconds": remaining_seconds,
		"running": running
	}

func _perform_action() -> void:
	if not running:
		return
	score = mini(target_score, score + 1)
	if score >= target_score:
		_finish()
	else:
		_refresh_text()

func _on_tick() -> void:
	if not running:
		return
	remaining_seconds = maxi(0, remaining_seconds - 1)
	if remaining_seconds <= 0:
		_finish()
	else:
		_refresh_text()

func _finish() -> void:
	if not running:
		return
	running = false
	timer.stop()
	action_button.disabled = true
	status_label.text = App.t_key("creator.runtime.complete")
	ended.emit(on_end())

func _refresh_text() -> void:
	title_label.text = _localized_title()
	mode_label.text = App.format_key("creator.runtime.mode", {
		"mode": App.t_key("creator.mode.%s.name" % get_game_mode_id())
	})
	score_label.text = App.format_key("creator.runtime.score", {
		"score": score,
		"target": target_score
	})
	time_label.text = App.format_key("creator.runtime.time", {
		"seconds": remaining_seconds
	})
	status_label.text = App.t_key("creator.runtime.ready")
	action_button.text = App.t_key("creator.runtime.action")
	finish_button.text = App.t_key("creator.runtime.finish")
	action_button.disabled = not running and not runtime.is_empty()

func _localized_title() -> String:
	var names := runtime.get("name", {}) as Dictionary
	var value := str(names.get(App.current_locale, ""))
	if value.is_empty() and App.current_locale == "zh-Hans":
		value = str(names.get("zh", ""))
	return value if not value.is_empty() else str(names.get("en", definition.get("title", get_game_id())))

func _apply_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(game_panel)
	WorldHUDAssetsScript.configure_button_frame(action_button)
	WorldHUDAssetsScript.configure_button_frame(finish_button)

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
