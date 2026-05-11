extends SceneTree

const MOBILE_VIEWPORT := Vector2(844, 390)
const DESKTOP_VIEWPORT := Vector2(1280, 720)
const MOBILE_SAFE := {"top": 56.0, "bottom": 72.0, "side": 28.0}
const DESKTOP_SAFE := {"top": 96.0, "bottom": 118.0, "side": 48.0}
const FOCUS_POINTS := [
	{"map": "city_forest_dawn_v1", "points": [["npc_points", "npc.event_guide"], ["interaction_points", "trade"]]},
	{
		"map": "city_port_market_v1",
		"points": [["npc_points", "npc.merchant"], ["interaction_points", "shop"], ["interaction_points", "mail"]]
	},
	{"map": "social_trade_market_v1", "points": [["npc_points", "npc.trade_broker"], ["interaction_points", "trade"]]},
	{"map": "social_guild_garden_v1", "points": [["npc_points", "npc.guild_coordinator"], ["interaction_points", "guild"]]},
	{"map": "social_housing_district_v1", "points": [["npc_points", "npc.home_keeper"], ["interaction_points", "home"]]},
	{"map": "social_minigame_arcade_hall_v1", "points": [["npc_points", "npc.game_host"], ["interaction_points", "games"]]},
	{"map": "social_mail_plaza_v1", "points": [["npc_points", "npc.mail_courier"], ["interaction_points", "mail"]]},
	{"map": "social_creator_gallery_v1", "points": [["npc_points", "npc.creator_tutor"], ["interaction_points", "creator_help"]]},
	{"map": "life_fishing_riverbend_v1", "points": [["npc_points", "npc.fisher"], ["interaction_points", "fishing"]]}
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	var map_runtime = instance.get("_map_runtime")
	var player := instance.get_node("PlayerRoot/LocalPlayer") as Node2D
	var camera := player.get_node("Camera2D") as Camera2D
	for record in FOCUS_POINTS:
		var map_id := str(record.get("map", ""))
		var metadata = map_runtime.call("load_map", map_id)
		await process_frame
		_assert_focus_points(map_id, record.get("points", []), metadata, player, camera, failures)
	instance.queue_free()
	if failures.is_empty():
		print("map first-screen readability smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_focus_points(
	map_id: String,
	points: Array,
	metadata,
	player: Node2D,
	camera: Camera2D,
	failures: Array[String]
) -> void:
	var mobile_rect := _safe_world_rect(player.global_position, camera, MOBILE_VIEWPORT, MOBILE_SAFE)
	var desktop_rect := _safe_world_rect(player.global_position, camera, DESKTOP_VIEWPORT, DESKTOP_SAFE)
	for point_ref in points:
		var section := str(point_ref[0])
		var point_id := str(point_ref[1])
		var point: Dictionary = metadata.call("point_record", section, point_id)
		if point.is_empty():
			failures.append("%s missing first-screen focus point %s.%s." % [map_id, section, point_id])
			continue
		var world_position: Vector2 = metadata.call("point_to_world", point)
		if not mobile_rect.has_point(world_position):
			failures.append("%s %s.%s is outside the mobile first-screen safe view." % [map_id, section, point_id])
		if not desktop_rect.has_point(world_position):
			failures.append("%s %s.%s is outside the desktop first-screen safe view." % [map_id, section, point_id])

func _safe_world_rect(center_source: Vector2, camera: Camera2D, viewport_size: Vector2, safe: Dictionary) -> Rect2:
	var zoom: float = max(0.1, camera.zoom.x)
	var half_w := viewport_size.x * 0.5 / zoom
	var half_h := viewport_size.y * 0.5 / zoom
	var center := _camera_center(center_source, camera, half_w, half_h)
	var left := center.x - (viewport_size.x * 0.5 - float(safe.get("side", 0.0))) / zoom
	var right := center.x + (viewport_size.x * 0.5 - float(safe.get("side", 0.0))) / zoom
	var top := center.y - (viewport_size.y * 0.5 - float(safe.get("top", 0.0))) / zoom
	var bottom := center.y + (viewport_size.y * 0.5 - float(safe.get("bottom", 0.0))) / zoom
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _camera_center(position: Vector2, camera: Camera2D, half_w: float, half_h: float) -> Vector2:
	var left := float(camera.limit_left)
	var right := float(camera.limit_right)
	var top := float(camera.limit_top)
	var bottom := float(camera.limit_bottom)
	return Vector2(
		_clamp_axis(position.x, left, right, half_w),
		_clamp_axis(position.y, top, bottom, half_h)
	)

func _clamp_axis(value: float, min_limit: float, max_limit: float, half_size: float) -> float:
	if max_limit - min_limit <= half_size * 2.0:
		return (min_limit + max_limit) * 0.5
	return clampf(value, min_limit + half_size, max_limit - half_size)
