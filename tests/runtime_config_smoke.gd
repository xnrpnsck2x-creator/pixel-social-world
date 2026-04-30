extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var service := root.get_node("RuntimeConfigService")
	var base := {
		"version": "0.1.0",
		"feature_flags": {"chat": true, "friends": false},
		"network": {
			"environment": "local_dev",
			"base_url": "http://127.0.0.1:8787",
			"websocket_url": "ws://127.0.0.1:8787/ws/city",
			"online_enabled": false,
			"web_session_storage_key": "keep-this"
		}
	}
	var overrides := {
		"web_build": "test-build",
		"maintenance": {"enabled": true, "message_key": "maintenance.test"},
		"network": {
			"environment": "production",
			"base_url": "https://api.funyoru.com",
			"websocket_url": "wss://api.funyoru.com/ws/city",
			"web_session_storage_key": "do-not-override"
		},
		"feature_flags": {"chat": false, "trading": true, "friends": "bad"},
		"unexpected": {"value": true}
	}
	var merged: Dictionary = service.call("apply_overrides", base, overrides)
	var network: Dictionary = merged.get("network", {}) as Dictionary
	var flags: Dictionary = merged.get("feature_flags", {}) as Dictionary
	if network.get("base_url") != "https://api.funyoru.com":
		failures.append("Runtime base_url override was not applied.")
	if network.get("web_session_storage_key") != "keep-this":
		failures.append("Disallowed network override changed session storage key.")
	if bool(flags.get("chat", true)):
		failures.append("Boolean feature flag override was not applied.")
	if flags.get("friends") != false:
		failures.append("Non-boolean feature flag override was applied.")
	if not bool(flags.get("trading", false)):
		failures.append("New boolean feature flag was not added.")
	if merged.has("unexpected"):
		failures.append("Unexpected top-level runtime config key was applied.")
	if not bool((merged.get("maintenance", {}) as Dictionary).get("enabled", false)):
		failures.append("Maintenance block was not applied.")

	var resolved: Dictionary = await service.call("resolve_app_config", {
		"runtime_config": {
			"enabled": true,
			"url": "",
			"local_fallback_path": "res://configs/runtime_overrides.json"
		},
		"network": {"base_url": "http://local"}
	})
	if str(resolved.get("web_build", "")) != "local-dev":
		failures.append("Local runtime fallback was not loaded.")

	if failures.is_empty():
		print("runtime config smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
