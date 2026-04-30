class_name MainCityInteractionController
extends Node

signal fishing_requested()
signal home_requested()
signal games_requested()

const MainCityNPCScript := preload("res://scripts/main_city/MainCityNPC.gd")

var screen_root: Node
var npc_root: Node2D
var hud: Node
var chat_service: Node
var _npc_records_by_id: Dictionary = {}

func bind(
	new_screen_root: Node,
	new_npc_root: Node2D,
	new_hud: Node,
	new_chat_service: Node
) -> void:
	screen_root = new_screen_root
	npc_root = new_npc_root
	hud = new_hud
	chat_service = new_chat_service
	if hud != null and not hud.npc_primary_action.is_connected(_on_npc_primary_action):
		hud.npc_primary_action.connect(_on_npc_primary_action)
	_spawn_npcs()
	_bind_hotspots()

func _bind_hotspots() -> void:
	if screen_root == null:
		return
	var callback := Callable(self, "_on_hotspot_activated")
	for node in get_tree().get_nodes_in_group("main_city_hotspot"):
		if not screen_root.is_ancestor_of(node):
			continue
		if not node.is_connected("activated", callback):
			node.connect("activated", callback)

func _spawn_npcs() -> void:
	if npc_root == null:
		return
	for child in npc_root.get_children():
		child.queue_free()
	_npc_records_by_id.clear()
	var config: Dictionary = ConfigLoader.load_config("main_city_npcs")
	for record in config.get("npcs", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var npc_record := record as Dictionary
		var npc_id := str(npc_record.get("id", ""))
		if npc_id.is_empty():
			continue
		_npc_records_by_id[npc_id] = npc_record
		var npc := MainCityNPCScript.new()
		npc.setup(npc_record)
		npc.activated.connect(_on_npc_activated)
		npc_root.add_child(npc)

func _on_hotspot_activated(action_id: String) -> void:
	_route_action(action_id, "")

func _on_npc_activated(npc_id: String, _action_id: String) -> void:
	var record: Dictionary = _npc_records_by_id.get(npc_id, {}) as Dictionary
	if record.is_empty() or hud == null:
		return
	hud.show_npc_dialog(record)

func _on_npc_primary_action(action_id: String) -> void:
	_route_action(action_id, "npc")

func _route_action(action_id: String, source: String) -> void:
	match action_id:
		"fishing":
			fishing_requested.emit()
		"home":
			home_requested.emit()
		"games":
			games_requested.emit()
		"shop":
			_show_utility_panel("shop")
			_add_system_message("chat.system.name", "world.hotspot_shop_soon")
		"mail":
			_show_messages_panel()
			_add_system_message("npc.mail_courier.name", "npc.mail_courier.dialogue")
		"notice":
			_show_utility_panel("notice")
			_add_system_message("npc.event_guide.name", "npc.event_guide.dialogue")
		_:
			if source == "npc":
				_add_system_message("chat.system.name", "world.hotspot_shop_soon")

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
