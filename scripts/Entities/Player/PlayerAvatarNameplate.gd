class_name PlayerAvatarNameplate
extends RefCounted

var avatar: Node2D
var label: Label
var reveal_seconds := 3.0
var hit_radius := 26.0
var _time_left := 0.0

func bind(new_avatar: Node2D, new_label: Label, seconds: float, radius: float) -> void:
	avatar = new_avatar
	label = new_label
	reveal_seconds = seconds
	hit_radius = radius

func refresh(display_name: String) -> void:
	if label != null:
		label.text = display_name

func reveal(display_name: String, seconds: float = -1.0) -> void:
	if label == null or display_name.strip_edges().is_empty():
		return
	_time_left = max(0.1, seconds if seconds > 0.0 else reveal_seconds)
	label.visible = true

func hide() -> void:
	_time_left = 0.0
	if label != null:
		label.visible = false

func tick(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = max(0.0, _time_left - delta)
	if _time_left <= 0.0:
		hide()

func handle_input(event: InputEvent, input_enabled: bool, player_id: String, display_name: String) -> Dictionary:
	if avatar == null or not event is InputEventMouseButton:
		return {}
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return {}
	if avatar.global_position.distance_to(avatar.get_global_mouse_position()) > hit_radius:
		return {}
	reveal(display_name)
	avatar.get_viewport().set_input_as_handled()
	if not input_enabled and not player_id.is_empty():
		return {
			"handled": true,
			"profile": {
				"player_id": player_id,
				"display_name": display_name
			}
		}
	return {"handled": true}
