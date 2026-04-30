extends Node

signal network_suspended(reason: String)
signal network_resumed(reason: String)

var lifecycle_enabled := true
var pause_realtime_on_hidden := true
var _suspended := false
var _visibility_callback: JavaScriptObject
var _has_manual_config := false

func _ready() -> void:
	configure()
	_install_web_visibility_listener()

func configure(config: Dictionary = {}) -> void:
	if config.is_empty() and _has_manual_config:
		return
	var source_config := config
	if source_config.is_empty() and has_node("/root/App"):
		source_config = (get_node("/root/App") as Node).get("app_config") as Dictionary
	elif not source_config.is_empty():
		_has_manual_config = true
	var network: Dictionary = source_config.get("network", {}) as Dictionary
	lifecycle_enabled = bool(network.get("lifecycle_enabled", lifecycle_enabled))
	pause_realtime_on_hidden = bool(network.get("pause_realtime_on_hidden", pause_realtime_on_hidden))

func suspend_network(reason: String = "manual") -> void:
	if not lifecycle_enabled or _suspended:
		return
	_suspended = true
	var realtime := _realtime_client()
	if realtime != null:
		realtime.call("pause_realtime")
	network_suspended.emit(reason)

func resume_network(reason: String = "manual") -> void:
	if not lifecycle_enabled or not _suspended:
		return
	_suspended = false
	var realtime := _realtime_client()
	if realtime != null:
		realtime.call("resume_realtime")
	network_resumed.emit(reason)

func is_suspended() -> bool:
	return _suspended

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		suspend_network("application_paused")
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		resume_network("application_resumed")

func _install_web_visibility_listener() -> void:
	if not _web_available() or not pause_realtime_on_hidden:
		return
	var bridge := _javascript_bridge()
	var document: JavaScriptObject = bridge.get_interface("document")
	if document == null:
		return
	_visibility_callback = bridge.create_callback(_on_web_visibility_changed)
	document.addEventListener("visibilitychange", _visibility_callback)

func _on_web_visibility_changed(_args: Array) -> void:
	if not _web_available():
		return
	var hidden := bool(_javascript_bridge().eval("document.hidden === true", true))
	if hidden:
		suspend_network("web_hidden")
	else:
		resume_network("web_visible")

func _web_available() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")

func _javascript_bridge() -> Object:
	return Engine.get_singleton("JavaScriptBridge")

func _realtime_client() -> Node:
	if not has_node("/root/RealtimeClient"):
		return null
	return get_node("/root/RealtimeClient")
