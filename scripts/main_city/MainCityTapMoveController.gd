class_name MainCityTapMoveController
extends Node2D

signal hotspot_requested(action_id: String)

const ACTIONS := {
	"left": "ui_left",
	"right": "ui_right",
	"up": "ui_up",
	"down": "ui_down"
}
const ARRIVAL_RADIUS := 7.0
const DEADZONE := 0.16
const STUCK_SECONDS := 1.25
const STUCK_EPSILON := 1.5
const HOTSPOT_SCREEN_RADIUS := 220.0
const HOTSPOT_TOUCH_PADDING := 70.0
const SYNTHETIC_MOUSE_SUPPRESS_MS := 420
const SYNTHETIC_MOUSE_RADIUS := 18.0
const TARGET_MARKER_ICON := "res://assets/ui/sliced/hud_icons_v0/hud_icons_v0_038.png"
const TARGET_MARKER_SCALE := Vector2(0.20, 0.20)
const TARGET_MARKER_ALPHA := 0.88
const TARGET_PULSE_POINTS := [
	Vector2(0, -18),
	Vector2(18, 0),
	Vector2(0, 18),
	Vector2(-18, 0),
	Vector2(0, -18)
]
const TARGET_PULSE_COLOR := Color(1.0, 0.78, 0.28, 0.92)

var player: Node2D
var enabled := true
var _target := Vector2.ZERO
var _has_target := false
var _managed_actions := {}
var _last_distance := INF
var _stuck_time := 0.0
var _last_touch_screen := Vector2(INF, INF)
var _last_touch_msec := -SYNTHETIC_MOUSE_SUPPRESS_MS
var _target_marker: Sprite2D
var _target_pulse: Line2D

func _ready() -> void:
	_build_target_marker()

func bind(new_player: Node2D) -> void:
	player = new_player
	set_process(false)

