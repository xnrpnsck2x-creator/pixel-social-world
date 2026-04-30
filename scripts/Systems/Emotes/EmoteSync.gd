class_name EmoteSync
extends Node

signal emote_received(player_id: String, emote_id: String)

const MessageTypesScript := preload("res://scripts/Network/Protocol/MessageTypes.gd")
const EMOTE_SEND_ROUTE := "emote.send"
const DEFAULT_ROOM_ID := "world_town_square"

var client: Node
var room_id := DEFAULT_ROOM_ID

func bind_client(new_client: Node) -> void:
	client = new_client

func bind_room(new_room_id: String) -> void:
	room_id = new_room_id if not new_room_id.is_empty() else DEFAULT_ROOM_ID

func send_emote(player_id: String, emote_id: String) -> void:
	var payload := {
		"player_id": player_id,
		"room_id": room_id,
		"emote_id": emote_id,
		"created_at": int(Time.get_unix_time_from_system())
	}
	var realtime := _realtime_client()
	if realtime != null and bool(realtime.get("is_connected")):
		realtime.send_envelope(MessageTypesScript.EMOTE_SEND, payload)
	elif client != null and client.has_method("send_request"):
		client.send_request(EMOTE_SEND_ROUTE, payload)
	emote_received.emit(player_id, emote_id)

func _realtime_client() -> Node:
	if not has_node("/root/RealtimeClient"):
		return null
	return get_node("/root/RealtimeClient")
