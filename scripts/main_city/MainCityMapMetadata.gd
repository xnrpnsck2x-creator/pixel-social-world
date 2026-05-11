class_name MainCityMapMetadata
extends RefCounted

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const VISUAL_GROUND_OFFSETS := [
	Vector2.ZERO,
	Vector2(-24.0, 0.0),
	Vector2(24.0, 0.0),
	Vector2(0.0, -8.0),
	Vector2(0.0, 18.0),
	Vector2(-16.0, 16.0),
	Vector2(16.0, 16.0)
]
const VISUAL_BLOCKED_FRONT_CLEARANCE := 24.0
const VISUAL_BLOCKED_X_PADDING := 12.0
const VISUAL_BLOCKED_TOP_PADDING := 8.0

var map_id := DEFAULT_MAP_ID
var metadata := {}
var canvas_size := Vector2.ZERO

func load_map(new_map_id: String = DEFAULT_MAP_ID) -> bool:
	map_id = new_map_id
	var config: Dictionary = ConfigLoader.load_config("map_points")
	var maps: Dictionary = config.get("maps", {}) as Dictionary
	metadata = maps.get(map_id, {}) as Dictionary
	var raw_size: Array = metadata.get("canvas_size", [])
	if raw_size.size() != 2:
		canvas_size = Vector2.ZERO
		return false
	canvas_size = Vector2(float(raw_size[0]), float(raw_size[1]))
	return canvas_size.x > 0.0 and canvas_size.y > 0.0

func spawn_world_position(spawn_id: String = "default", fallback := Vector2.ZERO) -> Vector2:
	return _world_position_from_section("spawn_points", spawn_id, fallback)

func npc_world_position(npc_id: String, fallback := Vector2.ZERO) -> Vector2:
	return _world_position_from_section("npc_points", "npc.%s" % npc_id, fallback)

func interaction_world_position(action_id: String, fallback := Vector2.ZERO) -> Vector2:
	return _world_position_from_section("interaction_points", action_id, fallback)

func has_interaction(action_id: String) -> bool:
	return not point_record("interaction_points", action_id).is_empty()

func has_npc(npc_id: String) -> bool:
	return not point_record("npc_points", "npc.%s" % npc_id).is_empty()

func interaction_records() -> Array:
	return _section_records("interaction_points")

func life_skill_records() -> Array:
	return _section_records("life_skill_nodes")

func camera_world_rect(spawn_id: String = "default") -> Rect2:
	var region := camera_region_record(spawn_id)
	if not region.is_empty():
		return _camera_rect_to_world(region)
	var bounds: Dictionary = metadata.get("camera_bounds", {}) as Dictionary
	if bounds.is_empty():
		return Rect2(-canvas_size * 0.5, canvas_size)
	return _camera_rect_to_world(bounds)

func camera_region_record(spawn_id: String) -> Dictionary:
	for region in metadata.get("camera_regions", []):
		if typeof(region) != TYPE_DICTIONARY:
			continue
		var spawn_ids: Array = (region as Dictionary).get("spawn_ids", []) as Array
		if spawn_ids.is_empty() or spawn_ids.has(spawn_id) or spawn_ids.has("*"):
			return region as Dictionary
	return {}

func _camera_rect_to_world(bounds: Dictionary) -> Rect2:
	var origin := point_to_world(bounds)
	return Rect2(origin, Vector2(
		float(bounds.get("width", canvas_size.x)),
		float(bounds.get("height", canvas_size.y))
	))

func _world_position_from_section(section: String, point_id: String, fallback: Vector2) -> Vector2:
	var point := point_record(section, point_id)
	if point.is_empty():
		return fallback
	return point_to_world(point)

func point_record(section: String, point_id: String) -> Dictionary:
	for point in metadata.get(section, []):
		if typeof(point) == TYPE_DICTIONARY and str((point as Dictionary).get("id", "")) == point_id:
			return point as Dictionary
	return {}

func _section_records(section: String) -> Array:
	var rows := []
	for point in metadata.get(section, []):
		if typeof(point) == TYPE_DICTIONARY:
			rows.append((point as Dictionary).duplicate(true))
	return rows

func point_to_world(point: Dictionary) -> Vector2:
	if canvas_size == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2(
		float(point.get("x", canvas_size.x * 0.5)) - canvas_size.x * 0.5,
		float(point.get("y", canvas_size.y * 0.5)) - canvas_size.y * 0.5
	)

func rect_to_world(rect: Dictionary) -> Rect2:
	return Rect2(point_to_world(rect), Vector2(float(rect.get("width", 0.0)), float(rect.get("height", 0.0))))

func world_to_image(world_position: Vector2) -> Vector2:
	return world_position + canvas_size * 0.5

func is_world_position_walkable(world_position: Vector2) -> bool:
	if canvas_size == Vector2.ZERO:
		return true
	var image_point := world_to_image(world_position)
	if image_point.x < 0.0 or image_point.y < 0.0 or image_point.x > canvas_size.x or image_point.y > canvas_size.y:
		return false
	if _has_rects("walkable_rects") and not _point_in_rects(image_point, "walkable_rects"):
		return false
	return not _point_in_rects(image_point, "blocked_rects")

func is_world_position_visually_grounded(world_position: Vector2) -> bool:
	for offset in VISUAL_GROUND_OFFSETS:
		if not is_world_position_walkable(world_position + offset):
			return false
	return true

func is_world_position_clear_of_blocked_art(world_position: Vector2, front_clearance := VISUAL_BLOCKED_FRONT_CLEARANCE) -> bool:
	var image_point := world_to_image(world_position)
	for rect in metadata.get("blocked_rects", []):
		if typeof(rect) != TYPE_DICTIONARY:
			continue
		if _point_is_in_blocked_visual_band(image_point, rect as Dictionary, front_clearance):
			return false
	return true

func _has_rects(section: String) -> bool:
	return (metadata.get(section, []) as Array).size() > 0

func _point_in_rects(point: Vector2, section: String) -> bool:
	for rect in metadata.get(section, []):
		if typeof(rect) != TYPE_DICTIONARY:
			continue
		var data := rect as Dictionary
		var x := float(data.get("x", 0.0))
		var y := float(data.get("y", 0.0))
		var width := float(data.get("width", 0.0))
		var height := float(data.get("height", 0.0))
		if point.x >= x and point.y >= y and point.x <= x + width and point.y <= y + height:
			return true
	return false

func _point_is_in_blocked_visual_band(point: Vector2, rect: Dictionary, front_clearance: float) -> bool:
	var x := float(rect.get("x", 0.0))
	var y := float(rect.get("y", 0.0))
	var width := float(rect.get("width", 0.0))
	var height := float(rect.get("height", 0.0))
	var horizontally_overlaps := point.x >= x - VISUAL_BLOCKED_X_PADDING and point.x <= x + width + VISUAL_BLOCKED_X_PADDING
	var vertically_too_close := point.y >= y - VISUAL_BLOCKED_TOP_PADDING and point.y < y + height + front_clearance
	return horizontally_overlaps and vertically_too_close
