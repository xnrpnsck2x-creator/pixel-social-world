extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	root.size = Vector2i(844, 390)
	DisplayServer.window_set_size(Vector2i(844, 390))
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "local-test-player",
		"device_id": "test-device",
		"display_name": "Local Test",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	instance.call("_on_presence_updated", [
		{"player_id": "local-test-player", "display_name": "Local Test"},
		{"player_id": "remote-a", "display_name": "Remote A", "character_variant_id": "female_magic_v0"},
		{"player_id": "remote-b", "display_name": "Remote B", "character_variant_id": "male_ranged_v0"}
	], false, -1)
	await process_frame

	var remote_root := instance.get_node("PlayerRoot/RemotePlayers")
	if remote_root.get_child_count() != 2:
		failures.append("Expected 2 remote avatars, got %d." % remote_root.get_child_count())

	for child in remote_root.get_children():
		if child.get("input_enabled") != false:
			failures.append("Remote avatar input should be disabled.")
		if child.get_node_or_null("AvatarSprite") == null:
			failures.append("Remote avatar is missing AvatarSprite.")
		var name_label := child.get_node_or_null("NameLabel") as Label
		if name_label == null:
			failures.append("Remote avatar is missing NameLabel.")
		elif name_label.visible:
			failures.append("Remote avatar name should be hidden until selected.")
		var remote_sync = instance.get("_remote_player_sync")
		var safe_rect: Rect2 = remote_sync.call("_playable_world_rect")
		if not safe_rect.has_point(child.global_position):
			failures.append("Remote avatar spawned outside the playable safe rect.")
		if child.global_position.y < -16.0:
			failures.append("Remote avatar spawned too close to the mobile top HUD.")
		if not ["female_magic_v0", "male_ranged_v0"].has(str(child.get("character_variant_id"))):
			failures.append("Remote avatar did not apply its presence character variant.")

	var map_remote_sync = instance.get("_remote_player_sync")
	map_remote_sync.call("set_current_map_id", "city_forest_dawn_v1")
	map_remote_sync.call("apply_move", {
		"player_id": "remote-a",
		"display_name": "Remote A",
		"map_id": "city_port_market_v1",
		"position": {"x": 32, "y": 12},
		"facing": "down"
	}, "local-test-player")
	await process_frame
	if remote_root.get_child_count() != 1:
		failures.append("Remote avatar from another map should be removed from the current map.")
	map_remote_sync.call("apply_move", {
		"player_id": "remote-a",
		"display_name": "Remote A",
		"map_id": "city_forest_dawn_v1",
		"position": {"x": 32, "y": 12},
		"facing": "down"
	}, "local-test-player")
	await process_frame
	if remote_root.get_child_count() != 2:
		failures.append("Remote avatar from the current map should be visible again.")

	instance.call("_on_presence_updated", [
		{"player_id": "local-test-player", "display_name": "Local Test"},
		{"player_id": "remote-a", "display_name": "Remote A", "character_variant_id": "female_magic_v0"}
	], false, -1)
	await process_frame
	if remote_root.get_child_count() != 1:
		failures.append("Remote avatar cleanup did not remove stale members.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("remote players smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
