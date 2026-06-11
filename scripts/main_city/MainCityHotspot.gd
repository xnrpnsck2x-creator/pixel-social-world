class_name MainCityHotspot
extends Area2D

signal activated(action_id: String)
signal input_activated(action_id: String, input_source: String)
@export var action_id := ""
@export var label_key := ""
@export var activity_state_enabled := false
@export var always_show_prompt := false
@onready var prompt_label: Label = $PromptLabel
const ACTIVATION_DEBOUNCE_MS := 450
const PROMPT_REVEAL_SECONDS := 1.2
const STATE_READY := "ready"
const STATE_COOLDOWN := "cooldown"
const STATE_DISABLED := "disabled"
const MOBILE_VIEWPORT_MAX_WIDTH := 960.0
const MOBILE_TOP_SAFE_Y := 112.0
const DESKTOP_TOP_SAFE_Y := 108.0
const MOBILE_BOTTOM_SAFE_HEIGHT := 76.0
const DESKTOP_BOTTOM_SAFE_HEIGHT := 24.0
const PROMPT_SCREEN_MARGIN := 8.0
const PROMPT_COLLISION_GAP := 8.0

var _activity_state := STATE_READY
var _cooldown_until_msec := 0
var _hovered := false
var _prompt_reveal_left := 0.0
var _last_activation_msec := -ACTIVATION_DEBOUNCE_MS
var _last_rendered_cooldown := -1
var _base_prompt_rect := Rect2()
var _base_prompt_ready := false

func _ready() -> void:
	add_to_group("main_city_hotspot")
	input_pickable = true
	set_process(false)
	mouse_entered.connect(_show_prompt)
	mouse_exited.connect(_hide_prompt)
	if has_node("/root/App"):
		App.locale_changed.connect(_on_locale_changed)
	if prompt_label != null:
		prompt_label.z_as_relative = false
		prompt_label.z_index = 1950
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.58, 1.0))
		prompt_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.03, 0.95))
		prompt_label.add_theme_constant_override("outline_size", 3)
		_capture_base_prompt_rect()
	_refresh_text()
	_sync_prompt_visibility()
	call_deferred("refresh_prompt_layout")

func activate(input_source := "") -> void:
	var now := Time.get_ticks_msec()
	if now - _last_activation_msec < ACTIVATION_DEBOUNCE_MS:
		return
	_last_activation_msec = now
	show_prompt_feedback()
	if not action_id.is_empty():
		if input_source.is_empty():
			activated.emit(action_id)
		else:
			input_activated.emit(action_id, input_source)

func set_activity_state(state: String, seconds: int = 0) -> void:
	activity_state_enabled = true
	_activity_state = state if state in [STATE_READY, STATE_COOLDOWN, STATE_DISABLED] else STATE_READY
	if _activity_state == STATE_COOLDOWN:
		_cooldown_until_msec = Time.get_ticks_msec() + max(1, seconds) * 1000
		set_process(true)
	else:
		_cooldown_until_msec = 0
		_sync_process_state()
	_last_rendered_cooldown = -1
	_refresh_text()
	_sync_prompt_visibility()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		activate("mouse")
		_viewport.set_input_as_handled()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		activate("touch")
		_viewport.set_input_as_handled()

func _process(_delta: float) -> void:
	if always_show_prompt and prompt_label != null and prompt_label.visible:
		refresh_prompt_layout()
	if _prompt_reveal_left > 0.0:
		_prompt_reveal_left = max(0.0, _prompt_reveal_left - _delta)
		if _prompt_reveal_left <= 0.0:
			_sync_prompt_visibility()
	if _activity_state == STATE_COOLDOWN:
		var remaining := _cooldown_seconds_remaining()
		if remaining <= 0:
			set_activity_state(STATE_READY, 0)
			return
		if remaining != _last_rendered_cooldown:
			_refresh_text()
	_sync_process_state()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	if prompt_label == null:
		return
	var title := App.t_key(label_key) if not label_key.is_empty() else action_id
	prompt_label.text = title
	if activity_state_enabled:
		prompt_label.text = "%s - %s" % [title, _state_text()]
		_apply_state_color()
	if prompt_label.visible:
		refresh_prompt_layout()

func _show_prompt() -> void:
	_hovered = true
	_sync_prompt_visibility()

func _hide_prompt() -> void:
	_hovered = false
	_sync_prompt_visibility()

func _sync_prompt_visibility() -> void:
	if prompt_label != null:
		var should_show := always_show_prompt or _hovered or _prompt_reveal_left > 0.0
		if should_show and is_inside_tree():
			refresh_prompt_layout()
		prompt_label.visible = should_show

func show_prompt_feedback(seconds: float = PROMPT_REVEAL_SECONDS) -> void:
	_prompt_reveal_left = max(0.1, seconds)
	_sync_prompt_visibility()
	set_process(true)

func refresh_prompt_layout() -> void:
	if prompt_label == null or not is_inside_tree():
		return
	_capture_base_prompt_rect()
	_apply_prompt_rect(_base_prompt_rect)
	var viewport_size := _visible_viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var top_safe := _top_safe_y(viewport_size)
	var bottom_safe := viewport_size.y - _bottom_safe_height(viewport_size)
	var prompt_rect := _prompt_screen_rect()
	if prompt_rect.position.y < top_safe:
		_apply_prompt_rect(_below_prompt_rect())
		prompt_rect = _prompt_screen_rect()
	var screen_shift := Vector2.ZERO
	if prompt_rect.position.x < PROMPT_SCREEN_MARGIN:
		screen_shift.x += PROMPT_SCREEN_MARGIN - prompt_rect.position.x
	elif prompt_rect.end.x > viewport_size.x - PROMPT_SCREEN_MARGIN:
		screen_shift.x -= prompt_rect.end.x - (viewport_size.x - PROMPT_SCREEN_MARGIN)
	if prompt_rect.position.y < top_safe:
		screen_shift.y += top_safe - prompt_rect.position.y
	elif prompt_rect.end.y > bottom_safe:
		screen_shift.y -= prompt_rect.end.y - bottom_safe
	_shift_prompt_by_screen(screen_shift)

