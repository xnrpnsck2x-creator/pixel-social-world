extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const POINT_SECTIONS := ["spawn_points", "npc_points", "life_skill_nodes", "portals", "interaction_points"]
const VISUAL_GROUND_SECTIONS := ["npc_points"]
const COLLISION_DELTA := 0.20
const EDGE_PROBE_OFFSET := 8.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-collision-patrol",
		"display_name": "Map Collision Smoke",
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

	for map_id in _stable_map_ids(point_maps):
		if map_id != str(instance.get("_map_runtime").get("current_map_id")):
			instance.call("_switch_world_map", map_id, "world.map_travel_generic")
			await process_frame
			await process_frame
		_assert_map_collision(instance, map_id, point_maps.get(map_id, {}) as Dictionary, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map collision patrol smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _stable_map_ids(point_maps: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for map_id in point_maps.keys():
		rows.append(str(map_id))
	rows.sort()
	if rows.has(DEFAULT_MAP_ID):
		rows.erase(DEFAULT_MAP_ID)
		rows.push_front(DEFAULT_MAP_ID)
	return rows

func _assert_map_collision(instance: Node, map_id: String, map_config: Dictionary, failures: Array[String]) -> void:
	var map_runtime = instance.get("_map_runtime")
	var map_metadata = instance.get("_map_metadata")
	var player := instance.get_node_or_null("PlayerRoot/LocalPlayer")
	if map_runtime == null or str(map_runtime.get("current_map_id")) != map_id:
		failures.append("%s did not become the active runtime map." % map_id)
		return
	if map_metadata == null:
		failures.append("%s did not expose runtime map metadata." % map_id)
		return
	if player == null:
		failures.append("%s is missing the local player for collision patrol." % map_id)
		return
	if not bool(player.call("can_enter_world_position", player.global_position)):
		failures.append("%s active spawn is rejected by the player movement validator." % map_id)
	_assert_config_points_are_walkable(map_id, map_metadata, player, map_config, failures)
	_assert_blocked_rects_are_denied(map_id, map_metadata, player, map_config, failures)
	_assert_canvas_edges_are_denied(map_id, map_metadata, player, map_config, failures)
	_assert_player_cannot_step_into_blocked_art(map_id, map_metadata, player, map_config, failures)

func _assert_config_points_are_walkable(
	map_id: String,
	map_metadata,
	player: Node,
	map_config: Dictionary,
	failures: Array[String]
) -> void:
	for section in POINT_SECTIONS:
		for record in map_config.get(section, []) as Array:
			if typeof(record) != TYPE_DICTIONARY:
				continue
			var point := record as Dictionary
			var world_position: Vector2 = map_metadata.call("point_to_world", point)
			if not bool(player.call("can_enter_world_position", world_position)):
				failures.append("%s.%s.%s is not walkable at runtime." % [
					map_id,
					section,
					str(point.get("id", "unknown"))
				])
			if VISUAL_GROUND_SECTIONS.has(section) and not bool(map_metadata.call("is_world_position_visually_grounded", world_position)):
				failures.append("%s.%s.%s lacks enough visual foot-room at runtime." % [
					map_id,
					section,
					str(point.get("id", "unknown"))
				])
			if VISUAL_GROUND_SECTIONS.has(section) and not bool(map_metadata.call("is_world_position_clear_of_blocked_art", world_position)):
				failures.append("%s.%s.%s is too close to roof/building blocked art." % [
					map_id,
					section,
					str(point.get("id", "unknown"))
				])

func _assert_blocked_rects_are_denied(
	map_id: String,
	map_metadata,
	player: Node,
	map_config: Dictionary,
	failures: Array[String]
) -> void:
	var blocked_rects := map_config.get("blocked_rects", []) as Array
	if blocked_rects.is_empty():
		failures.append("%s has no blocked art rects for runtime collision." % map_id)
		return
	for record in blocked_rects:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var rect := record as Dictionary
		var center := _rect_center(rect)
		var world_position: Vector2 = map_metadata.call("point_to_world", {"x": center.x, "y": center.y})
		if bool(player.call("can_enter_world_position", world_position)):
			failures.append("%s blocked rect %s can be entered at its center." % [
				map_id,
				str(rect.get("id", "unknown"))
			])

func _assert_canvas_edges_are_denied(
	map_id: String,
	map_metadata,
	player: Node,
	map_config: Dictionary,
	failures: Array[String]
) -> void:
	var canvas := map_config.get("canvas_size", []) as Array
	if canvas.size() != 2:
		failures.append("%s is missing canvas size for runtime edge collision." % map_id)
		return
	var width := float(canvas[0])
	var height := float(canvas[1])
	for point in [
		Vector2(-8.0, height * 0.5),
		Vector2(width + 8.0, height * 0.5),
		Vector2(width * 0.5, -8.0),
		Vector2(width * 0.5, height + 8.0)
	]:
		var world_position: Vector2 = map_metadata.call("point_to_world", {"x": point.x, "y": point.y})
		if bool(player.call("can_enter_world_position", world_position)):
			failures.append("%s allows walking outside generated canvas at %s." % [map_id, str(point)])

func _assert_player_cannot_step_into_blocked_art(
	map_id: String,
	map_metadata,
	player: Node,
	map_config: Dictionary,
	failures: Array[String]
) -> void:
	var checked := 0
	for record in map_config.get("blocked_rects", []) as Array:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var rect := record as Dictionary
		var probe := _entry_probe(map_metadata, player, rect)
		if probe.is_empty():
			continue
		player.global_position = probe.get("start_world", Vector2.ZERO)
		var direction: Vector2 = probe.get("direction", Vector2.ZERO)
		var velocity: Vector2 = player.call("_validated_velocity", direction, COLLISION_DELTA)
		var next_position: Vector2 = player.global_position + velocity * COLLISION_DELTA
		if not bool(player.call("can_enter_world_position", next_position)):
			failures.append("%s movement validator returned a blocked next position for %s." % [
				map_id,
				str(rect.get("id", "unknown"))
			])
		if velocity.dot(direction) > 0.01:
			failures.append("%s player can step forward into blocked art %s." % [
				map_id,
				str(rect.get("id", "unknown"))
			])
		checked += 1
	if checked == 0:
		failures.append("%s has no reachable blocked edge probe for player movement." % map_id)

func _entry_probe(map_metadata, player: Node, rect: Dictionary) -> Dictionary:
	var x := float(rect.get("x", 0.0))
	var y := float(rect.get("y", 0.0))
	var width := float(rect.get("width", 0.0))
	var height := float(rect.get("height", 0.0))
	var center := _rect_center(rect)
	var move_distance := float(player.get("speed")) * COLLISION_DELTA
	var probes := [
		{"start": Vector2(x - EDGE_PROBE_OFFSET, center.y), "direction": Vector2.RIGHT},
		{"start": Vector2(x + width + EDGE_PROBE_OFFSET, center.y), "direction": Vector2.LEFT},
		{"start": Vector2(center.x, y - EDGE_PROBE_OFFSET), "direction": Vector2.DOWN},
		{"start": Vector2(center.x, y + height + EDGE_PROBE_OFFSET), "direction": Vector2.UP}
	]
	for probe in probes:
		var start_image: Vector2 = probe.get("start", Vector2.ZERO)
		var direction: Vector2 = probe.get("direction", Vector2.ZERO)
		var start_world: Vector2 = map_metadata.call("point_to_world", {"x": start_image.x, "y": start_image.y})
		var end_world: Vector2 = start_world + direction * move_distance
		if bool(map_metadata.call("is_world_position_walkable", start_world)) and not bool(map_metadata.call("is_world_position_walkable", end_world)):
			return {"start_world": start_world, "direction": direction}
	return {}

func _rect_center(rect: Dictionary) -> Vector2:
	return Vector2(
		float(rect.get("x", 0.0)) + float(rect.get("width", 0.0)) * 0.5,
		float(rect.get("y", 0.0)) + float(rect.get("height", 0.0)) * 0.5
	)
