extends Control

const MOBILE_MAX_FPS := 24
const MOBILE_PHYSICS_TICKS_PER_SECOND := 30
const MOBILE_MAX_PHYSICS_STEPS_PER_FRAME := 4
const MOBILE_LOW_PROCESSOR_SLEEP_USEC := 6000
const ANDROID_DEBUG_STARTUP_PATH := "user://android_debug_startup.json"

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	_apply_mobile_frame_budget()
	status_label.text = "Loading..."
	if not App.is_initialized:
		await App.initialized
	status_label.text = App.t_key("boot.loading")
	var startup_route: String = str(App.app_config.get("startup_route", "login"))
	var debug_route := _local_web_debug_route()
	if debug_route.is_empty():
		debug_route = _local_android_debug_route()
	if not debug_route.is_empty():
		startup_route = debug_route
	await get_tree().process_frame
	SceneRouter.route_to(startup_route)

func _apply_mobile_frame_budget() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		Engine.max_fps = MOBILE_MAX_FPS
		Engine.physics_ticks_per_second = MOBILE_PHYSICS_TICKS_PER_SECOND
		Engine.max_physics_steps_per_frame = MOBILE_MAX_PHYSICS_STEPS_PER_FRAME
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode_sleep_usec = MOBILE_LOW_PROCESSOR_SLEEP_USEC

func _local_web_debug_route() -> String:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var network: Dictionary = App.app_config.get("network", {}) as Dictionary
	if not ["local_dev", "local_alpha"].has(str(network.get("environment", ""))):
		return ""
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var value: Variant = bridge.call("eval", "new URLSearchParams(window.location.search).get('psw_route') || ''", true)
	if typeof(value) != TYPE_STRING or str(value).is_empty():
		return ""
	bridge.call("eval", "window.__psw_debug_route = %s" % JSON.stringify(str(value)), true)
	return str(value)

func _local_android_debug_route() -> String:
	if not OS.has_feature("android") or not OS.is_debug_build():
		return ""
	if not FileAccess.file_exists(ANDROID_DEBUG_STARTUP_PATH):
		return ""
	var file := FileAccess.open(ANDROID_DEBUG_STARTUP_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	return str((parsed as Dictionary).get("route", "main_city"))
