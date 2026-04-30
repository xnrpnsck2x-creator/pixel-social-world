extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var lifecycle := root.get_node("NetworkLifecycle")
	root.get_node("RealtimeClient").call("configure", {"network": {"online_enabled": false}})

	lifecycle.call("configure", {
		"network": {
			"lifecycle_enabled": true,
			"pause_realtime_on_hidden": true
		}
	})
	lifecycle.call("suspend_network", "smoke")
	if not bool(lifecycle.call("is_suspended")):
		failures.append("NetworkLifecycle did not enter suspended state.")
	lifecycle.call("resume_network", "smoke")
	if bool(lifecycle.call("is_suspended")):
		failures.append("NetworkLifecycle did not resume.")

	lifecycle.call("configure", {"network": {"lifecycle_enabled": false}})
	lifecycle.call("suspend_network", "disabled")
	if bool(lifecycle.call("is_suspended")):
		failures.append("Disabled NetworkLifecycle still suspended.")
	lifecycle.call("configure", {"network": {"lifecycle_enabled": true}})

	if failures.is_empty():
		print("network lifecycle smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
