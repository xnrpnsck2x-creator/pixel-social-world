extends Control

@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	status_label.text = "Loading..."
	if not App.is_initialized:
		await App.initialized
	status_label.text = App.t_key("boot.loading")
	var startup_route: String = str(App.app_config.get("startup_route", "login"))
	var debug_route := _local_web_debug_route()
	if not debug_route.is_empty():
		startup_route = debug_route
	SceneRouter.route_to(startup_route)

func _local_web_debug_route() -> String:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var network: Dictionary = App.app_config.get("network", {}) as Dictionary
	if str(network.get("environment", "")) != "local_dev":
		return ""
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var value: Variant = bridge.call("eval", "new URLSearchParams(window.location.search).get('psw_route') || ''", true)
	if typeof(value) != TYPE_STRING or str(value).is_empty():
		return ""
	bridge.call("eval", "window.__psw_debug_route = %s" % JSON.stringify(str(value)), true)
	return str(value)