func debug_prompt_screen_rect() -> Dictionary:
	if prompt_label == null:
		return {}
	refresh_prompt_layout()
	var rect := _prompt_screen_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y
	}

func _sync_process_state() -> void:
	set_process(always_show_prompt or _prompt_reveal_left > 0.0 or _activity_state == STATE_COOLDOWN)

func _state_text() -> String:
	if _activity_state == STATE_COOLDOWN:
		var remaining := _cooldown_seconds_remaining()
		_last_rendered_cooldown = remaining
		return App.format_key("map_activity.hotspot.cooldown_short", {"seconds": remaining})
	if _activity_state == STATE_DISABLED:
		return App.t_key("map_activity.hotspot.disabled")
	return App.t_key("map_activity.hotspot.ready")

func _cooldown_seconds_remaining() -> int:
	return max(0, ceili(float(_cooldown_until_msec - Time.get_ticks_msec()) / 1000.0))

func _apply_state_color() -> void:
	var color := Color(0.95, 0.78, 0.34, 1.0)
	if _activity_state == STATE_COOLDOWN:
		color = Color(0.78, 0.79, 0.75, 1.0)
	elif _activity_state == STATE_DISABLED:
		color = Color(0.95, 0.46, 0.42, 1.0)
	prompt_label.add_theme_color_override("font_color", color)

func _capture_base_prompt_rect() -> void:
	if _base_prompt_ready or prompt_label == null:
		return
	_base_prompt_rect = Rect2(
		Vector2(prompt_label.offset_left, prompt_label.offset_top),
		Vector2(
			prompt_label.offset_right - prompt_label.offset_left,
			prompt_label.offset_bottom - prompt_label.offset_top
		)
	)
	_base_prompt_ready = _base_prompt_rect.size.x > 0.0 and _base_prompt_rect.size.y > 0.0

func _apply_prompt_rect(rect: Rect2) -> void:
	if prompt_label == null:
		return
	prompt_label.offset_left = rect.position.x
	prompt_label.offset_top = rect.position.y
	prompt_label.offset_right = rect.position.x + rect.size.x
	prompt_label.offset_bottom = rect.position.y + rect.size.y

func _below_prompt_rect() -> Rect2:
	var bounds := _collision_local_bounds()
	var height: float = maxf(24.0, float(_base_prompt_rect.size.y))
	var width: float = maxf(96.0, float(_base_prompt_rect.size.x))
	return Rect2(
		Vector2(_base_prompt_rect.position.x, bounds.position.y + bounds.size.y + PROMPT_COLLISION_GAP),
		Vector2(width, height)
	)

func _collision_local_bounds() -> Rect2:
	var bounds := Rect2(Vector2(-48.0, -28.0), Vector2(96.0, 64.0))
	var has_bounds := false
	for child in get_children():
		var rect := Rect2()
		var found := false
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			var shape := (child as CollisionShape2D).shape as RectangleShape2D
			rect = Rect2((child as Node2D).position - shape.size * 0.5, shape.size)
			found = true
		elif child is CollisionPolygon2D:
			rect = _polygon_bounds((child as CollisionPolygon2D).polygon, (child as Node2D).position)
			found = rect.size.x > 0.0 and rect.size.y > 0.0
		if not found:
			continue
		if has_bounds:
			bounds = bounds.merge(rect)
		else:
			bounds = rect
			has_bounds = true
	return bounds

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

func _prompt_screen_rect() -> Rect2:
	var size := Vector2(
		prompt_label.offset_right - prompt_label.offset_left,
		prompt_label.offset_bottom - prompt_label.offset_top
	)
	var transform := prompt_label.get_global_transform_with_canvas()
	var rect := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	rect = rect.expand(transform * Vector2(size.x, 0.0))
	rect = rect.expand(transform * Vector2(0.0, size.y))
	rect = rect.expand(transform * size)
	return rect

func _visible_viewport_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return viewport_size
	return Vector2(
		minf(viewport_size.x, window_size.x),
		minf(viewport_size.y, window_size.y)
	)

func _shift_prompt_by_screen(screen_shift: Vector2) -> void:
	if screen_shift == Vector2.ZERO or prompt_label == null:
		return
	var transform := get_global_transform_with_canvas().affine_inverse()
	var local_origin := transform * Vector2.ZERO
	var local_shift := (transform * screen_shift) - local_origin
	prompt_label.offset_left += local_shift.x
	prompt_label.offset_right += local_shift.x
	prompt_label.offset_top += local_shift.y
	prompt_label.offset_bottom += local_shift.y

func _top_safe_y(viewport_size: Vector2) -> float:
	if viewport_size.x <= MOBILE_VIEWPORT_MAX_WIDTH:
		return minf(MOBILE_TOP_SAFE_Y, viewport_size.y * 0.32)
	return DESKTOP_TOP_SAFE_Y

func _bottom_safe_height(viewport_size: Vector2) -> float:
	if viewport_size.x <= MOBILE_VIEWPORT_MAX_WIDTH:
		return minf(MOBILE_BOTTOM_SAFE_HEIGHT, viewport_size.y * 0.24)
	return DESKTOP_BOTTOM_SAFE_HEIGHT
