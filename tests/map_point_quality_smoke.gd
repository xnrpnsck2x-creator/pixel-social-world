extends SceneTree

const POINT_SECTIONS := ["spawn_points", "npc_points", "life_skill_nodes", "portals", "interaction_points"]
const CLEARANCE_RADIUS := 24.0
const MIN_CLEARANCE_SAMPLES := 5
const NPC_MIN_CLEARANCE_SAMPLES := 8
const NPC_MIN_BLOCKED_DISTANCE := 24.0
const NPC_BLOCKED_BASELINE_MARGIN := 48.0
const EDGE_SAFE_MARGIN := 72.0
const NPC_MIN_VISUAL_Y_RATIO := 0.30
const INTERACTIVE_MIN_VISUAL_Y_RATIO := 0.20

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var point_config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var maps: Dictionary = point_config.get("maps", {}) as Dictionary
	for map_id in maps.keys():
		_assert_map_points(str(map_id), maps.get(map_id, {}) as Dictionary, maps, failures)
	if failures.is_empty():
		print("map point quality smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_map_points(map_id: String, metadata: Dictionary, maps: Dictionary, failures: Array[String]) -> void:
	var canvas_size := metadata.get("canvas_size", []) as Array
	if canvas_size.size() != 2:
		failures.append("%s is missing canvas_size." % map_id)
		return
	var width := float(canvas_size[0])
	var height := float(canvas_size[1])
	var walkable_rects := metadata.get("walkable_rects", []) as Array
	var blocked_rects := metadata.get("blocked_rects", []) as Array
	_assert_map_content_density(map_id, metadata, failures)
	for section in POINT_SECTIONS:
		for point in metadata.get(section, []) as Array:
			if typeof(point) != TYPE_DICTIONARY:
				continue
			var record := point as Dictionary
			_assert_point_schema(map_id, section, record, width, height, failures)
			_assert_point_edge_margin(map_id, section, record, width, height, failures)
			_assert_point_clearance(map_id, section, record, width, height, walkable_rects, blocked_rects, failures)
			if section == "npc_points":
				_assert_npc_blocked_baseline(map_id, record, blocked_rects, failures)
				_assert_npc_visual_grounding(map_id, record, height, failures)
			elif section in ["life_skill_nodes", "portals", "interaction_points"]:
				_assert_interactive_visual_grounding(map_id, section, record, height, failures)
			if section == "portals":
				_assert_portal_target(map_id, record, maps, failures)

func _assert_map_content_density(map_id: String, metadata: Dictionary, failures: Array[String]) -> void:
	var npc_count := (metadata.get("npc_points", []) as Array).size()
	if npc_count < 1:
		failures.append("%s needs at least one NPC guide or activity anchor." % map_id)

func _assert_point_schema(
	map_id: String,
	section: String,
	point: Dictionary,
	width: float,
	height: float,
	failures: Array[String]
) -> void:
	var point_id := str(point.get("id", ""))
	if point_id.is_empty():
		failures.append("%s.%s contains a point without id." % [map_id, section])
	var x := float(point.get("x", -1))
	var y := float(point.get("y", -1))
	if x < 0.0 or y < 0.0 or x > width or y > height:
		failures.append("%s.%s.%s is outside canvas bounds." % [map_id, section, point_id])
	if section in ["life_skill_nodes", "interaction_points"]:
		var action := str(point.get("action", point.get("type", "")))
		if action.is_empty():
			failures.append("%s.%s.%s is missing action/type routing." % [map_id, section, point_id])

func _assert_point_edge_margin(
	map_id: String,
	section: String,
	point: Dictionary,
	width: float,
	height: float,
	failures: Array[String]
) -> void:
	var point_id := str(point.get("id", ""))
	var x := float(point.get("x", -1))
	var y := float(point.get("y", -1))
	if x < EDGE_SAFE_MARGIN or y < EDGE_SAFE_MARGIN or x > width - EDGE_SAFE_MARGIN or y > height - EDGE_SAFE_MARGIN:
		failures.append("%s.%s.%s is too close to the map edge for mobile touch." % [map_id, section, point_id])

func _assert_point_clearance(
	map_id: String,
	section: String,
	point: Dictionary,
	width: float,
	height: float,
	walkable_rects: Array,
	blocked_rects: Array,
	failures: Array[String]
) -> void:
	var point_id := str(point.get("id", ""))
	var x := float(point.get("x", -1))
	var y := float(point.get("y", -1))
	var offsets := [
		Vector2.ZERO,
		Vector2(-CLEARANCE_RADIUS, 0.0),
		Vector2(CLEARANCE_RADIUS, 0.0),
		Vector2(0.0, -CLEARANCE_RADIUS),
		Vector2(0.0, CLEARANCE_RADIUS),
		Vector2(-CLEARANCE_RADIUS, -CLEARANCE_RADIUS),
		Vector2(CLEARANCE_RADIUS, -CLEARANCE_RADIUS),
		Vector2(-CLEARANCE_RADIUS, CLEARANCE_RADIUS),
		Vector2(CLEARANCE_RADIUS, CLEARANCE_RADIUS)
	]
	var samples := 0
	if not _is_walkable(Vector2(x, y), width, height, walkable_rects, blocked_rects):
		failures.append("%s.%s.%s center is not walkable." % [map_id, section, point_id])
	for offset in offsets:
		if _is_walkable(Vector2(x, y) + offset, width, height, walkable_rects, blocked_rects):
			samples += 1
	var required_samples := NPC_MIN_CLEARANCE_SAMPLES if section == "npc_points" else MIN_CLEARANCE_SAMPLES
	if samples < required_samples:
		failures.append("%s.%s.%s has only %d walkable clearance samples." % [map_id, section, point_id, samples])
	if section == "npc_points":
		var blocked_distance := _distance_to_nearest_rect(Vector2(x, y), blocked_rects)
		if blocked_distance < NPC_MIN_BLOCKED_DISTANCE:
			failures.append("%s.%s.%s is %.1f px from blocked art." % [map_id, section, point_id, blocked_distance])

func _assert_npc_blocked_baseline(
	map_id: String,
	point: Dictionary,
	blocked_rects: Array,
	failures: Array[String]
) -> void:
	var point_id := str(point.get("id", ""))
	var x := float(point.get("x", -1))
	var y := float(point.get("y", -1))
	for rect_record in blocked_rects:
		if typeof(rect_record) != TYPE_DICTIONARY:
			continue
		var rect := rect_record as Dictionary
		var rect_x := float(rect.get("x", 0.0))
		var rect_y := float(rect.get("y", 0.0))
		var rect_width := float(rect.get("width", 0.0))
		var rect_height := float(rect.get("height", 0.0))
		if x < rect_x or x > rect_x + rect_width:
			continue
		var blocked_bottom := rect_y + rect_height
		if y >= rect_y - CLEARANCE_RADIUS and y < blocked_bottom + NPC_BLOCKED_BASELINE_MARGIN:
			failures.append("%s.npc_points.%s baseline is too close to blocked art %s." % [
				map_id,
				point_id,
				str(rect.get("id", "unknown"))
			])

func _assert_npc_visual_grounding(map_id: String, point: Dictionary, height: float, failures: Array[String]) -> void:
	var point_id := str(point.get("id", ""))
	var y := float(point.get("y", -1))
	if y / height < NPC_MIN_VISUAL_Y_RATIO:
		failures.append("%s.npc_points.%s is too high in the decorative/building band." % [map_id, point_id])

func _assert_interactive_visual_grounding(
	map_id: String,
	section: String,
	point: Dictionary,
	height: float,
	failures: Array[String]
) -> void:
	var point_id := str(point.get("id", ""))
	var y := float(point.get("y", -1))
	if y / height < INTERACTIVE_MIN_VISUAL_Y_RATIO:
		failures.append("%s.%s.%s is too high to read as a grounded interaction." % [map_id, section, point_id])

func _assert_portal_target(map_id: String, point: Dictionary, maps: Dictionary, failures: Array[String]) -> void:
	var point_id := str(point.get("id", ""))
	var target_map := str(point.get("target_map", ""))
	if target_map.is_empty():
		failures.append("%s.portals.%s is missing target_map." % [map_id, point_id])
	elif not maps.has(target_map):
		failures.append("%s.portals.%s points to unknown map %s." % [map_id, point_id, target_map])

func _is_walkable(point: Vector2, width: float, height: float, walkable_rects: Array, blocked_rects: Array) -> bool:
	if point.x < 0.0 or point.y < 0.0 or point.x > width or point.y > height:
		return false
	if not walkable_rects.is_empty() and not _point_in_rects(point, walkable_rects):
		return false
	if _point_in_rects(point, blocked_rects):
		return false
	return true

func _point_in_rects(point: Vector2, rects: Array) -> bool:
	for rect_record in rects:
		if typeof(rect_record) != TYPE_DICTIONARY:
			continue
		var rect := rect_record as Dictionary
		var x := float(rect.get("x", 0))
		var y := float(rect.get("y", 0))
		var width := float(rect.get("width", 0))
		var height := float(rect.get("height", 0))
		if point.x >= x and point.y >= y and point.x <= x + width and point.y <= y + height:
			return true
	return false

func _distance_to_nearest_rect(point: Vector2, rects: Array) -> float:
	var best := 999999.0
	for rect_record in rects:
		if typeof(rect_record) != TYPE_DICTIONARY:
			continue
		var rect := rect_record as Dictionary
		var x := float(rect.get("x", 0))
		var y := float(rect.get("y", 0))
		var width := float(rect.get("width", 0))
		var height := float(rect.get("height", 0))
		if point.x >= x and point.y >= y and point.x <= x + width and point.y <= y + height:
			return -1.0
		var dx = max(max(x - point.x, 0.0), point.x - (x + width))
		var dy = max(max(y - point.y, 0.0), point.y - (y + height))
		best = min(best, Vector2(dx, dy).length())
	return best
