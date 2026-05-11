class_name WorldHUDMobileInputController
extends RefCounted

const COMPACT_HEIGHT := 480.0
const FALLBACK_KEYBOARD_INSET := 96.0
const FALLBACK_KEYBOARD_INSET_RATIO := 0.48
const FALLBACK_KEYBOARD_GRACE_MSEC := 1200
const PANEL_TOP_SAFE := 8.0
const PANEL_SHIFT_CAP := 260.0

var bottom_bar: Control
var viewport_size_override := Vector2.ZERO
var force_mobile_keyboard_guard := false
var web_visual_viewport_inset_override := -1.0
var _shift_targets: Array[Control] = []
var _base_offsets := {}
var _focused_input: LineEdit
var _focused := false
var _focus_started_msec := 0
var _timer: Timer

func bind(new_bottom_bar: Control, inputs: Array, panel_targets: Array = []) -> void:
	bottom_bar = new_bottom_bar
	_track_target(bottom_bar)
	for target in panel_targets:
		if target is Control:
			_track_target(target as Control)
	for input in inputs:
		if input is LineEdit:
			track_input(input as LineEdit)
	_timer = Timer.new()
	_timer.wait_time = 0.15
	_timer.timeout.connect(_refresh_inset)
	bottom_bar.add_child(_timer)
	_capture_offsets()

func track_input(input: LineEdit) -> void:
	if input == null:
		return
	input.focus_entered.connect(_on_focus_entered.bind(input))
	input.focus_exited.connect(_on_focus_exited)

func _on_focus_entered(input: LineEdit) -> void:
	_focused = true
	_focused_input = input
	_focus_started_msec = Time.get_ticks_msec()
	_mark_debug_input(_debug_input_id(input))
	_capture_offsets()
	_timer.start()
	_refresh_inset()

func _on_focus_exited() -> void:
	_focused = false
	_focused_input = null
	_mark_debug_input("")
	_refresh_inset()
	_timer.stop()

func _refresh_inset() -> void:
	if bottom_bar == null:
		return
	var viewport_size := _viewport_size()
	var keyboard_height: float = _virtual_keyboard_height()
	var inset := 0.0
	if _focused and (keyboard_height > 0.0 or _should_use_fallback_keyboard_inset(viewport_size)):
		var max_inset := viewport_size.y * 0.58
		var guarded_inset := keyboard_height if keyboard_height > 0.0 else _fallback_keyboard_inset(viewport_size)
		inset = min(guarded_inset, max_inset)
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
	return min(inset, _focused_input_shift(target, base, inset), PANEL_SHIFT_CAP)

func _focused_input_shift(target: Control, base: Vector2, inset: float) -> float:
	var viewport_size := _viewport_size()
	var current_shift := base.x - target.offset_top
	var input_rect := _focused_input.get_global_rect()
	var input_bottom := input_rect.position.y + input_rect.size.y + current_shift
	var visible_bottom := maxf(PANEL_TOP_SAFE + 56.0, viewport_size.y - inset - 8.0)
	return maxf(0.0, input_bottom - visible_bottom)

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
	var viewport_rect_size := bottom_bar.get_viewport_rect().size
	if viewport_rect_size.x > 0.0 and viewport_rect_size.y > 0.0:
		return viewport_rect_size
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0 and window_size.y > 0.0:
		return window_size
	return Vector2(960, 540)

func _virtual_keyboard_height() -> float:
	var web_height := _web_visual_viewport_keyboard_height()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return maxf(float(DisplayServer.virtual_keyboard_get_height()), web_height)
	return web_height

func _web_visual_viewport_keyboard_height() -> float:
	if web_visual_viewport_inset_override >= 0.0:
		return web_visual_viewport_inset_override
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return 0.0
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var css_inset: Variant = bridge.call("eval", """
(() => {
	const viewport = window.visualViewport;
	if (!viewport) return 0;
	const top = Math.max(0, viewport.offsetTop || 0);
	return Math.max(0, window.innerHeight - viewport.height - top);
})()
""", true)
	if typeof(css_inset) != TYPE_FLOAT and typeof(css_inset) != TYPE_INT:
		return 0.0
	var inner_height: Variant = bridge.call("eval", "window.innerHeight || 0", true)
	if typeof(inner_height) != TYPE_FLOAT and typeof(inner_height) != TYPE_INT:
		return float(css_inset)
	var viewport_size := _viewport_size()
	if float(inner_height) <= 1.0 or viewport_size.y <= 0.0:
		return float(css_inset)
	return float(css_inset) * viewport_size.y / float(inner_height)

func _should_guard_keyboard(viewport_size: Vector2) -> bool:
	return force_mobile_keyboard_guard or OS.get_name() in ["Android", "iOS"] or viewport_size.y <= COMPACT_HEIGHT

func _should_use_fallback_keyboard_inset(viewport_size: Vector2) -> bool:
	if not _should_guard_keyboard(viewport_size):
		return false
	return Time.get_ticks_msec() - _focus_started_msec <= FALLBACK_KEYBOARD_GRACE_MSEC

func _fallback_keyboard_inset(viewport_size: Vector2) -> float:
	if viewport_size.y <= COMPACT_HEIGHT:
		return FALLBACK_KEYBOARD_INSET
	return max(FALLBACK_KEYBOARD_INSET, viewport_size.y * FALLBACK_KEYBOARD_INSET_RATIO)

func _debug_input_id(input: LineEdit) -> String:
	match str(input.name):
		"ChatInput": return "chat"
		"RoomChatInput": return "room"
		"PrivateInput": return "private"
		"PriceInput": return "trade_price"
	return str(input.name).to_snake_case()

func _mark_debug_input(input_id: String) -> void:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_focused_input = %s" % JSON.stringify(input_id), true)
