class_name MainCityInteractionController
extends Node

signal fishing_requested()
signal home_requested()
signal games_requested()
signal shop_requested()
signal trade_requested()
signal guild_requested()
signal workshop_requested()
signal mine_requested()
signal city_requested()
signal map_unlock_requested(map_id: String, source: String)
signal map_activity_requested(action_id: String)

const MainCityNPCScript := preload("res://scripts/main_city/MainCityNPC.gd")
const MainCityNPCAmbienceScript := preload("res://scripts/main_city/MainCityNPCAmbience.gd")
const ACTION_MAPS := {
	"fishing": "life_fishing_riverbend_v1",
	"home": "social_housing_district_v1",
	"games": "social_minigame_arcade_hall_v1",
	"shop": "city_port_market_v1",
	"trade": "social_trade_market_v1",
	"guild": "social_guild_garden_v1",
	"mail": "social_mail_plaza_v1",
	"creator_help": "social_creator_gallery_v1",
	"workshop": "city_spring_workshop_v1",
	"mine": "life_crystal_mine_v1",
	"to_city": "city_forest_dawn_v1"
}
const NPC_ATTENTION_RADIUS := 88.0
const NPC_ATTENTION_SCAN_SECONDS := 0.22
const MAP_ROUTE_DEBOUNCE_MS := 5200

var screen_root: Node
var npc_root: Node2D
var hud: Node
var chat_service: Node
var map_metadata
var _npc_records_by_id: Dictionary = {}
var _nearby_npc_id := ""
var _npc_scan_left := 0.0
var _npc_ambience: Node
var _touch_route_guard_until_msec := 0
var _routing_touch_action := false

func bind(
	new_screen_root: Node,
	new_npc_root: Node2D,
	new_hud: Node,
	new_chat_service: Node,
	new_map_metadata = null
) -> void:
	screen_root = new_screen_root
	npc_root = new_npc_root
	hud = new_hud
	chat_service = new_chat_service
	map_metadata = new_map_metadata
	if hud != null and not hud.npc_primary_action.is_connected(_on_npc_primary_action):
		hud.npc_primary_action.connect(_on_npc_primary_action)
	_spawn_npcs()
	_bind_hotspots()
	_bind_npc_ambience()
	set_process(true)

func set_map_metadata(new_map_metadata) -> void:
	map_metadata = new_map_metadata
	_nearby_npc_id = ""
	_spawn_npcs()
	_bind_hotspots()
	_bind_npc_ambience()

func _process(delta: float) -> void:
	_npc_scan_left -= delta
	if _npc_scan_left > 0.0:
		return
	_npc_scan_left = NPC_ATTENTION_SCAN_SECONDS
	_refresh_nearby_npc_attention()

func _bind_hotspots() -> void:
	if screen_root == null:
		return
	var callback := Callable(self, "_on_hotspot_activated")
	var input_callback := Callable(self, "_on_hotspot_input_activated")
	for node in get_tree().get_nodes_in_group("main_city_hotspot"):
		if not screen_root.is_ancestor_of(node):
			continue
		if not node.is_connected("activated", callback):
			node.connect("activated", callback)
		if node.has_signal("input_activated") and not node.is_connected("input_activated", input_callback):
			node.connect("input_activated", input_callback)

func _bind_npc_ambience() -> void:
	if _npc_ambience == null:
		_npc_ambience = MainCityNPCAmbienceScript.new()
		_npc_ambience.name = "NPCAmbience"
		add_child(_npc_ambience)
	_npc_ambience.call("bind", screen_root, npc_root)

