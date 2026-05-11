extends SceneTree

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const DYNAMIC_ROOT := "MapRoot/InteractionPoints/DynamicMapActivityHotspots"
const POINT_SECTIONS := ["spawn_points", "npc_points", "life_skill_nodes", "portals", "interaction_points"]
const VIEWPORTS := [
	{"id": "desktop", "size": Vector2(1280, 720), "top": 96.0, "bottom": 92.0, "side": 20.0},
	{"id": "mobile", "size": Vector2(844, 390), "top": 56.0, "bottom": 76.0, "side": 14.0}
]
const ROUTE_STEP := 24.0
const NEAREST_CELL_RADIUS := 4
const ARTIFACT_DIR := "res://.tools/map-interaction-quality-v2"

var _report_rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-interaction-quality-v2",
		"display_name": "Map Quality V2",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"discovered_world_map_ids": _all_map_ids()
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame

	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	for map_id in _stable_map_ids(maps):
		if map_id != str(instance.get("_map_runtime").get("current_map_id")):
			instance.call("_switch_world_map", map_id, "world.map_travel_generic")
			await process_frame
			await process_frame
		_assert_map_quality(instance, map_id, maps.get(map_id, {}) as Dictionary, failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	_write_report(failures)
	if failures.is_empty():
		print("map interaction quality v2 smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_map_quality(instance: Node, map_id: String, map_config: Dictionary, failures: Array[String]) -> void:
	var metadata = instance.get("_map_metadata")
	var player := instance.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	var camera := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	var row := {"map": map_id, "route_targets": 0, "dynamic_markers": 0, "screen_checks": 0}
	if metadata == null or player == null or camera == null:
		failures.append("%s is missing runtime metadata, player, or camera." % map_id)
		_report_rows.append(row)
		return
	row["route_targets"] = _assert_reachable_points(map_id, map_config, failures)
	row["screen_checks"] = _assert_hotspot_screen_safety(instance, map_id, camera, failures)
	row["dynamic_markers"] = _dynamic_marker_count(instance)
	_report_rows.append(row)

func _assert_reachable_points(map_id: String, map_config: Dictionary, failures: Array[String]) -> int:
	var canvas := map_config.get("canvas_size", []) as Array
	if canvas.size() != 2:
		failures.append("%s is missing canvas_size for reachability." % map_id)
		return 0
	var width := float(canvas[0])
	var height := float(canvas[1])
	var walkable := map_config.get("walkable_rects", []) as Array
	var blocked := map_config.get("blocked_rects", []) as Array
	var spawn := _spawn_point(map_config)
	if spawn.is_empty():
		failures.append("%s has no default or fallback spawn point." % map_id)
		return 0
	var start := _nearest_walkable_cell(_point_vec(spawn), width, height, walkable, blocked)
	if start == Vector2i(-1, -1):
		failures.append("%s spawn has no nearby walkable route cell." % map_id)
		return 0
	var reachable := _reachable_cells(start, width, height, walkable, blocked)
	var checked := 0
	for section in POINT_SECTIONS:
		for raw_point in map_config.get(section, []) as Array:
			if typeof(raw_point) != TYPE_DICTIONARY:
				continue
			var point := raw_point as Dictionary
			var target := _nearest_walkable_cell(_point_vec(point), width, height, walkable, blocked)
			checked += 1
			if target == Vector2i(-1, -1) or not reachable.has(_cell_key(target)):
				failures.append("%s.%s.%s is not reachable from spawn." % [
					map_id,
					section,
					str(point.get("id", "unknown"))
				])
	return checked

func _assert_hotspot_screen_safety(_instance: Node, map_id: String, camera: Camera2D, failures: Array[String]) -> int:
	var checked := 0
	for hotspot in _active_hotspots():
		for viewport in VIEWPORTS:
			var size: Vector2 = viewport.get("size", Vector2.ZERO)
			var safe := _safe_screen_rect(viewport)
			var center := _camera_center((hotspot as Node2D).global_position, camera, size)
			var screen_point := _world_to_screen((hotspot as Node2D).global_position, center, camera.zoom.x, size)
			checked += 1
			if not safe.grow(18.0).has_point(screen_point):
				failures.append("%s hotspot %s is too close to HUD in %s view." % [
					map_id,
					hotspot.name,
					str(viewport.get("id", "viewport"))
				])
			var marker := hotspot.get_node_or_null("PromptMarker") as Sprite2D
			if marker != null:
				var marker_rect := _marker_screen_rect(marker, center, camera.zoom.x, size)
				checked += 1
				if not _rect_inside(marker_rect, safe):
					failures.append("%s marker %s enters HUD safe area in %s view." % [
						map_id,
						hotspot.name,
						str(viewport.get("id", "viewport"))
					])
	return checked

func _active_hotspots() -> Array[Node]:
	var rows: Array[Node] = []
	for node in get_nodes_in_group("main_city_hotspot"):
		if node is Area2D and (node as CanvasItem).visible:
			rows.append(node)
	return rows

func _reachable_cells(start: Vector2i, width: float, height: float, walkable: Array, blocked: Array) -> Dictionary:
	var cols := ceili(width / ROUTE_STEP)
	var rows := ceili(height / ROUTE_STEP)
	var visited := {_cell_key(start): true}
	var queue: Array[Vector2i] = [start]
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for offset in offsets:
			var next_cell := cell + offset
			if next_cell.x < 0 or next_cell.y < 0 or next_cell.x >= cols or next_cell.y >= rows:
				continue
			var key := _cell_key(next_cell)
			if visited.has(key):
				continue
			if not _is_walkable(_cell_center(next_cell, width, height), width, height, walkable, blocked):
				continue
			visited[key] = true
			queue.append(next_cell)
	return visited

func _nearest_walkable_cell(point: Vector2, width: float, height: float, walkable: Array, blocked: Array) -> Vector2i:
	var origin := Vector2i(floori(point.x / ROUTE_STEP), floori(point.y / ROUTE_STEP))
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for radius in range(0, NEAREST_CELL_RADIUS + 1):
		for x_offset in range(-radius, radius + 1):
			for y_offset in range(-radius, radius + 1):
				var cell := origin + Vector2i(x_offset, y_offset)
				var center := _cell_center(cell, width, height)
				if not _is_walkable(center, width, height, walkable, blocked):
					continue
				var distance := center.distance_to(point)
				if distance < best_distance:
					best_distance = distance
					best = cell
		if best != Vector2i(-1, -1):
			return best
	return best

func _is_walkable(point: Vector2, width: float, height: float, walkable: Array, blocked: Array) -> bool:
	if point.x < 0.0 or point.y < 0.0 or point.x > width or point.y > height:
		return false
	if not walkable.is_empty() and not _point_in_rects(point, walkable):
		return false
	return not _point_in_rects(point, blocked)

func _point_in_rects(point: Vector2, rects: Array) -> bool:
	for raw_rect in rects:
		if typeof(raw_rect) != TYPE_DICTIONARY:
			continue
		var rect := raw_rect as Dictionary
		var x := float(rect.get("x", 0.0))
		var y := float(rect.get("y", 0.0))
		var width := float(rect.get("width", 0.0))
		var height := float(rect.get("height", 0.0))
		if point.x >= x and point.y >= y and point.x <= x + width and point.y <= y + height:
			return true
	return false

func _marker_screen_rect(marker: Sprite2D, center: Vector2, zoom: float, viewport_size: Vector2) -> Rect2:
	var screen_center := _world_to_screen(marker.global_position, center, zoom, viewport_size)
	var texture_size := marker.texture.get_size() if marker.texture != null else Vector2(48, 48)
	var size := Vector2(
		maxf(18.0, texture_size.x * absf(marker.scale.x) * zoom),
		maxf(18.0, texture_size.y * absf(marker.scale.y) * zoom)
	)
	return Rect2(screen_center - size * 0.5, size)

func _camera_center(position: Vector2, camera: Camera2D, viewport_size: Vector2) -> Vector2:
	var zoom := maxf(0.1, camera.zoom.x)
	var half_w := viewport_size.x * 0.5 / zoom
	var half_h := viewport_size.y * 0.5 / zoom
	return Vector2(
		_clamp_axis(position.x, float(camera.limit_left), float(camera.limit_right), half_w),
		_clamp_axis(position.y, float(camera.limit_top), float(camera.limit_bottom), half_h)
	)

func _clamp_axis(value: float, min_limit: float, max_limit: float, half_size: float) -> float:
	if max_limit - min_limit <= half_size * 2.0:
		return (min_limit + max_limit) * 0.5
	return clampf(value, min_limit + half_size, max_limit - half_size)

func _world_to_screen(world: Vector2, center: Vector2, zoom: float, viewport_size: Vector2) -> Vector2:
	return (world - center) * zoom + viewport_size * 0.5

func _safe_screen_rect(viewport: Dictionary) -> Rect2:
	var size: Vector2 = viewport.get("size", Vector2.ZERO)
	var side := float(viewport.get("side", 0.0))
	var top := float(viewport.get("top", 0.0))
	var bottom := float(viewport.get("bottom", 0.0))
	return Rect2(Vector2(side, top), Vector2(size.x - side * 2.0, size.y - top - bottom))

func _rect_inside(rect: Rect2, bounds: Rect2) -> bool:
	return bounds.has_point(rect.position) and bounds.has_point(rect.end)

func _cell_center(cell: Vector2i, width: float, height: float) -> Vector2:
	return Vector2(
		clampf(float(cell.x) * ROUTE_STEP + ROUTE_STEP * 0.5, 0.0, width),
		clampf(float(cell.y) * ROUTE_STEP + ROUTE_STEP * 0.5, 0.0, height)
	)

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _point_vec(point: Dictionary) -> Vector2:
	return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))

