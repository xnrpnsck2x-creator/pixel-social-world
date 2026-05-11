extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-actor-depth-sort",
		"display_name": "Depth Smoke",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"discovered_world_map_ids": ["city_forest_dawn_v1"]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	_assert_depth_sort(instance, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map actor depth sort smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_depth_sort(instance: Node, failures: Array[String]) -> void:
	var sorter: Node = instance.get("_depth_sorter")
	var player := instance.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	var npc_root := instance.get_node_or_null("MapRoot/NPCRoot")
	var remote_root := instance.get_node_or_null("PlayerRoot/RemotePlayers")
	if sorter == null:
		failures.append("Main city did not install MainCityDepthSorter.")
		return
	if player == null or npc_root == null or remote_root == null or npc_root.get_child_count() < 2:
		failures.append("Main city depth sort smoke is missing actors.")
		return
	var front_npc := npc_root.get_child(0) as Node2D
	var back_npc := npc_root.get_child(1) as Node2D
	var remote := Node2D.new()
	remote.name = "DepthRemote"
	remote_root.add_child(remote)
	back_npc.global_position = Vector2(0, -120)
	player.global_position = Vector2(0, 0)
	front_npc.global_position = Vector2(0, 120)
	remote.global_position = Vector2(0, 180)
	sorter.call("sort_now")
	if back_npc.z_as_relative or player.z_as_relative or front_npc.z_as_relative or remote.z_as_relative:
		failures.append("Actor depth sorter must use absolute z for actors across different roots.")
	if not (back_npc.z_index < player.z_index and player.z_index < front_npc.z_index and front_npc.z_index < remote.z_index):
		failures.append("Actor depth sorter did not order actors by screen y.")
	var prompt := instance.get_node_or_null("MapRoot/Entrances/HomeGateHotspot/PromptLabel") as Label
	if prompt == null or prompt.z_as_relative or prompt.z_index < 1950:
		failures.append("Hotspot prompts should draw above y-sorted actors.")
	var backdrop := instance.get_node_or_null("MapRoot/MapBackdrop") as Sprite2D
	if backdrop == null or backdrop.z_index >= back_npc.z_index:
		failures.append("Map backdrop should remain behind y-sorted actors.")
	remote.queue_free()
