class_name OfflineClient
extends Node

signal connection_changed(is_connected: bool)

var is_connected := false
var current_user: Dictionary = {}

func connect_async(profile: Dictionary) -> void:
	await get_tree().process_frame
	current_user = {
		"id": str(profile.get("id", "offline-user")),
		"display_name": str(profile.get("display_name", ""))
	}
	is_connected = true
	connection_changed.emit(is_connected)

func disconnect_client() -> void:
	is_connected = false
	current_user = {}
	connection_changed.emit(is_connected)

func send_request(route: String, payload: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"offline": true,
		"route": route,
		"payload": payload
	}
