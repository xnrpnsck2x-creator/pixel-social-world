extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const DIRECTIONS := ["down", "right", "up", "left"]
const FORMAL_DIRECTIONAL_VISUALS := {
	"fisher_v1": "npc_professions_life_direction_v1",
	"merchant_v1": "npc_professions_direction_v1",
	"mail_courier_v1": "npc_professions_direction_v1",
	"game_host_v1": "npc_professions_direction_v1",
	"home_keeper_v1": "npc_professions_direction_v1",
	"academy_registrar_v1": "npc_professions_direction_v1",
	"herbalist_v1": "npc_professions_life_direction_v1",
	"chef_guide_v1": "npc_professions_life_direction_v1"
}
const REQUIRED_NPC_FIELDS := [
	"name_key", "dialogue_key", "primary_action_id", "primary_action_key",
	"primary_icon_id", "avatar_id", "npc_visual_id", "role_key", "duty_key", "emote_id"
]
const FOCUS_MIN_NPCS := {
	"city_forest_dawn_v1": 5,
	"city_academy_plaza_v1": 2,
	"city_port_market_v1": 2,
	"social_housing_district_v1": 2,
	"social_minigame_arcade_hall_v1": 2,
	"social_trade_market_v1": 2,
	"social_guild_garden_v1": 2,
	"social_creator_gallery_v1": 1
}
const NPC_PAIR_MIN_DISTANCE := 92.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var loader := root.get_node("ConfigLoader")
	var point_maps: Dictionary = loader.call("load_config", "map_points").get("maps", {}) as Dictionary
	var npc_records := _npc_records()
	_assert_npc_catalog_quality(npc_records, failures)
	_assert_map_npc_points(point_maps, failures)
	await _assert_runtime_npc_visuals(point_maps, npc_records, failures)
	if failures.is_empty():
		print("map npc visual quality v2 smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _npc_records() -> Dictionary:
	var rows := {}
	var config: Dictionary = root.get_node("ConfigLoader").call("load_config", "main_city_npcs")
	for record in config.get("npcs", []):
		if typeof(record) == TYPE_DICTIONARY:
			rows[str((record as Dictionary).get("id", ""))] = record as Dictionary
	return rows

func _assert_npc_catalog_quality(npc_records: Dictionary, failures: Array[String]) -> void:
	var avatar_ids := {}
	for npc_id in npc_records.keys():
		var record: Dictionary = npc_records.get(npc_id, {}) as Dictionary
		for field in REQUIRED_NPC_FIELDS:
			if str(record.get(field, "")).is_empty():
				failures.append("main_city_npcs.%s is missing %s." % [npc_id, field])
		avatar_ids[str(record.get("avatar_id", ""))] = true
	for avatar_id in ["male_melee_v1", "male_ranged_v1", "male_magic_v1", "female_melee_v1", "female_ranged_v1", "female_magic_v1"]:
		if not avatar_ids.has(avatar_id):
			failures.append("main_city_npcs does not use avatar %s for NPC variety." % avatar_id)

func _assert_map_npc_points(point_maps: Dictionary, failures: Array[String]) -> void:
	for map_id in point_maps.keys():
		var metadata: Dictionary = point_maps.get(map_id, {}) as Dictionary
		var npcs := metadata.get("npc_points", []) as Array
		if FOCUS_MIN_NPCS.has(map_id) and npcs.size() < int(FOCUS_MIN_NPCS.get(map_id)):
			failures.append("%s has only %d NPCs for a focus social map." % [map_id, npcs.size()])
		_assert_map_npc_facing(str(map_id), npcs, failures)
		_assert_map_npc_spacing(str(map_id), npcs, failures)

func _assert_map_npc_facing(map_id: String, npcs: Array, failures: Array[String]) -> void:
	var facings := {}
	for raw_point in npcs:
		if typeof(raw_point) != TYPE_DICTIONARY:
			continue
		var point := raw_point as Dictionary
		var point_id := str(point.get("id", "unknown"))
		var facing := str(point.get("facing", ""))
		if not DIRECTIONS.has(facing):
			failures.append("%s.%s is missing a valid facing override." % [map_id, point_id])
		facings[facing] = true
	if npcs.size() >= 2 and facings.size() < 2:
		failures.append("%s NPC group needs mixed facing directions." % map_id)

func _assert_map_npc_spacing(map_id: String, npcs: Array, failures: Array[String]) -> void:
	for index in range(npcs.size()):
		if typeof(npcs[index]) != TYPE_DICTIONARY:
			continue
		var a := npcs[index] as Dictionary
		for next_index in range(index + 1, npcs.size()):
			if typeof(npcs[next_index]) != TYPE_DICTIONARY:
				continue
			var b := npcs[next_index] as Dictionary
			var distance := Vector2(float(a.get("x", 0)), float(a.get("y", 0))).distance_to(
				Vector2(float(b.get("x", 0)), float(b.get("y", 0)))
			)
			if distance < NPC_PAIR_MIN_DISTANCE:
				failures.append("%s NPCs %s and %s are too close: %.1f px." % [
					map_id,
					str(a.get("id", "a")),
					str(b.get("id", "b")),
					distance
				])

func _assert_runtime_npc_visuals(point_maps: Dictionary, npc_records: Dictionary, failures: Array[String]) -> void:
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-npc-visual-quality-v2",
		"display_name": "NPC Visual V2",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"discovered_world_map_ids": _maps_with_npcs(point_maps)
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	for map_id in _maps_with_npcs(point_maps):
		if map_id != str(instance.get("_map_runtime").get("current_map_id")):
			instance.call("_switch_world_map", map_id, "world.map_travel_generic")
			await process_frame
			await process_frame
		_assert_spawned_npcs(instance, map_id, point_maps.get(map_id, {}) as Dictionary, npc_records, failures)
	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

func _assert_spawned_npcs(
	instance: Node,
	map_id: String,
	metadata: Dictionary,
	npc_records: Dictionary,
	failures: Array[String]
) -> void:
	var npc_root := instance.get_node_or_null("MapRoot/NPCRoot")
	if npc_root == null:
		failures.append("%s is missing NPCRoot." % map_id)
		return
	for raw_point in metadata.get("npc_points", []) as Array:
		if typeof(raw_point) != TYPE_DICTIONARY:
			continue
		var point := raw_point as Dictionary
		var npc_id := str(point.get("id", "")).trim_prefix("npc.")
		if not npc_records.has(npc_id):
			failures.append("%s references unknown NPC %s." % [map_id, npc_id])
			continue
		var npc := npc_root.get_node_or_null(npc_id)
		if npc == null:
			failures.append("%s did not spawn NPC %s." % [map_id, npc_id])
			continue
		var expected_facing := str(point.get("facing", "down"))
		if str(npc.get("facing")) != expected_facing:
			failures.append("%s NPC %s ignored facing %s." % [map_id, npc_id, expected_facing])
		var npc_record := npc_records.get(npc_id, {}) as Dictionary
		_assert_npc_texture_direction(map_id, npc, expected_facing, str(npc_record.get("npc_visual_id", "")), failures)
		_assert_npc_ambience_pose_meta(map_id, npc, point, str(npc_record.get("npc_visual_id", "")), failures)

func _assert_npc_texture_direction(
	map_id: String,
	npc: Node,
	expected_facing: String,
	expected_visual_id: String,
	failures: Array[String]
) -> void:
	var sprite := npc.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null:
		failures.append("%s NPC %s has no runtime sprite texture." % [map_id, npc.name])
		return
	if sprite.flip_h:
		failures.append("%s NPC %s is still using horizontal flip instead of authored direction frames." % [map_id, npc.name])
		return
	var texture_path := str(sprite.texture.resource_path)
	if FORMAL_DIRECTIONAL_VISUALS.has(expected_visual_id) and not texture_path.contains(str(FORMAL_DIRECTIONAL_VISUALS.get(expected_visual_id))):
		failures.append("%s NPC %s did not use formal directional NPC art: %s." % [
			map_id,
			npc.name,
			texture_path
		])
	if expected_facing == "down":
		return
	if not texture_path.contains("idle_%s" % expected_facing):
		failures.append("%s NPC %s did not use directional avatar frame for %s: %s." % [
			map_id,
			npc.name,
			expected_facing,
			texture_path
		])

func _assert_npc_ambience_pose_meta(
	map_id: String,
	npc: Node,
	point: Dictionary,
	expected_visual_id: String,
	failures: Array[String]
) -> void:
	var expected_poses: Array = point.get("ambience_poses", []) as Array
	if expected_poses.is_empty():
		return
	if not npc.has_meta("ambience_poses"):
		failures.append("%s NPC %s did not receive point ambience pose metadata." % [map_id, npc.name])
		return
	var runtime_poses: Array = npc.get_meta("ambience_poses") as Array
	for pose in expected_poses:
		if not runtime_poses.has(pose):
			failures.append("%s NPC %s dropped ambience pose %s." % [map_id, npc.name, pose])
	_assert_ambience_pose_textures(map_id, npc, expected_poses, expected_visual_id, failures)

func _assert_ambience_pose_textures(
	map_id: String,
	npc: Node,
	poses: Array,
	expected_visual_id: String,
	failures: Array[String]
) -> void:
	var frames := _profession_frames(expected_visual_id)
	for pose in poses:
		for facing in DIRECTIONS:
			var frame_path := str(frames.get("%s_%s" % [pose, facing], ""))
			if frame_path.is_empty() or not ResourceLoader.exists(frame_path):
				failures.append("%s NPC %s ambience pose %s missing %s frame." % [
					map_id,
					npc.name,
					pose,
					facing
				])

func _profession_frames(visual_id: String) -> Dictionary:
	var config: Dictionary = root.get_node("ConfigLoader").call("load_config", "npc_professions")
	for role in config.get("roles", []):
		if typeof(role) == TYPE_DICTIONARY and str((role as Dictionary).get("id", "")) == visual_id:
			return (role as Dictionary).get("directional_frames", {}) as Dictionary
	return {}

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
