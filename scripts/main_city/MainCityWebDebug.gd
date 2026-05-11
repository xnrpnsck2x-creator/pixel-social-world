class_name MainCityWebDebug
extends RefCounted

const AvatarDebugScript := preload("res://scripts/main_city/MainCityWebAvatarDebug.gd")

func apply(screen: Node, hud: Node, minigame_session_service: Node) -> void:
	if not _can_use_local_debug():
		return
	var map_id := _query_value("psw_map")
	if not map_id.is_empty() and screen.has_method("_switch_world_map"):
		screen.call("_switch_world_map", map_id, "world.map_debug_enter")
		_mark_debug_map(map_id)
	_mark_debug_map_view(screen)
	if _query_value("psw_activity_rewards") == "sample":
		_seed_activity_rewards()
	if _query_value("psw_trade_seed") == "activity_drop":
		_schedule_trade_seed(screen)
	var hotspot_id := _query_value("psw_hotspot")
	if not hotspot_id.is_empty():
		_schedule_hotspot_feedback(screen, hotspot_id)
	match _query_value("psw_panel"):
		"messages":
			hud.show_messages_panel("mail")
		"messages_private":
			hud.show_messages_panel("private")
		"inventory", "shop", "mail", "notice", "creator", "map", "map_atlas":
			hud.show_utility_panel(_query_value("psw_panel"))
		"room":
			hud.show_room_panel()
		"room_invite":
			_show_debug_room_invite(hud, minigame_session_service)
		"profile":
			var profile_variant_id := _query_value("psw_character_variant")
			if profile_variant_id.is_empty():
				profile_variant_id = "male_melee_v0"
			hud.show_player_profile({
				"player_id": "peer-h5-profile",
				"display_name": "Peer City",
				"character_variant_id": profile_variant_id
			})
	var facility_id := _query_value("psw_facility")
	if not facility_id.is_empty() and hud.has_method("show_social_facility_panel"):
		hud.show_social_facility_panel(facility_id)
		_mark_debug_facility(facility_id)
	var npc_id := _query_value("psw_npc")
	if not npc_id.is_empty():
		_show_debug_npc_dialog(hud, npc_id)
	var ambience_npc_id := _query_value("psw_ambience_npc")
	if not ambience_npc_id.is_empty():
		_schedule_ambience_pose(screen, ambience_npc_id)
	var character_variant_id := _query_value("psw_character_variant")
	if not character_variant_id.is_empty() or _query_value("psw_remote_avatar") == "sample":
		AvatarDebugScript.new().apply(screen)
	if _query_value("psw_first_session") == "complete":
		_complete_first_session(hud)
	var launch_game_id := _query_value("psw_launch_minigame")
	if not launch_game_id.is_empty():
		_launch_debug_minigame(minigame_session_service, launch_game_id)

func _show_debug_npc_dialog(hud: Node, npc_id: String) -> void:
	for record in ConfigLoader.load_config("main_city_npcs").get("npcs", []):
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == npc_id:
			hud.show_npc_dialog((record as Dictionary).duplicate(true))
			_mark_debug_npc(npc_id)
			return

func _schedule_hotspot_feedback(screen: Node, hotspot_id: String) -> void:
	var timer := screen.get_tree().create_timer(4.85)
	timer.timeout.connect(func() -> void:
		var hotspot := _find_hotspot(screen, hotspot_id)
		if hotspot != null and hotspot.has_method("show_prompt_feedback"):
			hotspot.call("show_prompt_feedback", 1.8)
			_mark_debug_hotspot(hotspot_id)
			if hotspot.has_method("debug_prompt_screen_rect"):
				_mark_debug_hotspot_rect(hotspot.call("debug_prompt_screen_rect"))
		)

func _schedule_ambience_pose(screen: Node, npc_id: String) -> void:
	var timer := screen.get_tree().create_timer(0.85)
	timer.timeout.connect(func() -> void:
		_show_ambience_pose(screen, npc_id)
	)

