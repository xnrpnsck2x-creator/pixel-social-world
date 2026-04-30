extends SceneTree

const WorldStateSyncScript := preload("res://scripts/Network/Sync/WorldStateSync.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {"id": "sync-test-player", "coin_balance": 25, "coin_ledger": []})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var sync := Node.new()
	sync.set_script(WorldStateSyncScript)
	root.add_child(sync)
	sync.call("bind_local_player", instance.get_node("PlayerRoot/LocalPlayer"))
	var payload: Dictionary = sync.call("build_player_move_payload")

	for key in ["player_id", "room_id", "position", "velocity", "facing", "is_sitting", "is_attacking", "sent_at"]:
		if not payload.has(key):
			failures.append("player.move payload missing %s." % key)
	if payload.get("player_id") != "sync-test-player":
		failures.append("player.move payload used wrong player_id.")

	sync.queue_free()
	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("world state sync smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