func _spawn_point(map_config: Dictionary) -> Dictionary:
	var spawns := map_config.get("spawn_points", []) as Array
	for raw_point in spawns:
		if typeof(raw_point) == TYPE_DICTIONARY and str((raw_point as Dictionary).get("id", "")) == "default":
			return raw_point as Dictionary
	for raw_point in spawns:
		if typeof(raw_point) == TYPE_DICTIONARY:
			return raw_point as Dictionary
	return {}

func _dynamic_marker_count(instance: Node) -> int:
	var count := 0
	var dynamic_root := instance.get_node_or_null(DYNAMIC_ROOT)
	if dynamic_root == null:
		return 0
	for child in dynamic_root.get_children():
		if child.get_node_or_null("PromptMarker") != null:
			count += 1
	return count

func _stable_map_ids(maps: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for map_id in maps.keys():
		rows.append(str(map_id))
	rows.sort()
	if rows.has(DEFAULT_MAP_ID):
		rows.erase(DEFAULT_MAP_ID)
		rows.push_front(DEFAULT_MAP_ID)
	return rows

func _all_map_ids() -> Array[String]:
	var maps: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points").get("maps", {}) as Dictionary
	return _stable_map_ids(maps)

func _write_report(failures: Array[String]) -> void:
	var absolute_dir := ProjectSettings.globalize_path(ARTIFACT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var json := {"rows": _report_rows, "failures": failures}
	var json_file := FileAccess.open("%s/report.json" % absolute_dir, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(json, "\t"))
