class_name MainCityMapTravelController
extends RefCounted

var map_runtime
var interaction_controller: Node
var chat_service: Node

func bind(new_map_runtime, new_interaction_controller: Node, new_chat_service: Node) -> void:
	map_runtime = new_map_runtime
	interaction_controller = new_interaction_controller
	chat_service = new_chat_service

func request_directory_travel(map_id: String) -> Variant:
	if map_runtime != null and not bool(map_runtime.call("can_travel_to", map_id)):
		_add_system_message("world.map_locked")
		return null
	return switch_world_map(map_id, "world.map_travel_generic")

func switch_world_map(map_id: String, message_key: String, source: String = "arrival", spawn_id := "default") -> Variant:
	var next_metadata = map_runtime.load_map(map_id, spawn_id, source)
	if next_metadata == null:
		return null
	if interaction_controller != null:
		interaction_controller.call("set_map_metadata", next_metadata)
	_add_system_message(message_key)
	return next_metadata

func _add_system_message(message_key: String) -> void:
	chat_service.add_system_message(App.t_key("chat.system.name"), App.t_key(message_key))
