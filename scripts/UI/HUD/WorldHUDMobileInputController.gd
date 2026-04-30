class_name WorldHUDMobileInputController
extends RefCounted

const COMPACT_HEIGHT := 480.0
const FALLBACK_KEYBOARD_INSET := 96.0
const PANEL_TOP_SAFE := 8.0
const PANEL_SHIFT_CAP := 72.0

var bottom_bar: Control
var viewport_size_override := Vector2.ZERO
var _shift_targets: Array[Control] = []
var _base_offsets := {}
var _focused_input: LineEdit
var _focused := false
var _timer: Timer

func bind(new_bottom_bar: Control, inputs: Array, panel_targets: Array = []) -> void:
	bottom_bar = new_bottom_bar
	_track_target(bottom_bar)
	for target in panel_targets:
		if target is Control:
			_track_target(target as Control)
	for input in inputs:
		if input is LineEdit:
			(input as LineEdit).focus_entered.connect(_on_focus_entered.bind(input))
			(input as LineEdit).focus_exited.connect(_on_focus_exited)
	_timer = Timer.new()
	_timer.wait_time = 0.15
	_timer.timeout.connect(_refresh_inset)
	bottom_bar.add_child(_timer)
	_capture_offsets()

func _on_focus_entered(input: LineEdit) -> void:
	_focused = true
	_focused_input = input
	_capture_offsets()
	_timer.start()
	_refresh_inset()

func _on_focus_exited() -> void:
	_focused = false
	_focused_input = null
	_refresh_inset()
	_timer.stop()

func _refresh_inset() -> void:
	if bottom_bar == null:
		return
	var viewport_size := _viewport_size()
	var inset := 0.0
	if _focused and viewport_size.y <= COMPACT_HEIGHT:
		inset = max(_virtual_keyboard_height(), FALLBACK_KEYBOARD_INSET)
	for target in _shift_targets:
		if not is_instance_valid(target):
			continue
		var base: Vector2 = _base_offsets.get(target.get_instance_id(), Vector2(target.offset_top, target.offset_bottom))
		var shift := _target_shift(target, base, inset)
		target.offset_top = base.x - shift
		target.offset_bottom = base.y - shift

func _track_target(target: Control) -> void:
	if target != null and not _shift_targets.has(target):
		_shift_targets.append(target)

func _capture_offsets() -> void:
	for target in _shift_targets:
		if is_instance_valid(target):
			_base_offsets[target.get_instance_id()] = Vector2(target.offset_top, target.offset_bottom)

func _target_shift(target: Control, base: Vector2, inset: float) -> float:
	if target == bottom_bar:
		return inset
	if not _focused or _focused_input == null or not _target_contains_focus(target):
		return 0.0
	return min(inset, max(0.0, base.x - PANEL_TOP_SAFE), PANEL_SHIFT_CAP)

func _target_contains_focus(target: Control) -> bool:
	var node: Node = _focused_input
	while node != null:
		if node == target:
			return true
		node = node.get_parent()
	return false

func _viewport_size() -> Vector2:
	if viewport_size_override.x > 0.0 and viewport_size_override.y > 0.0:
		return viewport_size_override
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		return window_size
	return bottom_bar.get_viewport_rect().size

func _virtual_keyboard_height() -> float:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return float(DisplayServer.virtual_keyboard_get_height())
	return 0.0