func _spawn_npcs() -> void:
	if npc_root == null:
		return
	for child in npc_root.get_children():
		npc_root.remove_child(child)
		child.queue_free()
	_npc_records_by_id.clear()
	_nearby_npc_id = ""
	var config: Dictionary = ConfigLoader.load_config("main_city_npcs")
	for record in config.get("npcs", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var npc_record := (record as Dictionary).duplicate(true)
		var npc_id := str(npc_record.get("id", ""))
		if npc_id.is_empty():
			continue
		_apply_map_position(npc_record, npc_id)
		if npc_record.is_empty():
			continue
		_npc_records_by_id[npc_id] = npc_record
		var npc := MainCityNPCScript.new()
		npc.setup(npc_record)
		_apply_npc_runtime_meta(npc, npc_record)
		npc.activated.connect(_on_npc_activated)
		npc_root.add_child(npc)

func _on_hotspot_activated(action_id: String) -> void:
	_route_action(action_id, "")

func _on_hotspot_input_activated(action_id: String, _input_source: String) -> void:
	if action_id == "to_city":
		route_touch_hotspot_action(action_id)
		return
	_route_action(action_id, "")

func route_hotspot_action(action_id: String) -> void:
	_route_action(action_id, "")

func route_touch_hotspot_action(action_id: String) -> void:
	_routing_touch_action = true
	_route_action(action_id, "")
	_routing_touch_action = false
	if action_id == "to_city":
		_touch_route_guard_until_msec = Time.get_ticks_msec() + MAP_ROUTE_DEBOUNCE_MS

func _on_npc_activated(npc_id: String, _action_id: String) -> void:
	var record: Dictionary = _npc_records_by_id.get(npc_id, {}) as Dictionary
	if record.is_empty():
		return
	_request_npc_attention(npc_id, 1.8, true)
	if hud == null:
		return
	hud.show_npc_dialog(record)

func _on_npc_primary_action(action_id: String) -> void:
	_route_action(action_id, "npc")

func _route_action(action_id: String, source: String) -> void:
	if _should_suppress_map_route(action_id):
		return
	_request_unlock_for_action(action_id, source)
	match action_id:
		"fishing":
			fishing_requested.emit()
		"home":
			home_requested.emit()
		"games":
			games_requested.emit()
		"shop":
			shop_requested.emit()
		"trade":
			trade_requested.emit()
		"guild":
			guild_requested.emit()
		"workshop":
			workshop_requested.emit()
		"mine":
			mine_requested.emit()
		"to_city":
			city_requested.emit()
		"mail":
			_show_messages_panel()
			_add_system_message("npc.mail_courier.name", "npc.mail_courier.dialogue")
		"creator_help":
			_show_utility_panel("creator")
			_add_system_message("npc.creator_tutor.name", "npc.creator_tutor.dialogue")
		"notice":
			_show_utility_panel("notice")
			_add_system_message("npc.event_guide.name", "npc.event_guide.dialogue")
		_:
			if source == "npc":
				_add_system_message("chat.system.name", "world.hotspot_shop_soon")
			else:
				map_activity_requested.emit(action_id)

func _should_suppress_map_route(action_id: String) -> bool:
	if not ACTION_MAPS.has(action_id):
		return false
	if _routing_touch_action and action_id == "to_city":
		return false
	return Time.get_ticks_msec() <= _touch_route_guard_until_msec

func _request_unlock_for_action(action_id: String, source: String) -> void:
	if source.is_empty() or not ACTION_MAPS.has(action_id):
		return
	map_unlock_requested.emit(str(ACTION_MAPS[action_id]), source)

func _add_system_message(sender_key: String, body_key: String) -> void:
	if chat_service == null:
		return
	chat_service.add_system_message(App.t_key(sender_key), App.t_key(body_key))

func _show_utility_panel(panel_id: String) -> void:
	if hud != null and hud.has_method("show_utility_panel"):
		hud.call("show_utility_panel", panel_id)

func _show_messages_panel() -> void:
	if hud != null and hud.has_method("show_messages_panel"):
		hud.call("show_messages_panel", "mail")

func _apply_map_position(npc_record: Dictionary, npc_id: String) -> void:
	if map_metadata == null or not map_metadata.has_method("npc_world_position"):
		return
	if map_metadata.has_method("has_npc") and not bool(map_metadata.call("has_npc", npc_id)):
		npc_record.clear()
		return
	var fallback := _record_position(npc_record)
	var point_record := map_metadata.call("point_record", "npc_points", "npc.%s" % npc_id) as Dictionary
	var next_position: Vector2 = map_metadata.call("npc_world_position", npc_id, fallback)
	if map_metadata.has_method("is_world_position_walkable") and not bool(map_metadata.call("is_world_position_walkable", next_position)):
		npc_record.clear()
		return
	_apply_point_visual_overrides(npc_record, point_record)
	npc_record["position"] = {
		"x": next_position.x,
		"y": next_position.y
	}

func _apply_point_visual_overrides(npc_record: Dictionary, point_record: Dictionary) -> void:
	if point_record.is_empty():
		return
	for key in ["facing", "pose", "emote_id", "ambience_poses"]:
		if point_record.has(key):
			npc_record[key] = point_record.get(key)

func _apply_npc_runtime_meta(npc: Node, npc_record: Dictionary) -> void:
	if npc == null:
		return
	var ambience_poses: Array = npc_record.get("ambience_poses", []) as Array
	if not ambience_poses.is_empty():
		npc.set_meta("ambience_poses", ambience_poses.duplicate(true))

func _refresh_nearby_npc_attention() -> void:
	var player := _local_player()
	if player == null or npc_root == null:
		return
	var nearest := _nearest_npc(player.global_position)
	var next_id := "" if nearest == null else str(nearest.get("npc_id"))
	if next_id == _nearby_npc_id:
		return
	_nearby_npc_id = next_id
	if nearest != null:
		nearest.call("face_toward", player.global_position, 1.2, false)

func _request_npc_attention(npc_id: String, seconds: float, reveal := false) -> void:
	var player := _local_player()
	if player == null or npc_root == null:
		return
	var npc := npc_root.get_node_or_null(npc_id)
	if npc != null and npc.has_method("face_toward"):
		npc.call("face_toward", player.global_position, seconds, reveal)

func _nearest_npc(player_position: Vector2) -> Node:
	var best: Node = null
	var best_distance := NPC_ATTENTION_RADIUS * NPC_ATTENTION_RADIUS
	for child in npc_root.get_children():
		var npc := child as Node2D
		if npc == null or not npc.has_method("face_toward"):
			continue
		var distance := npc.global_position.distance_squared_to(player_position)
		if distance < best_distance:
			best_distance = distance
			best = npc
	return best

func _local_player() -> Node2D:
	if screen_root == null:
		return null
	return screen_root.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D

func _record_position(npc_record: Dictionary) -> Vector2:
	var position_data: Dictionary = npc_record.get("position", {}) as Dictionary
	return Vector2(
		float(position_data.get("x", 0.0)),
		float(position_data.get("y", 0.0))
	)
