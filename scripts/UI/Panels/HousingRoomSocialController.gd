class_name HousingRoomSocialController
extends Node

const ChatServiceScript := preload("res://scripts/Systems/Chat/ChatService.gd")
const PresenceServiceScript := preload("res://scripts/Systems/Presence/PresenceService.gd")

var chat_service: Node
var presence_service: Node
var owner_id := ""
var room_id := ""

func initialize(new_owner_id: String, new_room_id: String) -> void:
	owner_id = new_owner_id
	room_id = new_room_id
	chat_service = ChatServiceScript.new()
	add_child(chat_service)
	chat_service.initialize()
	chat_service.set_view_channel("house")
	chat_service.load_history(room_id, "house")
	presence_service = PresenceServiceScript.new()
	add_child(presence_service)
	presence_service.initialize(SaveSystem.get_display_name(), room_id)

func bind_panel(panel: Node) -> void:
	if panel == null:
		return
	panel.chat_send_requested.connect(_send_house_chat)
	panel.bind_services(presence_service, chat_service, owner_id)

func _send_house_chat(body: String) -> void:
	if chat_service == null:
		return
	chat_service.send_local_message("house", SaveSystem.get_display_name(), body)
