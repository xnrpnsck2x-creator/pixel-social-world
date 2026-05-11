extends SceneTree

const MIN_CAPACITY := 4
const MIN_WIDTH := 96.0
const MIN_HEIGHT := 72.0
const EDGE_SAFE_MARGIN := 48.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var point_config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var maps: Dictionary = point_config.get("maps", {}) as Dictionary
	for map_id in maps.keys():
		_assert_map_gathering_zones(str(map_id), maps.get(map_id, {}) as Dictionary, failures)
	if failures.is_empty():
		print("map gathering zone quality smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_map_gathering_zones(map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	var canvas_size := metadata.get("canvas_size", []) as Array
	if canvas_size.size() != 2:
		failures.append("%s is missing canvas_size." % map_id)
		return
	var width := float(canvas_size[0])
	var height := float(canvas_size[1])
	var walkable_rects := metadata.get("walkable_rects", []) as Array
	var blocked_rects := metadata.get("blocked_rects", []) as Array
	for raw_zone in metadata.get("gathering_zones", []) as Array:
		if typeof(raw_zone) != TYPE_DICTIONARY:
			failures.append("%s.gathering_zones contains a non-object record." % map_id)
			continue
		_assert_zone(map_id, raw_zone as Dictionary, width, height, walkable_rects, blocked_rects, failures)

func _assert_zone(
	map_id: String,
	zone: Dictionary,
	width: float,
	height: float,
	walkable_rects: Array,
	blocked_rects: Array,
	failures: Array[String]
) -> void:
	var zone_id := str(zone.get("id", ""))
	if zone_id.is_empty():
		failures.append("%s.gathering_zones contains a zone without id." % map_id)
	var rect := Rect2(
		Vector2(float(zone.get("x", -1.0)), float(zone.get("y", -1.0))),
		Vector2(float(zone.get("width", 0.0)), float(zone.get("height", 0.0)))
	)
	if rect.size.x < MIN_WIDTH or rect.size.y < MIN_HEIGHT:
		failures.append("%s.gathering_zones.%s is too small for a visible social rest zone." % [map_id, zone_id])
	if int(zone.get("capacity", 0)) < MIN_CAPACITY:
		failures.append("%s.gathering_zones.%s capacity is too low." % [map_id, zone_id])
	var canvas_rect := Rect2(Vector2.ZERO, Vector2(width, height)).grow(-EDGE_SAFE_MARGIN)
	if not canvas_rect.encloses(rect):
		failures.append("%s.gathering_zones.%s is too close to the map edge." % [map_id, zone_id])
	var center := rect.get_center()
	if not _is_walkable(center, width, height, walkable_rects, blocked_rects):
		failures.append("%s.gathering_zones.%s center is not walkable." % [map_id, zone_id])
	for sample in _zone_samples(rect):
		if _point_in_rects(sample, blocked_rects):
			failures.append("%s.gathering_zones.%s overlaps blocked decorative art." % [map_id, zone_id])
			return

func _zone_samples(rect: Rect2) -> Array[Vector2]:
	return [
		rect.get_center(),
		rect.position + rect.size * Vector2(0.25, 0.25),
		rect.position + rect.size * Vector2(0.75, 0.25),
		rect.position + rect.size * Vector2(0.25, 0.75),
		rect.position + rect.size * Vector2(0.75, 0.75)
	]

func _is_walkable(point: Vector2, width: float, height: float, walkable_rects: Array, blocked_rects: Array) -> bool:
	if point.x < 0.0 or point.y < 0.0 or point.x > width or point.y > height:
		return false
	if not walkable_rects.is_empty() and not _point_in_rects(point, walkable_rects):
		return false
	return not _point_in_rects(point, blocked_rects)

func _point_in_rects(point: Vector2, rects: Array) -> bool:
	for raw_rect in rects:
		if typeof(raw_rect) != TYPE_DICTIONARY:
			continue
		var record := raw_rect as Dictionary
		var rect := Rect2(
			Vector2(float(record.get("x", 0.0)), float(record.get("y", 0.0))),
			Vector2(float(record.get("width", 0.0)), float(record.get("height", 0.0)))
		)
		if rect.has_point(point):
			return true
	return false
