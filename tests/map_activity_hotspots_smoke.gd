extends SceneTree

const MIN_STATIC_TOUCH_SIZE := Vector2(96, 52)
const MIN_DYNAMIC_TOUCH_SIZE := Vector2(120, 72)
const MIN_DYNAMIC_MARKER_SIZE := Vector2(36, 40)
const MAX_DYNAMIC_MARKER_SIZE := Vector2(56, 60)
const STATIC_HOTSPOT_PATHS := [
	"MapRoot/Entrances/HomeGateHotspot",
	"MapRoot/InteractionPoints/FishingPierHotspot",
	"MapRoot/InteractionPoints/GamesHallHotspot",
	"MapRoot/InteractionPoints/ShopHotspot",
	"MapRoot/InteractionPoints/TradeMarketHotspot",
	"MapRoot/InteractionPoints/GuildGardenHotspot",
	"MapRoot/InteractionPoints/WorkshopHotspot",
	"MapRoot/InteractionPoints/MineHotspot",
	"MapRoot/InteractionPoints/ReturnCityHotspot"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-activity-hotspots",
		"display_name": "Hotspot Smoke",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"map_activity_cooldowns": {},
		"discovered_world_map_ids": ["city_forest_dawn_v1", "random_flower_valley_v1", "life_herb_forest_v1"]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	_verify_static_touch_targets(instance, failures)
	instance.call("_switch_world_map", "random_flower_valley_v1", "world.map_travel_generic")
	await process_frame
	var dynamic_root := instance.get_node_or_null("MapRoot/InteractionPoints/DynamicMapActivityHotspots")
	if dynamic_root == null or dynamic_root.get_child_count() < 3:
		failures.append("Random map did not create dynamic exploration hotspots.")
	else:
		var hotspot := _first_hotspot(dynamic_root, "explore")
		if hotspot == null:
			failures.append("Random map dynamic hotspots did not include explore.")
		else:
			_verify_dynamic_touch_target(hotspot, failures)
			_verify_dynamic_marker(hotspot, failures)
			var prompt := hotspot.get_node_or_null("PromptLabel") as Label
			if prompt == null or prompt.visible or prompt.text.find("Ready") < 0:
				failures.append("Dynamic explore hotspot should keep ready text hidden until touch.")
			hotspot.call("activate")
			await process_frame
			if save_system.call("get_coin_balance") != 1:
				failures.append("Dynamic explore hotspot did not route into MapActivityService.")
			var status_label := instance.get_node("WorldHUD/Root/BottomBar/BottomMargin/BottomRows/StatusLabel") as Label
			if status_label == null or not status_label.text.contains("Trail Token"):
				failures.append("Dynamic explore hotspot did not show the activity reward summary.")
			if prompt == null or prompt.text.find("s") < 0:
				failures.append("Dynamic explore hotspot did not show cooldown state.")
	instance.call("_switch_world_map", "life_herb_forest_v1", "world.map_travel_generic")
	await process_frame
	dynamic_root = instance.get_node_or_null("MapRoot/InteractionPoints/DynamicMapActivityHotspots")
	if dynamic_root == null or _first_hotspot(dynamic_root, "gather_herb") == null:
		failures.append("Life skill map did not expose gather_herb as a dynamic hotspot.")
	else:
		var herb_hotspot := _first_hotspot(dynamic_root, "gather_herb")
		_verify_dynamic_touch_target(herb_hotspot, failures)
		_verify_dynamic_marker(herb_hotspot, failures)
	await _verify_hotspot_feedback(failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map activity hotspots smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _first_hotspot(root_node: Node, action_id: String) -> Node:
	for child in root_node.get_children():
		if str(child.get("action_id")) == action_id:
			return child
	return null

func _verify_static_touch_targets(instance: Node, failures: Array[String]) -> void:
	for path in STATIC_HOTSPOT_PATHS:
		var hotspot := instance.get_node_or_null(path)
		if hotspot == null:
			failures.append("Missing static hotspot %s." % path)
			continue
		var polygon := hotspot.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if polygon == null:
			failures.append("%s is missing touch collision." % path)
			continue
		var size := _polygon_size(polygon.polygon)
		if size.x < MIN_STATIC_TOUCH_SIZE.x or size.y < MIN_STATIC_TOUCH_SIZE.y:
			failures.append("%s touch target is too small: %s." % [path, size])

func _verify_dynamic_touch_target(hotspot: Node, failures: Array[String]) -> void:
	if hotspot == null:
		return
	var collision := _first_collision_shape(hotspot)
	if collision == null or not (collision.shape is RectangleShape2D):
		failures.append("%s dynamic hotspot has no rectangular touch target." % hotspot.name)
		return
	var size := (collision.shape as RectangleShape2D).size
	if size.x < MIN_DYNAMIC_TOUCH_SIZE.x or size.y < MIN_DYNAMIC_TOUCH_SIZE.y:
		failures.append("%s dynamic touch target is too small: %s." % [hotspot.name, size])

func _verify_dynamic_marker(hotspot: Node, failures: Array[String]) -> void:
	if hotspot == null:
		return
	var marker := hotspot.get_node_or_null("PromptMarker") as Sprite2D
	if marker == null or marker.texture == null:
		failures.append("%s dynamic hotspot is missing its compact map marker." % hotspot.name)
		return
	var marker_size := marker.texture.get_size() * marker.scale.abs()
	if marker_size.x < MIN_DYNAMIC_MARKER_SIZE.x or marker_size.y < MIN_DYNAMIC_MARKER_SIZE.y:
		failures.append("%s dynamic marker is too small to read on mobile: %s." % [hotspot.name, marker_size])
	if marker_size.x > MAX_DYNAMIC_MARKER_SIZE.x or marker_size.y > MAX_DYNAMIC_MARKER_SIZE.y:
		failures.append("%s dynamic marker is too large and competes with actors: %s." % [hotspot.name, marker_size])

func _first_collision_shape(root_node: Node) -> CollisionShape2D:
	for child in root_node.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null

func _polygon_size(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_point := points[0]
	var max_point := points[0]
	for point in points:
		min_point.x = min(min_point.x, point.x)
		min_point.y = min(min_point.y, point.y)
		max_point.x = max(max_point.x, point.x)
		max_point.y = max(max_point.y, point.y)
	return max_point - min_point

func _verify_hotspot_feedback(failures: Array[String]) -> void:
	var hotspot = load("res://scripts/main_city/MainCityHotspot.gd").new()
	hotspot.action_id = "debounce_test"
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	hotspot.add_child(prompt)
	var activations: Array[String] = []
	hotspot.activated.connect(func(action_id: String) -> void: activations.append(action_id))
	root.add_child(hotspot)
	await process_frame
	if prompt.visible:
		failures.append("Static hotspot prompt should start hidden before touch feedback.")
	hotspot.activate()
	hotspot.activate()
	if activations.size() != 1:
		failures.append("MainCityHotspot did not debounce rapid double activation.")
	if not prompt.visible:
		failures.append("MainCityHotspot did not reveal its prompt after touch activation.")
	await create_timer(1.35).timeout
	if prompt.visible:
		failures.append("MainCityHotspot prompt did not hide after transient touch feedback.")
	hotspot.queue_free()
