extends SceneTree

class RuntimeClient:
	extends Node
	var online_enabled := true
	var response: Dictionary = {}

	func fetch_published_minigame_runtime(_game_id: String) -> Dictionary:
		return response

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile := (save_system.get("profile") as Dictionary).duplicate(true)
	var game_id := "creator_runtime_revocation"
	var runtime := _runtime_fixture(game_id)
	save_system.call("set_profile_value", "pending_creator_runtime", runtime)

	var launcher_script: Script = load("res://scripts/minigame/MinigameLauncher.gd")
	var launcher: Node = launcher_script.new()
	var client := RuntimeClient.new()
	launcher.runtime_client_override = client
	client.response = {"ok": false, "status": 404, "error": "not_found"}
	var revoked: Dictionary = await launcher.call("_fetch_creator_runtime", game_id)
	if not revoked.is_empty():
		failures.append("A revoked creator runtime launched from stale cache.")
	var cleared: Variant = save_system.call("get_profile_value", "pending_creator_runtime", {})
	if typeof(cleared) != TYPE_DICTIONARY or not (cleared as Dictionary).is_empty():
		failures.append("A 404 runtime response did not clear the stale cache.")

	save_system.call("set_profile_value", "pending_creator_runtime", runtime)
	client.response = {"ok": false, "status": 0, "offline": true, "error": "transport"}
	var offline: Dictionary = await launcher.call("_fetch_creator_runtime", game_id)
	if str(offline.get("game_path", "")) != "res://scenes/minigames/declarative/main.tscn":
		failures.append("Transport failure did not preserve the verified offline runtime cache.")

	var unsafe := runtime.duplicate(true)
	unsafe["mode_id"] = "2d_fighting"
	(unsafe["definition"] as Dictionary)["mode_id"] = "2d_fighting"
	(unsafe["definition"] as Dictionary)["type"] = "round_duel"
	save_system.call("set_profile_value", "pending_creator_runtime", unsafe)
	var unsupported: Dictionary = await launcher.call("_fetch_creator_runtime", game_id)
	if not unsupported.is_empty():
		failures.append("An unsupported declarative mode launched in the tap runtime.")

	launcher.free()
	client.free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("creator runtime revocation smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _runtime_fixture(game_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"game_id": game_id,
		"mode_id": "casual_activity",
		"name": {"en": "Runtime Guard", "ja": "Runtime Guard", "zh-Hans": "Runtime Guard"},
		"version": "1.0.0",
		"author": "creator",
		"min_players": 1,
		"max_players": 4,
		"runtime_contract": {
			"camera": "contained",
			"input_profile": "tap_timing",
			"network_profile": "offline_optional"
		},
		"manifest": {
			"lock_digest": "runtime-guard-lock",
			"interface": {"id": "interface.declarative_runtime", "version": "1.0.0"}
		},
		"definition": {
			"schema_version": 1,
			"game_id": game_id,
			"mode_id": "casual_activity",
			"type": "tap_timing"
		}
	}