func _exit_tree() -> void:
	_clear_target()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or player == null or _has_text_focus():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_last_touch_screen = touch.position
			_last_touch_msec = Time.get_ticks_msec()
			_handle_tap(touch.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and not _is_synthetic_mouse_after_touch(mouse.position) and _mouse_tap_enabled():
			_handle_tap(mouse.position)

func _process(delta: float) -> void:
	if not _has_target or player == null:
		return
	var offset := _target - player.global_position
	var distance := offset.length()
	if distance <= ARRIVAL_RADIUS or _is_stuck(distance, delta):
		_clear_target()
		return
	_apply_direction(offset.normalized())

func _set_target(world_position: Vector2) -> void:
	if player != null and player.has_method("can_enter_world_position"):
		if not bool(player.call("can_enter_world_position", world_position)):
			_clear_target()
			return
	_target = world_position
	_has_target = true
	_last_distance = INF
	_stuck_time = 0.0
	_show_target_marker(world_position)
	set_process(true)

func _handle_tap(screen_position: Vector2) -> void:
	var world_position := _screen_to_world(screen_position)
	if _activate_hotspot_at(screen_position, world_position):
		_clear_target()
		return
	_set_target(world_position)

func _activate_hotspot_at(screen_position: Vector2, world_position: Vector2) -> bool:
	var best_hotspot: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("main_city_hotspot"):
		var hotspot := node as Area2D
		if hotspot == null or hotspot.get_viewport() != get_viewport():
			continue
		if not hotspot.visible or not hotspot.monitoring or not hotspot.input_pickable:
			continue
		if not hotspot.has_method("activate"):
			continue
		var score := _hotspot_touch_score(hotspot, screen_position, world_position)
		if score < best_score:
			best_score = score
			best_hotspot = hotspot
	if best_hotspot == null:
		return false
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	var action_id := str(best_hotspot.get("action_id"))
	if best_hotspot.has_method("show_prompt_feedback"):
		best_hotspot.call("show_prompt_feedback")
	if not action_id.is_empty():
		hotspot_requested.emit(action_id)
	return true

func _hotspot_touch_score(hotspot: Area2D, screen_position: Vector2, world_position: Vector2) -> float:
	var screen_center := get_viewport().get_canvas_transform() * hotspot.global_position
	var screen_distance := screen_center.distance_to(screen_position)
	if _point_in_hotspot_collision_bounds(hotspot, world_position, 0.0):
		return screen_distance
	var can_walk := _can_walk_to(world_position)
	if not can_walk and _point_in_hotspot_expanded_bounds(hotspot, world_position):
		return screen_distance + HOTSPOT_SCREEN_RADIUS
	if not can_walk and screen_distance <= HOTSPOT_SCREEN_RADIUS:
		return screen_distance + HOTSPOT_SCREEN_RADIUS
	return INF

func _can_walk_to(world_position: Vector2) -> bool:
	if player != null and player.has_method("can_enter_world_position"):
		return bool(player.call("can_enter_world_position", world_position))
	return true

func _point_in_hotspot_expanded_bounds(hotspot: Area2D, world_position: Vector2) -> bool:
	if hotspot.has_meta("mobile_touch_rect"):
		var touch_rect: Variant = hotspot.get_meta("mobile_touch_rect")
		if typeof(touch_rect) == TYPE_RECT2:
			var mobile_rect: Rect2 = touch_rect
			if mobile_rect.has_point(world_position):
				return true
	return _point_in_hotspot_collision_bounds(hotspot, world_position, HOTSPOT_TOUCH_PADDING)

func _point_in_hotspot_collision_bounds(hotspot: Area2D, world_position: Vector2, padding: float) -> bool:
	var local_point := hotspot.to_local(world_position)
	for child in hotspot.get_children():
		var rect := Rect2()
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			var collision := child as CollisionShape2D
			var shape := collision.shape as RectangleShape2D
			rect = Rect2(collision.position - shape.size * 0.5, shape.size)
		elif child is CollisionPolygon2D:
			var polygon := child as CollisionPolygon2D
			rect = _polygon_bounds(polygon.polygon, polygon.position)
		else:
			continue
		if rect.grow(padding).has_point(local_point):
			return true
	return false

func _polygon_bounds(points: PackedVector2Array, origin: Vector2) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := points[0] + origin
	var max_point := min_point
	for point in points:
		var local_point := point + origin
		min_point.x = min(min_point.x, local_point.x)
		min_point.y = min(min_point.y, local_point.y)
		max_point.x = max(max_point.x, local_point.x)
		max_point.y = max(max_point.y, local_point.y)
	return Rect2(min_point, max_point - min_point)

func _clear_target() -> void:
	for action in _managed_actions.keys():
		Input.action_release(str(action))
	_managed_actions.clear()
	_has_target = false
	_hide_target_marker()
	set_process(false)

func _apply_direction(direction: Vector2) -> void:
	_set_action("left", direction.x < -DEADZONE, absf(direction.x))
	_set_action("right", direction.x > DEADZONE, absf(direction.x))
	_set_action("up", direction.y < -DEADZONE, absf(direction.y))
	_set_action("down", direction.y > DEADZONE, absf(direction.y))

func _set_action(key: String, pressed: bool, strength: float) -> void:
	var action := str(ACTIONS[key])
	if pressed:
		Input.action_press(action, clamp(strength, 0.0, 1.0))
		_managed_actions[action] = true
	elif _managed_actions.has(action):
		Input.action_release(action)
		_managed_actions.erase(action)

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _has_text_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _mouse_tap_enabled() -> bool:
	return OS.get_name() in ["Android", "iOS", "Web"] or DisplayServer.is_touchscreen_available()

func _is_synthetic_mouse_after_touch(position: Vector2) -> bool:
	var age := Time.get_ticks_msec() - _last_touch_msec
	return age >= 0 and age <= SYNTHETIC_MOUSE_SUPPRESS_MS and _last_touch_screen.distance_to(position) <= SYNTHETIC_MOUSE_RADIUS

func _is_stuck(distance: float, delta: float) -> bool:
	if distance < _last_distance - STUCK_EPSILON:
		_last_distance = distance
		_stuck_time = 0.0
		return false
	_stuck_time += delta
	_last_distance = min(_last_distance, distance)
	return _stuck_time >= STUCK_SECONDS

func _build_target_marker() -> void:
	if _target_marker != null:
		return
	_target_marker = Sprite2D.new()
	_target_marker.name = "TapTargetMarker"
	_target_marker.texture = ResourceLoader.load(TARGET_MARKER_ICON) as Texture2D
	_target_marker.scale = TARGET_MARKER_SCALE
	_target_marker.modulate = Color(1.0, 1.0, 1.0, TARGET_MARKER_ALPHA)
	_target_marker.z_as_relative = false
	_target_marker.z_index = 1960
	_target_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_target_marker.visible = false
	add_child(_target_marker)
	_target_pulse = Line2D.new()
	_target_pulse.name = "TapTargetPulse"
	_target_pulse.points = PackedVector2Array(TARGET_PULSE_POINTS)
	_target_pulse.width = 3.0
	_target_pulse.default_color = TARGET_PULSE_COLOR
	_target_pulse.z_as_relative = false
	_target_pulse.z_index = 1961
	_target_pulse.visible = false
	add_child(_target_pulse)

func _show_target_marker(world_position: Vector2) -> void:
	_build_target_marker()
	_target_marker.global_position = world_position
	_target_marker.visible = true
	_target_pulse.global_position = world_position
	_target_pulse.visible = true

func _hide_target_marker() -> void:
	if _target_marker != null:
		_target_marker.visible = false
	if _target_pulse != null:
		_target_pulse.visible = false
