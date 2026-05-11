class_name MainCityMapRuntime
extends RefCounted

const MainCityMapMetadataScript := preload("res://scripts/main_city/MainCityMapMetadata.gd")
const MainCityMapDiscoveryScript := preload("res://scripts/main_city/MainCityMapDiscovery.gd")
const MainCityHotspotScript := preload("res://scripts/main_city/MainCityHotspot.gd")
const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const DYNAMIC_HOTSPOT_CONTAINER := "DynamicMapActivityHotspots"
const DYNAMIC_HOTSPOT_SIZE := Vector2(128, 80)
const ACTIVITY_MARKER_ICON := "res://assets/ui/sliced/hud_icons_v0/hud_icons_v0_022.png"
const ACTIVITY_MARKER_OFFSET := Vector2(0, -34)
const ACTIVITY_MARKER_SCALE := Vector2(0.30, 0.30)
const ACTIVITY_MARKER_ALPHA := 0.78
const HOTSPOTS := {
	"home": "MapRoot/Entrances/HomeGateHotspot",
	"fishing": "MapRoot/InteractionPoints/FishingPierHotspot",
	"games": "MapRoot/InteractionPoints/GamesHallHotspot",
	"shop": "MapRoot/InteractionPoints/ShopHotspot",
	"trade": "MapRoot/InteractionPoints/TradeMarketHotspot",
	"guild": "MapRoot/InteractionPoints/GuildGardenHotspot",
	"workshop": "MapRoot/InteractionPoints/WorkshopHotspot",
	"mine": "MapRoot/InteractionPoints/MineHotspot",
	"to_city": "MapRoot/InteractionPoints/ReturnCityHotspot"
}
const UTILITY_HOTSPOT_LABELS := {
	"mail": "world.hotspot_mail",
	"creator_help": "world.hotspot_creator_help",
	"notice": "world.hotspot_notice"
}

var current_map_id := DEFAULT_MAP_ID
var metadata
var screen_root: Node
var player: Node2D
var hud: Node
var discovery := MainCityMapDiscoveryScript.new()
var _activity_actions: Dictionary = {}
var _marker_textures: Dictionary = {}

func bind(new_screen_root: Node, new_player: Node2D, new_hud: Node) -> void:
	screen_root = new_screen_root
	player = new_player
	hud = new_hud

func load_map(map_id: String = DEFAULT_MAP_ID, spawn_id: String = "default", source: String = "arrival"):
	var next_metadata = MainCityMapMetadataScript.new()
	if not next_metadata.load_map(map_id):
		return null
	current_map_id = map_id
	SaveSystem.set_profile_value("current_world_map_id", current_map_id)
	unlock_map(current_map_id, source)
	metadata = next_metadata
	_apply_background()
	_apply_camera(spawn_id)
	_apply_title()
	_apply_player(spawn_id)
	_apply_hotspots()
	return metadata

func _apply_background() -> void:
	var backdrop := screen_root.get_node_or_null("MapRoot/MapBackdrop") as Sprite2D
	if backdrop == null:
		return
	var path := _map_asset_path()
	if path.is_empty():
		return
	var texture := ResourceLoader.load(path)
	if texture is Texture2D:
		backdrop.texture = texture as Texture2D

func _apply_camera(spawn_id: String) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var zoom := float(_map_record().get("camera_zoom", 0.95))
	camera.zoom = Vector2(zoom, zoom)
	_apply_camera_limits(camera, spawn_id)

func _apply_camera_limits(camera: Camera2D, spawn_id: String) -> void:
	if metadata == null or not metadata.has_method("camera_world_rect"):
		return
	var rect: Rect2 = metadata.call("camera_world_rect", spawn_id)
	camera.limit_left = floori(rect.position.x)
	camera.limit_top = floori(rect.position.y)
	camera.limit_right = ceili(rect.position.x + rect.size.x)
	camera.limit_bottom = ceili(rect.position.y + rect.size.y)
	if camera.has_method("reset_smoothing"):
		camera.call("reset_smoothing")

func _apply_title() -> void:
	if hud != null and hud.has_method("set_world_title"):
		hud.call("set_world_title", _map_display_name())
	if hud != null and hud.has_method("set_first_session_guide_enabled"):
		hud.call("set_first_session_guide_enabled", current_map_id == DEFAULT_MAP_ID)

