class_name MinigameLauncher
extends Control

signal launch_failed(reason: String)
signal game_finished(result: Dictionary)
signal emote_requested(player_id: String, emote_id: String)

const MINIGAME_BASE_SCRIPT := preload("res://scripts/minigame/IMinigame.gd")
const REQUIRED_METHODS := [
	"get_game_id",
	"get_game_name",
	"get_version",
	"get_author",
	"on_start",
	"on_end",
	"on_pause",
	"on_resume"
]

var active_game: Node
var active_game_id := ""
var active_session_id := ""
var _returning_to_world := false

@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var exit_button: Button = %ExitButton
@onready var top_bar: PanelContainer = $TopBar
@onready var sandbox_viewport: SubViewport = %SandboxViewport

func _ready() -> void:
	exit_button.pressed.connect(_request_return_to_world)
	App.locale_changed.connect(_on_locale_changed)
	_apply_sandbox_chrome()
	_refresh_text()
	_launch_pending_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_request_return_to_world()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_request_return_to_world()
		get_viewport().set_input_as_handled()

func launch_game(game_path: String, context: Dictionary) -> bool:
	_clear_active_game()

	if not ResourceLoader.exists(game_path):
		return _fail("Missing minigame scene: %s" % game_path)

	var resource: Resource = load(game_path)
	if resource == null or not resource is PackedScene:
		return _fail("Invalid minigame scene: %s" % game_path)

	var instance: Node = (resource as PackedScene).instantiate()
	if instance == null:
		return _fail("Unable to instantiate minigame: %s" % game_path)
	if not _is_valid_minigame(instance):
		instance.queue_free()
		return _fail("Invalid minigame interface: %s" % game_path)

	active_game = instance
	active_game_id = str(context.get("game_id", ""))
	active_session_id = str(context.get("session_id", "local"))
	if active_game.has_signal("ended"):
		active_game.ended.connect(_on_game_ended)
	if active_game.has_signal("emote_requested"):
		active_game.emote_requested.connect(_on_game_emote_requested)

	sandbox_viewport.add_child(active_game)
	active_game.call("on_start", context)
	status_label.text = App.t_key("minigame.sandbox.running")
	return true

func _launch_pending_game() -> void:
	var game_id: String = str(SaveSystem.get_profile_value("pending_minigame_id", "fishing"))
	var minigame: Dictionary = _find_minigame(game_id)
	if minigame.is_empty():
		_fail("Unknown minigame: %s" % game_id)
		return
	var session_id := str(SaveSystem.get_profile_value("pending_minigame_session_id", "local"))
	if has_node("/root/RoomLifecycle"):
		get_node("/root/RoomLifecycle").call(
			"enter_minigame",
			game_id,
			session_id,
			SaveSystem.get_display_name()
		)

	var context: Dictionary = {
		"game_id": game_id,
		"player_id": SaveSystem.get_player_id(),
		"room_id": SaveSystem.get_profile_value("current_room_id", "world_town_square"),
		"session_id": session_id,
		"settings": minigame,
		"online_client": _online_client()
	}
	launch_game(str(minigame.get("game_path", "")), context)

func _find_minigame(game_id: String) -> Dictionary:
	var config: Dictionary = ConfigLoader.load_config("minigames")
	for record in config.get("minigames", []):
		if typeof(record) == TYPE_DICTIONARY and str(record.get("id", "")) == game_id:
			return record as Dictionary
	return {}

func _is_valid_minigame(instance: Node) -> bool:
	for method_name in REQUIRED_METHODS:
		if not instance.has_method(method_name):
			return false

	var script: Script = instance.get_script()
	if script == null:
		return false
	return _script_extends_minigame(script)

func _script_extends_minigame(script: Script) -> bool:
	var cursor: Script = script
	while cursor != null:
		if cursor == MINIGAME_BASE_SCRIPT:
			return true
		cursor = cursor.get_base_script()
	return false

func _on_game_ended(result: Dictionary) -> void:
	status_label.text = App.t_key("minigame.sandbox.finished")
	await _close_online_session(true)
	game_finished.emit(result)
	_route_to_world()

func _on_game_emote_requested(player_id: String, emote_id: String) -> void:
	emote_requested.emit(player_id, emote_id)

func _request_return_to_world() -> void:
	if _returning_to_world:
		return
	_returning_to_world = true
	call_deferred("_return_to_world")

func _return_to_world() -> void:
	await _close_online_session(false)
	_route_to_world()

func _route_to_world() -> void:
	_clear_active_game()
	if has_node("/root/RoomLifecycle"):
		get_node("/root/RoomLifecycle").call("enter_main_city", SaveSystem.get_display_name())
	SaveSystem.set_profile_value("pending_minigame_session_id", "")
	SaveSystem.save_profile()
	SceneRouter.route_to("main_city")

func _clear_active_game() -> void:
	for child in sandbox_viewport.get_children():
		child.queue_free()
	active_game = null
	active_game_id = ""
	active_session_id = ""

func _close_online_session(ended: bool) -> void:
	if active_session_id.is_empty() or active_session_id.begins_with("local"):
		return
	var client := _online_client()
	if client == null or not bool(client.get("online_enabled")):
		return
	var response: Dictionary = {}
	if ended:
		response = await client.call("end_minigame_session", active_session_id)
	if not ended or not bool(response.get("ok", false)):
		await client.call("leave_minigame_session", active_session_id)

func _online_client() -> Node:
	if not has_node("/root/OnlineClient"):
		return null
	return get_node("/root/OnlineClient")

func _fail(reason: String) -> bool:
	push_error(reason)
	status_label.text = reason
	launch_failed.emit(reason)
	return false

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	title_label.text = App.t_key("scene.minigame.sandbox.title")
	status_label.text = App.t_key("minigame.sandbox.loading")
	exit_button.text = App.t_key("minigame.sandbox.exit")

func _apply_sandbox_chrome() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.16, 0.96)
	style.border_color = Color(0.21, 0.17, 0.12, 1.0)
	style.set_border_width_all(2)
	top_bar.add_theme_stylebox_override("panel", style)
	title_label.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76, 1.0))
	status_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.84, 1.0))
