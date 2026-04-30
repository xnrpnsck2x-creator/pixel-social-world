class_name WorldStateSync
extends Node

signal snapshot_received(snapshot: Dictionary)
signal move_snapshot_ready(payload: Dictionary)

const MessageTypesScript := preload("res://scripts/Network/Protocol/MessageTypes.gd")

var client: Node
var local_player: Node
var room_id := "world_town_square"

func bind_client(new_client: Node) -> void:
	client = new_client

func bind_local_player(new_local_player: Node, new_room_id: String = "world_town_square") -> void:
	local_player = new_local_player
	room_id = new_room_id

func request_snapshot() -> Dictionary:
	if client == null:
		return {}

	var response: Dictionary = client.send_request(MessageTypesScript.WORLD_SNAPSHOT, {})
	snapshot_received.emit(response)
	return response

func build_player_move_payload() -> Dictionary:
	if local_player == null or not local_player.has_method("get_avatar_state"):
		return {}
	var state: Dictionary = local_player.call("get_avatar_state")
	var payload := {
		"player_id": _save_system().call("get_player_id"),
		"room_id": room_id,
		"position": state.get("position", {"x": 0, "y": 0}),
		"velocity": state.get("velocity", {"x": 0, "y": 0}),
		"facing": str(state.get("facing", "down")),
		"is_sitting": bool(state.get("is_sitting", false)),
		"is_attacking": bool(state.get("is_attacking", false)),
		"sent_at": int(Time.get_unix_time_from_system())
	}
	move_snapshot_ready.emit(payload)
	return payload

func _save_system() -> Node:
	return get_node("/root/SaveSystem")