func _apply_player(spawn_id: String) -> void:
	if player == null or metadata == null:
		return
	player.position = metadata.spawn_world_position(spawn_id, player.position)
	if player.has_method("set_movement_validator"):
		player.call("set_movement_validator", Callable(metadata, "is_world_position_walkable"))

func _apply_hotspots() -> void:
	for action_id in HOTSPOTS.keys():
		var hotspot := screen_root.get_node_or_null(str(HOTSPOTS[action_id])) as Node2D
		if hotspot == null:
			continue
		var enabled: bool = metadata != null and metadata.has_method("has_interaction") and bool(metadata.call("has_interaction", str(action_id)))
		hotspot.visible = enabled
		if hotspot is Area2D:
			(hotspot as Area2D).monitoring = enabled
			(hotspot as Area2D).input_pickable = enabled
		if hotspot.has_meta("mobile_touch_rect"):
			hotspot.remove_meta("mobile_touch_rect")
		if enabled:
			hotspot.position = metadata.interaction_world_position(str(action_id), hotspot.position)
			var point_record: Dictionary = metadata.point_record("interaction_points", str(action_id))
			var touch_rect: Dictionary = point_record.get("touch_rect", {}) as Dictionary
			if not touch_rect.is_empty():
				hotspot.set_meta("mobile_touch_rect", metadata.rect_to_world(touch_rect))
		var marker := hotspot.get_node_or_null("Marker") as Sprite2D
		if marker != null and str(action_id) == "to_city":
			marker.visible = enabled
		if hotspot.has_method("refresh_prompt_layout"):
			hotspot.call_deferred("refresh_prompt_layout")
	_apply_dynamic_activity_hotspots()

func _apply_dynamic_activity_hotspots() -> void:
	var container := _reset_dynamic_hotspot_container()
	if container == null or metadata == null:
		return
	var seen := {}
	for point in _activity_points():
		var action_id := _point_action(point)
		if action_id.is_empty() or HOTSPOTS.has(action_id):
			continue
		var key := "%s:%d:%d" % [action_id, int(round(float(point.get("x", 0.0)))), int(round(float(point.get("y", 0.0))))]
		if seen.has(key):
			continue
		seen[key] = true
		if _activity_records().has(action_id):
			_add_dynamic_activity_hotspot(container, action_id, point)
		elif UTILITY_HOTSPOT_LABELS.has(action_id):
			_add_dynamic_utility_hotspot(container, action_id, point)

func refresh_activity_hotspots(activity_service) -> void:
	var container := screen_root.get_node_or_null("MapRoot/InteractionPoints/%s" % DYNAMIC_HOTSPOT_CONTAINER)
	if container == null or activity_service == null:
		return
	for child in container.get_children():
		if str(child.get_meta("map_hotspot_kind", "")) != "activity":
			continue
		if not child.has_method("set_activity_state"):
			continue
		var action_id := str(child.get("action_id"))
		var state: Dictionary = activity_service.call("activity_state", action_id)
		child.call("set_activity_state", str(state.get("state", "ready")), int(state.get("seconds", 0)))

func _reset_dynamic_hotspot_container() -> Node2D:
	var parent := screen_root.get_node_or_null("MapRoot/InteractionPoints") as Node2D
	if parent == null:
		return null
	var previous := parent.get_node_or_null(DYNAMIC_HOTSPOT_CONTAINER)
	if previous != null:
		parent.remove_child(previous)
		previous.queue_free()
	var container := Node2D.new()
	container.name = DYNAMIC_HOTSPOT_CONTAINER
	parent.add_child(container)
	return container

func _activity_points() -> Array:
	var points := []
	if metadata.has_method("interaction_records"):
		points.append_array(metadata.call("interaction_records"))
	if metadata.has_method("life_skill_records"):
		points.append_array(metadata.call("life_skill_records"))
	return points

