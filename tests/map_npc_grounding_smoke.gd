extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const BASELINE_RULES := {
	"city_forest_dawn_v1:npc.mail_courier": 470.0,
	"city_forest_dawn_v1:npc.merchant": 420.0,
	"city_forest_dawn_v1:npc.game_host": 455.0
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-npc-grounding",
		"display_name": "Map NPC Smoke",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"discovered_world_map_ids": [DEFAULT_MAP_ID]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var point_config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var point_maps: Dictionary = point_config.get("maps", {}) as Dictionary
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	for map_id in _maps_with_npcs(point_maps):
		if map_id != DEFAULT_MAP_ID:
			instance.call("_switch_world_map", map_id, "world.map_travel_generic")
			await process_frame
			await process_frame
		_assert_map_npcs(instance, map_id, point_maps.get(map_id, {}) as Dictionary, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map npc grounding smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _maps_with_npcs(point_maps: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for map_id in point_maps.keys():
		var metadata: Dictionary = point_maps.get(map_id, {}) as Dictionary
		if (metadata.get("npc_points", []) as Array).size() > 0:
			rows.append(str(map_id))
	rows.sort()
	if rows.has(DEFAULT_MAP_ID):
		rows.erase(DEFAULT_MAP_ID)
		rows.push_front(DEFAULT_MAP_ID)
	return rows

func _assert_map_npcs(instance: Node, map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	var npc_root := instance.get_node_or_null("MapRoot/NPCRoot")
	var map_metadata = instance.get("_map_metadata")
	if npc_root == null:
		failures.append("%s is missing NPCRoot." % map_id)
		return
	if map_metadata == null:
		failures.append("%s did not expose runtime metadata." % map_id)
		return
	var expected := _expected_npc_ids(metadata)
	var spawned := _spawned_npc_ids(npc_root)
	for npc_id in expected.keys():
		if not spawned.has(npc_id):
			failures.append("%s did not spawn NPC %s." % [map_id, npc_id])
	for spawned_id in spawned.keys():
		if not expected.has(spawned_id):
			failures.append("%s spawned NPC %s without a map point." % [map_id, spawned_id])
	_assert_spawned_positions(map_id, npc_root, map_metadata, failures)
	_assert_spawned_visuals(map_id, npc_root, failures)

func _expected_npc_ids(metadata: Dictionary) -> Dictionary:
	var expected := {}
	for point in metadata.get("npc_points", []):
		if typeof(point) != TYPE_DICTIONARY:
			continue
		var point_id := str((point as Dictionary).get("id", ""))
		if point_id.begins_with("npc."):
			expected[point_id.substr(4)] = true
	return expected

func _spawned_npc_ids(npc_root: Node) -> Dictionary:
	var spawned := {}
	for child in npc_root.get_children():
		spawned[str(child.name)] = true
	return spawned

func _assert_spawned_positions(map_id: String, npc_root: Node, map_metadata, failures: Array[String]) -> void:
	if not map_metadata.has_method("is_world_position_visually_grounded"):
		failures.append("%s runtime metadata is missing visual grounding checks." % map_id)
		return
	if not map_metadata.has_method("is_world_position_clear_of_blocked_art"):
		failures.append("%s runtime metadata is missing blocked-art visual clearance checks." % map_id)
		return
	for child in npc_root.get_children():
		var npc := child as Node2D
		if npc == null:
			continue
		if not bool(map_metadata.call("is_world_position_walkable", npc.position)):
			failures.append("%s NPC %s is not on walkable ground." % [map_id, npc.name])
			continue
		if not bool(map_metadata.call("is_world_position_visually_grounded", npc.position)):
			failures.append("%s NPC %s lacks enough visual foot-room around its baseline." % [map_id, npc.name])
		if not bool(map_metadata.call("is_world_position_clear_of_blocked_art", npc.position)):
			failures.append("%s NPC %s is too visually close to roof/building blocked art." % [map_id, npc.name])
		var image_point: Vector2 = map_metadata.call("world_to_image", npc.position)
		var baseline_key := "%s:npc.%s" % [map_id, str(npc.name)]
		if BASELINE_RULES.has(baseline_key) and image_point.y < float(BASELINE_RULES[baseline_key]):
			failures.append("%s NPC %s is too high visually: y %.1f." % [map_id, npc.name, image_point.y])

func _assert_spawned_visuals(map_id: String, npc_root: Node, failures: Array[String]) -> void:
	for child in npc_root.get_children():
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			failures.append("%s NPC %s has no formal texture." % [map_id, child.name])
		if str(child.get("npc_visual_id")).is_empty():
			failures.append("%s NPC %s is missing a formal NPC profession visual." % [map_id, child.name])
		if str(child.get("avatar_id")).is_empty():
			failures.append("%s NPC %s is missing a formal avatar profile." % [map_id, child.name])
		var shadow := child.get_node_or_null("Shadow") as Polygon2D
		if shadow == null or not shadow.visible:
			failures.append("%s NPC %s is missing a grounding shadow." % [map_id, child.name])
