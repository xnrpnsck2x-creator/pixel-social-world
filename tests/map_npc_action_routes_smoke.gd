extends SceneTree

const AssertionsScript := preload("res://tests/helpers/MainCitySmokeAssertions.gd")

const ACTION_CASES := [
	{
		"map_id": "social_trade_market_v1",
		"npc_id": "trade_broker",
		"button": "Open Trade",
		"panel_text": "Market Board"
	},
	{
		"map_id": "social_guild_garden_v1",
		"npc_id": "guild_coordinator",
		"button": "Guild Desk",
		"panel_text": "Guild Board"
	},
	{
		"map_id": "city_spring_workshop_v1",
		"npc_id": "workshop_master",
		"button": "Workshop",
		"chat_text": "Crafting stations"
	},
	{
		"map_id": "life_crystal_mine_v1",
		"npc_id": "mine_foreman",
		"button": "Mine",
		"chat_text": "Mining nodes"
	}
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var assertions = AssertionsScript.new()
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "map-npc-action-routes",
		"display_name": "NPC Route Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"discovered_world_map_ids": _all_map_ids()
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	for action_case in ACTION_CASES:
		await _assert_action_case(instance, assertions, action_case as Dictionary, failures)
	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("map npc action routes smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_action_case(instance: Node, assertions, action_case: Dictionary, failures: Array[String]) -> void:
	var map_id := str(action_case.get("map_id", ""))
	var npc_id := str(action_case.get("npc_id", ""))
	instance.call("_switch_world_map", map_id, "world.map_travel_generic")
	await process_frame
	await process_frame
	var npc := instance.get_node_or_null("MapRoot/NPCRoot/%s" % npc_id)
	if npc == null:
		failures.append("%s did not spawn action NPC %s." % [map_id, npc_id])
		return
	npc.call("activate")
	await process_frame
	var hud := instance.get_node("WorldHUD")
	var dialog := hud.get_node("Root/MainCityNPCDialog")
	if not bool(dialog.get("visible")):
		failures.append("%s NPC %s did not open its dialog." % [map_id, npc_id])
		return
	var primary_button := dialog.get_node("Margin/Rows/ActionRow/PrimaryButton") as Button
	var expected_button := str(action_case.get("button", ""))
	if primary_button == null or primary_button.text != expected_button:
		failures.append("%s NPC %s primary button was not %s." % [map_id, npc_id, expected_button])
		return
	primary_button.pressed.emit()
	await process_frame
	_assert_action_result(instance, assertions, action_case, failures)

func _assert_action_result(instance: Node, assertions, action_case: Dictionary, failures: Array[String]) -> void:
	var panel_text := str(action_case.get("panel_text", ""))
	if not panel_text.is_empty():
		var facility_panel := instance.get_node("WorldHUD/Root/SocialFacilityPanel")
		if not bool(facility_panel.get("visible")) or not assertions.node_tree_contains(facility_panel, panel_text):
			failures.append("%s did not open facility panel %s." % [action_case.get("npc_id", ""), panel_text])
		return
	var chat_text := str(action_case.get("chat_text", ""))
	var chat_service := instance.get_node("ServiceRoot/ChatService")
	if not chat_text.is_empty() and not assertions.recent_chat_contains(chat_service, chat_text):
		failures.append("%s did not emit route status chat." % action_case.get("npc_id", ""))

func _all_map_ids() -> Array[String]:
	var point_config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var maps: Dictionary = point_config.get("maps", {}) as Dictionary
	var ids: Array[String] = []
	for map_id in maps.keys():
		ids.append(str(map_id))
	return ids
