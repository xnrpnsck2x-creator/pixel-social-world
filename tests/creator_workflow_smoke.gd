extends SceneTree

const CreatorWorkflowScript := preload("res://scripts/UI/Panels/CreatorWorkflow.gd")

class FakeCreatorClient extends Node:
	func discover_creator_keywords(
		_text: String,
		_mode_id: String,
		_locale: String,
		_limit: int
	) -> Dictionary:
		await get_tree().process_frame
		return {
			"ok": true,
			"data": {
				"revision": "test.1",
				"matches": [{
					"id": "keyword.activity.fishing",
					"kind": "keyword",
					"version": "1.0.0",
					"name": "Fishing",
					"score": 100
				}]
			}
		}

	func fetch_creator_registry(_filters: Dictionary) -> Dictionary:
		await get_tree().process_frame
		return {
			"ok": true,
			"data": {
				"revision": "test.1",
				"items": [{
					"id": "cap.timer.local",
					"kind": "capability",
					"version": "1.0.0",
					"status": "stable"
				}]
			}
		}

	func resolve_creator_manifest(manifest: Dictionary) -> Dictionary:
		await get_tree().process_frame
		var resolved := manifest.duplicate(true)
		resolved["granted_permissions"] = []
		resolved["lock_digest"] = "1234567890abcdef"
		return {
			"ok": true,
			"data": {
				"ok": true,
				"resolved_manifest": resolved,
				"issues": []
			}
		}

	func fetch_creator_submission_history(_game_id: String) -> Dictionary:
		await get_tree().process_frame
		return {"ok": false, "status": 404, "error": "not_found"}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "creator-workflow-player",
		"device_id": "creator-workflow-device",
		"display_name": "Creator Workflow",
		"locale": "en",
		"coin_balance": 0,
		"inventory": [],
		"owned_items": [],
		"house_items": []
	})
	save_system.call("_apply_defaults")

	var client := FakeCreatorClient.new()
	root.add_child(client)
	var workflow := CreatorWorkflowScript.new()
	var result: Dictionary = await workflow.analyze(
		client,
		"A calm river fishing timing game",
		"casual_activity"
	)
	if not bool(result.get("ok", false)):
		failures.append("Creator workflow did not resolve a valid idea: %s" % str(result))
	var state := result.get("state", {}) as Dictionary
	var resolved := state.get("resolved_manifest", {}) as Dictionary
	if (resolved.get("keywords", []) as Array) != ["keyword.activity.fishing"]:
		failures.append("Creator workflow did not retain discovered keywords.")
	if str(resolved.get("lock_digest", "")) != "1234567890abcdef":
		failures.append("Creator workflow did not retain the manifest lock.")

	var package := workflow.build_package()
	var paths := PackedStringArray()
	for value in package.get("files", []):
		if typeof(value) == TYPE_DICTIONARY:
			paths.append(str((value as Dictionary).get("path", "")))
	if paths != PackedStringArray([
		"meta.json",
		"creator_manifest.json",
		"content/game.json",
		"README.md"
	]):
		failures.append("Creator workflow package paths were not declarative-only: %s" % str(paths))
	for path in paths:
		if path.ends_with(".gd") or path.ends_with(".tscn"):
			failures.append("Creator workflow emitted an executable package file.")
	var definition := _file_json(package, "content/game.json")
	if str(definition.get("game_id", "")) != str(state.get("game_id", "")):
		failures.append("Creator definition identity did not match the resolved manifest.")
	if int((definition.get("settings", {}) as Dictionary).get("target_score", 0)) <= 0:
		failures.append("Creator definition did not include bounded runtime settings.")
	var reserved: Dictionary = await workflow.analyze(
		client,
		"A fighting game",
		"2d_fighting"
	)
	if bool(reserved.get("ok", false)) or str(reserved.get("error", "")) != "mode_not_found":
		failures.append("Creator workflow exposed a mode without a public runtime.")

	client.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("creator workflow smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _file_json(package: Dictionary, path: String) -> Dictionary:
	for value in package.get("files", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var file := value as Dictionary
		if str(file.get("path", "")) == path:
			var parsed: Variant = JSON.parse_string(str(file.get("content_text", "")))
			return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
	return {}