func _show_ambience_pose(screen: Node, npc_id: String) -> void:
	var npc := screen.get_node_or_null("MapRoot/NPCRoot/%s" % npc_id)
	if npc == null:
		_mark_debug_ambience({"npc": npc_id, "ok": false, "reason": "missing"})
		return
	var poses := _ambience_poses_for_npc(npc)
	if poses.is_empty():
		_mark_debug_ambience({"npc": npc_id, "ok": false, "reason": "no_pose"})
		return
	var pose_id := str(poses[0])
	npc.set("pose", pose_id)
	if npc.has_method("_refresh"):
		npc.call("_refresh")
	_focus_local_player_near(screen, npc)
	_mark_debug_map_view(screen)
	var sprite := npc.get_node_or_null("Sprite") as Sprite2D
	_mark_debug_ambience({
		"npc": npc_id,
		"pose": pose_id,
		"ok": true,
		"texture": "" if sprite == null or sprite.texture == null else str(sprite.texture.resource_path)
	})

func _ambience_poses_for_npc(npc: Node) -> Array:
	if npc.has_meta("ambience_poses"):
		return npc.get_meta("ambience_poses") as Array
	var visual_id := str(npc.get("npc_visual_id"))
	for role in ConfigLoader.load_config("npc_professions").get("roles", []):
		if typeof(role) == TYPE_DICTIONARY and str((role as Dictionary).get("id", "")) == visual_id:
			return (role as Dictionary).get("ambience_poses", []) as Array
	return []

func _focus_local_player_near(screen: Node, npc: Node) -> void:
	var player := screen.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	var actor := npc as Node2D
	if player != null and actor != null:
		player.global_position = actor.global_position + Vector2(0, 96)

func _find_hotspot(screen: Node, hotspot_id: String) -> Node:
	for node in screen.get_tree().get_nodes_in_group("main_city_hotspot"):
		if not screen.is_ancestor_of(node):
			continue
		if str(node.name) == hotspot_id or str(node.get("action_id")) == hotspot_id:
			return node
	return null

func _show_debug_room_invite(hud: Node, minigame_session_service: Node) -> void:
	if minigame_session_service == null:
		return
	hud.show_room_panel()
	var response: Dictionary = await minigame_session_service.create_session("fishing")
	var session: Dictionary = response.get("data", {}) as Dictionary
	hud.get_node("Root/OnlineRoomPanel").call("_announce_game_invite", "fishing", str(session.get("id", "")))

func _launch_debug_minigame(minigame_session_service: Node, game_id: String) -> void:
	if minigame_session_service != null:
		minigame_session_service.launch_game(game_id)
		return
	SaveSystem.set_profile_value("pending_minigame_id", game_id)
	SaveSystem.set_profile_value("pending_minigame_session_id", "h5_debug")
	SaveSystem.save_profile()
	SceneRouter.route_to("minigame_fishing")

func _complete_first_session(hud: Node) -> void:
	var guide = hud.get("first_session_guide")
	if guide == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var client := tree.root.get_node_or_null("OnlineClient")
	var was_connected := false
	if client != null:
		was_connected = bool(client.get("is_connected"))
		client.set("is_connected", false)
	for event_id in ["npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"]:
		guide.call("record_event", event_id)
	if client != null:
		client.set("is_connected", was_connected)
	_mark_debug_first_session("complete", SaveSystem.get_coin_balance())

func _seed_activity_rewards() -> void:
	SaveSystem.set_profile_value("map_activity_inventory", {
		"trail_token": {"item_id": "trail_token", "quantity": 2, "rarity": "common"}
	})
	SaveSystem.set_profile_value("map_activity_skill_xp", {"exploration": 4})
	SaveSystem.save_profile()

func _schedule_trade_seed(screen: Node) -> void:
	var timer := screen.get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		_seed_trade_inventory_online(screen, 0)
	)

