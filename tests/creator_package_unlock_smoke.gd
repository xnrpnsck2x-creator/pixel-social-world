extends SceneTree

class FakeCreatorClient:
	extends Node

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
				"revision": "unlock.1",
				"matches": [{
					"id": "keyword.loop.tap_timing",
					"kind": "keyword",
					"version": "1.0.0",
					"name": "Tap timing",
					"score": 100
				}]
			}
		}

	func fetch_creator_registry(_filters: Dictionary) -> Dictionary:
		await get_tree().process_frame
		return {
			"ok": true,
			"data": {
				"revision": "unlock.1",
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
		resolved["lock_digest"] = "unlock-lock"
		return {
			"ok": true,
			"data": {"ok": true, "resolved_manifest": resolved, "issues": []}
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
	var original_profile := (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "creator-unlock-player",
		"device_id": "creator-unlock-device",
		"display_name": "Creator Unlock",
		"locale": "en"
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/ui/WorldUtilityPanel.tscn")
	var panel: Node = scene.instantiate()
	root.add_child(panel)
	panel.call("show_panel", "creator")
	var client := FakeCreatorClient.new()
	root.add_child(client)
	var draft_rows: Variant = panel.get("_creator_draft_rows")
	draft_rows.set("client_override", client)
	var idea_input := panel.find_child("CreatorIdeaInput", true, false) as LineEdit
	var analyze_button := panel.find_child("CreatorAnalyzeButton", true, false) as Button
	var submit_button := panel.find_child("CreatorPackageSubmitButton", true, false) as Button
	if idea_input == null or analyze_button == null or submit_button == null:
		failures.append("Creator workflow controls were not rendered.")
	else:
		if not submit_button.disabled:
			failures.append("Package submit started enabled without a resolved manifest.")
		idea_input.text = "A small tap timing game"
		idea_input.text_changed.emit(idea_input.text)
		analyze_button.pressed.emit()
		for _frame in range(7):
			await process_frame
		if submit_button.disabled:
			failures.append("Analyze success did not unlock package submit immediately.")

	panel.queue_free()
	client.queue_free()
	await process_frame
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("creator package unlock smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
