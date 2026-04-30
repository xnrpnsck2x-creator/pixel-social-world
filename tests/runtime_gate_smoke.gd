extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var app: Node = root.get_node("App")
	var original_config: Dictionary = (app.get("app_config") as Dictionary).duplicate(true)

	app.set("app_config", {
		"version": "0.1.0",
		"maintenance": {"enabled": true, "message_key": ""},
		"min_client_version": "0.1.0"
	})
	var maintenance_gate: Dictionary = app.call("get_runtime_gate")
	if not bool(maintenance_gate.get("blocked", false)):
		failures.append("Maintenance gate did not block login.")
	if str(maintenance_gate.get("type", "")) != "maintenance":
		failures.append("Maintenance gate type was not reported.")

	app.set("app_config", {
		"version": "0.1.0",
		"maintenance": {"enabled": false},
		"min_client_version": "0.2.0"
	})
	var version_gate: Dictionary = app.call("get_runtime_gate")
	if not bool(version_gate.get("blocked", false)):
		failures.append("Version gate did not block old client.")
	if str(version_gate.get("type", "")) != "version":
		failures.append("Version gate type was not reported.")
	var values: Dictionary = version_gate.get("detail_values", {}) as Dictionary
	if str(values.get("current", "")) != "0.1.0" or str(values.get("minimum", "")) != "0.2.0":
		failures.append("Version gate values were not preserved.")

	app.set("app_config", {
		"version": "0.3.0",
		"maintenance": {"enabled": false},
		"min_client_version": "0.2.0"
	})
	var clear_gate: Dictionary = app.call("get_runtime_gate")
	if bool(clear_gate.get("blocked", false)):
		failures.append("Runtime gate blocked a compatible client.")

	app.set("app_config", original_config)
	if failures.is_empty():
		print("runtime gate smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
