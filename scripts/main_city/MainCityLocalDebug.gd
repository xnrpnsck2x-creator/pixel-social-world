class_name MainCityLocalDebug
extends RefCounted

const WebDebugScript := preload("res://scripts/main_city/MainCityWebDebug.gd")
const ANDROID_DEBUG_STARTUP_PATH := "user://android_debug_startup.json"

func apply(screen: Node, hud: Node, minigame_session_service: Node) -> void:
	WebDebugScript.new().apply(screen, hud, minigame_session_service)
	if not _can_use_android_debug():
		return
	var data := _read_android_debug_startup()
	if data.is_empty():
		return
	var map_id := str(data.get("map_id", ""))
	if not map_id.is_empty() and screen.has_method("_switch_world_map"):
		screen.call("_switch_world_map", map_id, "world.map_debug_enter")
	var panel_id := str(data.get("panel", ""))
	if not panel_id.is_empty():
		_show_debug_panel(hud, panel_id)
	var facility_id := str(data.get("facility", ""))
	if not facility_id.is_empty() and hud.has_method("show_social_facility_panel"):
		hud.call("show_social_facility_panel", facility_id)
	var npc_id := str(data.get("npc", ""))
	if not npc_id.is_empty():
		_show_debug_npc_dialog(hud, npc_id)
	var launch_game_id := str(data.get("launch_minigame", ""))
	if not launch_game_id.is_empty():
		_launch_debug_minigame(minigame_session_service, launch_game_id)

func _show_debug_panel(hud: Node, panel_id: String) -> void:
	match panel_id:
		"messages":
			if hud.has_method("show_messages_panel"):
				hud.call("show_messages_panel", "mail")
		"messages_private":
			if hud.has_method("show_messages_panel"):
				hud.call("show_messages_panel", "private")
		"room":
			if hud.has_method("show_room_panel"):
				hud.call("show_room_panel")
		"profile":
			if hud.has_method("show_player_profile"):
				hud.call("show_player_profile", _debug_profile())
		_:
			if hud.has_method("show_utility_panel"):
				hud.call("show_utility_panel", panel_id)

func _debug_profile() -> Dictionary:
	return {
		"player_id": "peer-android-profile",
		"display_name": "Peer City",
		"character_variant_id": "male_melee_v0",
		"class_id": "melee",
		"character_name_key": "character.variant.male_melee"
	}

func _show_debug_npc_dialog(hud: Node, npc_id: String) -> void:
	for record in ConfigLoader.load_config("main_city_npcs").get("npcs", []):
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == npc_id:
			hud.call("show_npc_dialog", (record as Dictionary).duplicate(true))
			return

func _launch_debug_minigame(minigame_session_service: Node, game_id: String) -> void:
	if minigame_session_service != null and minigame_session_service.has_method("launch_game"):
		minigame_session_service.call("launch_game", game_id)
		return
	SaveSystem.set_profile_value("pending_minigame_id", game_id)
	SaveSystem.set_profile_value("pending_minigame_session_id", "android_debug")
	SaveSystem.save_profile()
	SceneRouter.route_to("minigame_fishing")

func _can_use_android_debug() -> bool:
	return OS.has_feature("android") and OS.is_debug_build()

func _read_android_debug_startup() -> Dictionary:
	if not FileAccess.file_exists(ANDROID_DEBUG_STARTUP_PATH):
		return {}
	var file := FileAccess.open(ANDROID_DEBUG_STARTUP_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}
