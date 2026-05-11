extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const TRAVEL_STATUSES := ["route_exposed", "playtest_candidate"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var catalog: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_catalog")
	var point_config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var point_maps: Dictionary = point_config.get("maps", {}) as Dictionary
	var generated := _generated_maps(catalog)
	if generated.size() < 9:
		failures.append("Expected at least 9 Image2 generated maps in the first playable batch.")
	if not generated.has(DEFAULT_MAP_ID):
		failures.append("Generated map batch must include the Forest Dawn default map.")
	for map_id in generated:
		_assert_generated_contract(map_id, catalog, point_maps, failures)
	if failures.is_empty():
		print("map production contract smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _generated_maps(catalog: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for record in catalog.get("maps", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var map_record := record as Dictionary
		if not str(map_record.get("asset_path", "")).is_empty() and not str(map_record.get("metadata_path", "")).is_empty():
			rows.append(str(map_record.get("id", "")))
	return rows

func _assert_generated_contract(map_id: String, catalog: Dictionary, point_maps: Dictionary, failures: Array[String]) -> void:
	var record := _record_for_map(catalog, map_id)
	if not TRAVEL_STATUSES.has(str(record.get("status", ""))):
		failures.append("%s has generated assets but is not travelable/playtestable." % map_id)
	var metadata: Dictionary = point_maps.get(map_id, {}) as Dictionary
	if metadata.is_empty():
		failures.append("%s metadata did not load." % map_id)
		return
	_assert_default_spawn(map_id, metadata, failures)
	_assert_interactions(map_id, metadata, failures)
	_assert_portals(map_id, metadata, failures)

func _assert_default_spawn(map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	var spawn := _point_record(metadata, "spawn_points", "default")
	if spawn.is_empty():
		failures.append("%s is missing a default spawn point." % map_id)
	elif not _is_point_walkable(metadata, spawn):
		failures.append("%s default spawn is not walkable." % map_id)

func _assert_interactions(map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	for point in metadata.get("interaction_points", []):
		if typeof(point) != TYPE_DICTIONARY:
			continue
		var row := point as Dictionary
		var action_id := str(row.get("id", ""))
		if str(row.get("action", "")).is_empty():
			failures.append("%s interaction %s is missing an action." % [map_id, action_id])
		if not _is_point_walkable(metadata, row):
			failures.append("%s interaction %s is not walkable." % [map_id, action_id])

func _assert_portals(map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	var portals: Array = metadata.get("portals", [])
	if map_id != DEFAULT_MAP_ID and _portal_target_count(portals, DEFAULT_MAP_ID) == 0:
		failures.append("%s must include a return portal to Forest Dawn." % map_id)
	for portal in portals:
		if typeof(portal) != TYPE_DICTIONARY:
			continue
		var row := portal as Dictionary
		var portal_id := str(row.get("id", ""))
		if str(row.get("target_map", "")).is_empty():
			failures.append("%s portal %s is missing target_map." % [map_id, portal_id])
		if not _is_point_walkable(metadata, row):
			failures.append("%s portal %s is not walkable." % [map_id, portal_id])

func _point_record(metadata: Dictionary, section: String, point_id: String) -> Dictionary:
	for point in metadata.get(section, []):
		if typeof(point) == TYPE_DICTIONARY and str((point as Dictionary).get("id", "")) == point_id:
			return point as Dictionary
	return {}

func _is_point_walkable(metadata: Dictionary, point: Dictionary) -> bool:
	var image_point := Vector2(float(point.get("x", -1.0)), float(point.get("y", -1.0)))
	var canvas_size := metadata.get("canvas_size", []) as Array
	if canvas_size.size() != 2:
		return false
	if image_point.x < 0.0 or image_point.y < 0.0:
		return false
	if image_point.x > float(canvas_size[0]) or image_point.y > float(canvas_size[1]):
		return false
	var walkable_rects: Array[Dictionary] = _rects(metadata, "walkable_rects")
	if not walkable_rects.is_empty() and not _point_in_rects(image_point, walkable_rects):
		return false
	return not _point_in_rects(image_point, _rects(metadata, "blocked_rects"))

func _rects(metadata: Dictionary, section: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rect in metadata.get(section, []):
		if typeof(rect) == TYPE_DICTIONARY:
			rows.append(rect as Dictionary)
	return rows

func _point_in_rects(point: Vector2, rects: Array[Dictionary]) -> bool:
	for rect in rects:
		var x := float(rect.get("x", 0.0))
		var y := float(rect.get("y", 0.0))
		var width := float(rect.get("width", 0.0))
		var height := float(rect.get("height", 0.0))
		if point.x >= x and point.y >= y and point.x <= x + width and point.y <= y + height:
			return true
	return false

func _portal_target_count(portals: Array, target_map: String) -> int:
	var count := 0
	for portal in portals:
		if typeof(portal) == TYPE_DICTIONARY and str((portal as Dictionary).get("target_map", "")) == target_map:
			count += 1
	return count

func _record_for_map(catalog: Dictionary, map_id: String) -> Dictionary:
	for record in catalog.get("maps", []):
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == map_id:
			return record as Dictionary
	return {}
