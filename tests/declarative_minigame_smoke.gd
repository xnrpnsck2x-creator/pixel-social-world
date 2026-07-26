extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/minigames/declarative/main.tscn")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame

	var ended_results: Array[Dictionary] = []
	game.ended.connect(func(result: Dictionary) -> void:
		ended_results.append(result)
	)
	game.call("on_start", {
		"player_id": "creator-runtime-player",
		"settings": {
			"id": "creator_runtime_smoke",
			"version": "0.1.0",
			"author": "creator",
			"mode_id": "casual_activity",
			"name": {
				"en": "River Timing",
				"ja": "River Timing",
				"zh-Hans": "河畔时机"
			},
			"runtime_contract": {
				"camera": "contained",
				"input_profile": "tap_timing",
				"network_profile": "offline_optional"
			},
			"runtime_definition": {
				"schema_version": 1,
				"game_id": "creator_runtime_smoke",
				"mode_id": "casual_activity",
				"type": "tap_timing",
				"settings": {
					"duration_seconds": 30,
					"target_score": 3
				}
			}
		}
	})
	if str(game.call("get_game_id")) != "creator_runtime_smoke":
		failures.append("Declarative runtime did not expose the published game id.")
	if str(game.get_node("%TitleLabel").text) != "River Timing":
		failures.append("Declarative runtime did not localize the creator title.")
	for _index in range(3):
		game.call("_perform_action")
	var ended_result: Dictionary = ended_results.front() if not ended_results.is_empty() else {}
	if not bool((ended_result.get("stats", {}) as Dictionary).get("completed", false)):
		failures.append("Declarative runtime did not complete its bounded goal.")
	if not (ended_result.get("rewards", {}) as Dictionary).is_empty():
		failures.append("Declarative runtime granted unreviewed client-side rewards.")
	if not game.call("on_sync_state").has("remaining_seconds"):
		failures.append("Declarative runtime did not expose bounded sync state.")

	game.queue_free()
	if failures.is_empty():
		print("declarative minigame smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