func _seed_trade_inventory_online(screen: Node, attempt: int) -> void:
	var service := screen.get_node_or_null("ServiceRoot/SocialFacilityService")
	if service != null:
		_ensure_debug_trade_inventory(service)
	var client := screen.get_node_or_null("/root/OnlineClient")
	if client == null or not bool(client.get("is_connected")):
		if attempt < 5:
			var retry := screen.get_tree().create_timer(0.75)
			retry.timeout.connect(func() -> void:
				_seed_trade_inventory_online(screen, attempt + 1)
			)
		else:
			_mark_debug_trade_seed({"ok": false, "reason": "offline"})
		return
	var response: Dictionary = await client.call("claim_map_activity", "random_flower_valley_v1", "explore")
	var ok := bool(response.get("ok", false)) or str(response.get("error", "")) == "activity_cooldown"
	if service != null and service.has_method("refresh"):
		await service.call("refresh")
		_ensure_debug_trade_inventory(service)
	_mark_debug_trade_seed({
		"ok": ok,
		"status": int(response.get("status", 0)),
		"error": str(response.get("error", "")),
	})

func _ensure_debug_trade_inventory(service: Node) -> void:
	var inventory: Array = service.get("trade_inventory") as Array
	if not inventory.is_empty():
		return
	service.set("trade_inventory", [{
		"player_id": str(service.call("_player_id")) if service.has_method("_player_id") else SaveSystem.get_player_id(),
		"item_id": "simple_chair",
		"owned": 1,
		"locked": 0,
		"available": 1,
	}])
	if service.has_signal("facilities_updated") and service.has_method("get_catalog"):
		service.facilities_updated.emit(service.call("get_catalog"))

func _can_use_local_debug() -> bool:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return false
	var network: Dictionary = App.app_config.get("network", {}) as Dictionary
	return ["local_dev", "local_alpha"].has(str(network.get("environment", "")))

func _query_value(key: String) -> String:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var script := "new URLSearchParams(window.location.search).get('%s') || ''" % key
	var value: Variant = bridge.call("eval", script, true)
	return str(value) if typeof(value) == TYPE_STRING else ""

func _mark_debug_map(map_id: String) -> void:
	_mark_debug("__psw_debug_map", map_id)

func _mark_debug_map_view(screen: Node) -> void:
	var player := screen.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	var metadata = screen.get("_map_metadata")
	if player == null or metadata == null:
		_mark_debug("__psw_debug_map_view", null)
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		_mark_debug("__psw_debug_map_view", null)
		return
	var viewport_size := screen.get_viewport().get_visible_rect().size
	var canvas_size := Vector2.ZERO
	var raw_canvas: Variant = metadata.get("canvas_size")
	if typeof(raw_canvas) == TYPE_VECTOR2:
		canvas_size = raw_canvas
	var center := camera.global_position
	if camera.has_method("get_screen_center_position"):
		center = camera.call("get_screen_center_position")
	_mark_debug("__psw_debug_map_view", {
		"canvas_width": canvas_size.x,
		"canvas_height": canvas_size.y,
		"center_x": center.x,
		"center_y": center.y,
		"zoom_x": camera.zoom.x,
		"zoom_y": camera.zoom.y,
		"viewport_width": viewport_size.x,
		"viewport_height": viewport_size.y
	})

func _mark_debug_facility(facility_id: String) -> void:
	_mark_debug("__psw_debug_facility", facility_id)

func _mark_debug_npc(npc_id: String) -> void:
	_mark_debug("__psw_debug_npc", npc_id)

func _mark_debug_ambience(data: Dictionary) -> void:
	_mark_debug("__psw_debug_npc_ambience", data)

func _mark_debug_hotspot(hotspot_id: String) -> void:
	_mark_debug("__psw_debug_hotspot", hotspot_id)

func _mark_debug_hotspot_rect(rect: Dictionary) -> void:
	_mark_debug("__psw_debug_hotspot_rect", rect)

func _mark_debug_first_session(state: String, coin_balance: int) -> void:
	_mark_debug("__psw_debug_first_session", state)
	_mark_debug("__psw_debug_coin_balance", coin_balance)

func _mark_debug_trade_seed(data: Dictionary) -> void:
	_mark_debug("__psw_debug_trade_seed", data)

func _mark_debug(name: String, value: Variant) -> void:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	bridge.call("eval", "globalThis.%s = %s" % [name, JSON.stringify(value)], true)