func _add_dynamic_activity_hotspot(container: Node2D, action_id: String, point: Dictionary) -> void:
	var hotspot := MainCityHotspotScript.new()
	hotspot.name = "ActivityHotspot_%s" % _safe_node_name(str(point.get("id", action_id)))
	hotspot.action_id = action_id
	hotspot.label_key = str(point.get("label_key", _activity_title_key(action_id)))
	hotspot.activity_state_enabled = true
	hotspot.position = metadata.call("point_to_world", point)
	hotspot.set_meta("map_hotspot_kind", "activity")
	hotspot.add_child(_activity_collision())
	hotspot.add_child(_activity_marker("activity", hotspot.position))
	hotspot.add_child(_activity_prompt_label())
	container.add_child(hotspot)
	hotspot.call_deferred("refresh_prompt_layout")

func _add_dynamic_utility_hotspot(container: Node2D, action_id: String, point: Dictionary) -> void:
	var hotspot := MainCityHotspotScript.new()
	hotspot.name = "UtilityHotspot_%s" % _safe_node_name(str(point.get("id", action_id)))
	hotspot.action_id = action_id
	hotspot.label_key = str(point.get("label_key", UTILITY_HOTSPOT_LABELS.get(action_id, "")))
	hotspot.position = metadata.call("point_to_world", point)
	hotspot.set_meta("map_hotspot_kind", "utility")
	hotspot.add_child(_activity_collision())
	hotspot.add_child(_activity_marker(action_id, hotspot.position))
	hotspot.add_child(_activity_prompt_label())
	container.add_child(hotspot)
	hotspot.call_deferred("refresh_prompt_layout")

func _activity_collision() -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = DYNAMIC_HOTSPOT_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	return collision

func _activity_prompt_label() -> Label:
	var label := Label.new()
	label.name = "PromptLabel"
	label.offset_left = -76.0
	label.offset_top = -86.0
	label.offset_right = 76.0
	label.offset_bottom = -58.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _activity_marker(marker_id: String, hotspot_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "PromptMarker"
	sprite.texture = _marker_texture(marker_id)
	sprite.position = ACTIVITY_MARKER_OFFSET
	if hotspot_position.y < 150.0:
		sprite.position.y = 28.0
	sprite.scale = ACTIVITY_MARKER_SCALE
	sprite.modulate = Color(1.0, 1.0, 1.0, ACTIVITY_MARKER_ALPHA)
	sprite.z_as_relative = false
	sprite.z_index = 1940
	return sprite

func _marker_texture(marker_id: String) -> Texture2D:
	var path := _marker_path(marker_id)
	if not _marker_textures.has(path):
		_marker_textures[path] = ResourceLoader.load(path)
	return _marker_textures[path] as Texture2D

func _marker_path(marker_id: String) -> String:
	match marker_id:
		"mail":
			return "res://assets/ui/sliced/hud_icons_v0/hud_icons_v0_004.png"
		"creator_help":
			return "res://assets/ui/sliced/hud_icons_v0/hud_icons_v0_007.png"
		"notice":
			return "res://assets/ui/sliced/hud_icons_v0/hud_icons_v0_035.png"
		_:
			return ACTIVITY_MARKER_ICON

func _activity_records() -> Dictionary:
	if _activity_actions.is_empty():
		_activity_actions = ConfigLoader.get_value("map_activities", ["actions"], {}) as Dictionary
	return _activity_actions

func _activity_title_key(action_id: String) -> String:
	var record: Dictionary = _activity_records().get(action_id, {}) as Dictionary
	return str(record.get("title_key", ""))

func _point_action(point: Dictionary) -> String:
	return str(point.get("action", point.get("type", "")))

func _safe_node_name(value: String) -> String:
	return value.replace(".", "_").replace("-", "_").replace(":", "_")

func _map_asset_path() -> String:
	return str(_map_record().get("asset_path", ""))

func _map_display_name() -> String:
	var names: Dictionary = _map_record().get("name", {}) as Dictionary
	var locale := "zh" if App.current_locale.begins_with("zh") else App.current_locale
	return str(names.get(locale, names.get("en", current_map_id)))

func _map_record() -> Dictionary:
	return _record_for_map(current_map_id)

func can_travel_to(map_id: String) -> bool:
	return discovery.can_travel_to(map_id, _record_for_map(map_id))

func unlock_map(map_id: String, source: String = "arrival") -> bool:
	return bool(discovery.discover(map_id, source))

func _record_for_map(map_id: String) -> Dictionary:
	var catalog: Dictionary = ConfigLoader.load_config("map_catalog")
	for record in catalog.get("maps", []):
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == map_id:
			return record as Dictionary
	return {}
