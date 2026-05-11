class_name MainCityPresenceAnnouncer
extends RefCounted

var known_member_names: Dictionary = {}
var seeded := false
var remote_player_sync
var chat_service: Node

func bind(new_remote_player_sync, new_chat_service: Node) -> void:
	remote_player_sync = new_remote_player_sync
	chat_service = new_chat_service

func apply(members: Array) -> void:
	var local_id := SaveSystem.get_player_id()
	var next_member_names := {}
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var player_id := str((member as Dictionary).get("player_id", ""))
		if player_id.is_empty() or player_id == local_id:
			continue
		next_member_names[player_id] = remote_player_sync.display_name_for(member as Dictionary, player_id)
	if not seeded:
		known_member_names = next_member_names
		seeded = true
		return
	_announce_joins(next_member_names)
	_announce_leaves(next_member_names)
	known_member_names = next_member_names

func _announce_joins(next_member_names: Dictionary) -> void:
	for player_id in next_member_names:
		if not known_member_names.has(player_id):
			_add_presence_message("world.player_joined", str(next_member_names[player_id]))

func _announce_leaves(next_member_names: Dictionary) -> void:
	for player_id in known_member_names:
		if not next_member_names.has(player_id):
			_add_presence_message("world.player_left", str(known_member_names[player_id]))

func _add_presence_message(key: String, display_name: String) -> void:
	chat_service.add_system_message(App.t_key("chat.system.name"), App.format_key(key, {"name": display_name}))
