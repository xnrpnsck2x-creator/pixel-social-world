extends SceneTree
const AssertionsScript := preload("res://tests/helpers/MainCitySmokeAssertions.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var failures: Array[String] = []
	var assertions = AssertionsScript.new()
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "main-city-interactions-player",
		"device_id": "test-device",
		"display_name": "City Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"map_activity_inventory": {"trail_token": {"item_id": "trail_token", "quantity": 2, "rarity": "common"}},
		"map_activity_skill_xp": {"exploration": 4},
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {
		"offline_mode_enabled": true,
		"network": {"online_enabled": false}
	})
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	if instance.get_node_or_null("InteractionController") == null:
		failures.append("Main city interactions were not split into InteractionController.")
	assertions.assert_image2_hotspot_art(instance, failures)
	assertions.assert_image2_terrain(instance, failures)
	assertions.assert_main_city_npcs(instance, failures)
	assertions.assert_runtime_map_bounds(instance, failures)
	var hud := instance.get_node("WorldHUD")
	var hud_root := hud.get_node("Root") as Control
	if hud_root == null or hud_root.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		failures.append("HUD Root must ignore mouse input so map NPCs and hotspots stay clickable.")
	var mail_badge := hud.get_node("Root/TopBar/TopMargin/TopRow/SocialButton/MailUnreadBadge") as Label
	var messages_panel := hud.get_node("Root/SocialMessagesPanel")
	messages_panel.call("_set_unread_count", 12)
	await process_frame
	if mail_badge == null or not mail_badge.visible or mail_badge.text != "9+":
		failures.append("HUD social button did not show a capped unread badge.")
	var picker := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/ChannelPicker") as OptionButton
	if picker.item_count < 2:
		failures.append("Chat channel picker did not include multiple channels.")
	else:
		var nearby_index := assertions.item_index_for_metadata(picker, "nearby")
		if nearby_index < 0:
			failures.append("Chat channel picker did not include nearby.")
		else:
			picker.select(nearby_index)
			picker.item_selected.emit(nearby_index)
			var input := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/ChatInput") as LineEdit
			input.text = "nearby smoke"
			hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/SendButton").pressed.emit()
			await process_frame
			var chat_service := instance.get_node("ServiceRoot/ChatService")
			var recent: Array = chat_service.call("get_recent_messages", 1)
			if recent.is_empty() or str((recent.back() as Dictionary).get("channel_id", "")) != "nearby":
				failures.append("Chat message did not use the selected nearby channel.")
			chat_service.call("set_view_channel", "global")
			if assertions.chat_rows_contain(chat_service.call("get_visible_messages", 10), "nearby smoke"):
				failures.append("Global chat view leaked a nearby-only message.")
				chat_service.call("set_view_channel", "nearby")
				if not assertions.chat_rows_contain(chat_service.call("get_visible_messages", 10), "nearby smoke"):
					failures.append("Nearby chat view did not show its own message.")
	var panel := hud.get_node("Root/OnlineRoomPanel")
	instance.get_node("MapRoot/InteractionPoints/GamesHallHotspot").call("activate")
	await process_frame
	var map_runtime = instance.get("_map_runtime")
	assertions.assert_current_map(map_runtime, "social_minigame_arcade_hall_v1", "Games Hall hotspot did not switch to the Image 2 arcade hall map.", failures)
	assertions.assert_recent_chat(instance.get_node("ServiceRoot/ChatService"), "New route discovered: Minigame Arcade Hall", "First map unlock did not show a route discovery notice.", failures)
	var unlock_toast := hud.get_node_or_null("Root/MapUnlockToast")
	if unlock_toast == null or not bool(unlock_toast.get("visible")) or not assertions.node_tree_contains(unlock_toast, "Minigame Arcade Hall"):
		failures.append("First map unlock did not show a compact HUD toast.")
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/GamesHallHotspot").call("activate")
	await process_frame
	if not bool(panel.get("visible")):
		failures.append("Arcade hall games hotspot did not open the room panel.")
	var presence_service := instance.get_node("ServiceRoot/PresenceService")
	var fake_members: Array[Dictionary] = [
		{"player_id": "main-city-interactions-player", "room_id": "world_town_square", "display_name": "City Smoke", "last_seen_at": int(Time.get_unix_time_from_system())},
		{"player_id": "peer-city-smoke", "room_id": "world_town_square", "display_name": "Peer City", "character_variant_id": "female_ranged_v0", "last_seen_at": int(Time.get_unix_time_from_system())}
	]
	presence_service.set("members", fake_members)
	panel.call("_refresh_presence")
	panel.get_node("Margin/Rows/MemberActionRow/PrivateMemberButton").pressed.emit()
	await process_frame
	var profile_card := hud.get_node("Root/PlayerProfileCard")
	if not bool(profile_card.get("visible")):
		failures.append("Room member profile action did not open the player card.")
	elif not assertions.node_tree_contains(profile_card, "Peer City"):
		failures.append("Room member profile card did not show the selected player.")
	elif not assertions.node_tree_contains(profile_card, "Female Ranged") or not assertions.node_tree_contains(profile_card, "Far"):
		failures.append("Room member profile card did not show the selected player role/range.")
	var profile_preview := profile_card.get_node_or_null("%AvatarPreview") as TextureRect
	if profile_preview == null or profile_preview.texture == null:
		failures.append("Room member profile card did not show a character preview.")
	elif not profile_preview.texture.resource_path.contains("player_female_ranged_actions_v1"):
		failures.append("Room member profile card did not show the selected character variant preview.")
	if not profile_card.has_node("%FollowButton") or not profile_card.has_node("%BlockButton"):
		failures.append("Player profile card did not expose follow/block actions.")
	profile_card.get_node("%ReportButton").pressed.emit()
	await process_frame
	var report_chat_service := instance.get_node("ServiceRoot/ChatService")
	if not assertions.recent_chat_contains(report_chat_service, "online session"):
		failures.append("Offline player profile report did not show an online-session notice.")
	profile_card.get_node("%PrivateButton").pressed.emit()
	await process_frame
	if not bool(messages_panel.get("visible")):
		failures.append("Player profile private action did not open the messages panel.")
	elif not bool(messages_panel.get_node("%PrivateBox").get("visible")):
		failures.append("Player profile private action did not open the private tab.")
	elif str(messages_panel.get_node("%PeerInput").text) != "peer-city-smoke":
		failures.append("Player profile private action did not prefill the selected peer.")
	messages_panel.call("hide_panel")
	instance.call("_on_presence_updated", fake_members, true, 0)
	await process_frame
	var remote_root := instance.get_node("PlayerRoot/RemotePlayers")
	if remote_root.get_child_count() == 0:
		failures.append("Remote presence did not create a clickable remote avatar.")
	else:
		remote_root.get_child(0).emit_signal("profile_requested", {
			"player_id": "peer-city-smoke",
			"display_name": "Peer City",
			"character_variant_id": "female_ranged_v0"
		})
		await process_frame
		if not bool(profile_card.get("visible")):
			failures.append("Remote avatar profile signal did not open the player card.")
		elif not assertions.node_tree_contains(profile_card, "Peer City"):
			failures.append("Remote avatar profile card did not show the selected player.")
		elif not assertions.node_tree_contains(profile_card, "Female Ranged") or not assertions.node_tree_contains(profile_card, "Far"):
			failures.append("Remote avatar profile card did not show the selected player role/range.")
		profile_card.call("hide_card")
		instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
		await process_frame
		if str(map_runtime.get("current_map_id")) != "city_forest_dawn_v1":
			failures.append("Return city hotspot did not switch back to the main city map.")
		var tap_move_controller = instance.get("_tap_move_controller")
		if tap_move_controller == null:
			failures.append("Main city did not install the tap-to-move controller.")
		else:
			var shop_hotspot := instance.get_node("MapRoot/InteractionPoints/ShopHotspot") as Node2D
			var shop_screen_point := shop_hotspot.get_global_transform_with_canvas() * Vector2.ZERO
			tap_move_controller.call("_handle_tap", shop_screen_point)
			await process_frame
			assertions.assert_current_map(map_runtime, "city_port_market_v1", "Tap-to-move hotspot routing did not switch to the port market map.", failures)
			await assertions.wait_hotspot_debounce(self)
			instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
			await process_frame
			assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "Return city hotspot did not switch back after tap-to-move hotspot routing.", failures)
		instance.get_node("MapRoot/InteractionPoints/ShopHotspot").call("activate")
		await process_frame
		assertions.assert_current_map(map_runtime, "city_port_market_v1", "Shop hotspot did not route to the Image 2 port market map.", failures)
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/ShopHotspot").call("activate")
	await process_frame
	var chat_service := instance.get_node("ServiceRoot/ChatService")
	assertions.assert_recent_chat(chat_service, "preparing stock", "Shop hotspot did not add a system chat notice.", failures)
	var utility_panel := hud.get_node("Root/WorldUtilityPanel")
	var facility_panel := hud.get_node("Root/SocialFacilityPanel")
	var utility_title := utility_panel.get_node("Margin/Rows/HeaderRow/TitleLabel") as Label
	if not bool(utility_panel.get("visible")) or utility_title == null or utility_title.text != "Item Shop" or not assertions.utility_rows_contain(utility_panel, "Simple Chair"):
		failures.append("Port market shop hotspot did not open the configured shop panel.")
	hud.show_utility_panel("map")
	await process_frame
	if not bool(utility_panel.get("visible")) or not assertions.node_tree_contains(utility_panel, "Spring Workshop") or not assertions.node_tree_contains(utility_panel, "Maps"):
		failures.append("World map directory did not show registered Image 2 maps with collection progress.")
	if not assertions.node_tree_contains(utility_panel, "Activity progress") or not assertions.node_tree_contains(utility_panel, "routes"):
		failures.append("World map directory did not summarize map activity progression and route density.")
	if str(save_system.call("get_profile_value", "current_world_map_id", "")) != "city_port_market_v1":
		failures.append("World map runtime did not persist the current map id for directory state.")
	var discovered_maps: Array = save_system.call("get_profile_value", "discovered_world_map_ids", [])
	if not discovered_maps.has("city_port_market_v1"):
		failures.append("World map runtime did not mark visited maps as discovered.")
	if not assertions.node_tree_contains(utility_panel, root.get_node("App").call("t_key", "world.panel.map.current_action")) or not assertions.node_tree_contains(utility_panel, root.get_node("App").call("t_key", "world.panel.map.state.unlocked")):
		failures.append("World map directory did not mark current and unlocked route states.")
	if not assertions.node_tree_contains(utility_panel, root.get_node("App").call("t_key", "world.panel.map.undiscovered_action")):
		failures.append("World map directory did not mark undiscovered maps as exploration targets.")
	if not assertions.node_tree_contains(utility_panel, "Follow the workshop sign"):
		failures.append("World map directory did not show an unlock hint for undiscovered maps.")
	utility_panel.emit_signal("utility_action_requested", "map:city_spring_workshop_v1")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_port_market_v1", "World map directory allowed travel to an undiscovered map.", failures)
	assertions.assert_recent_chat(chat_service, "Discover this route", "World map directory did not explain the undiscovered route lock.", failures)
	utility_panel.emit_signal("utility_action_requested", "map:city_forest_dawn_v1")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "World map directory did not travel to an already discovered map.", failures)
	instance.get_node("MapRoot/InteractionPoints/TradeMarketHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "social_trade_market_v1", "Trade hotspot did not route to the Image 2 trade market map.", failures)
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/TradeMarketHotspot").call("activate")
	await process_frame
	assertions.assert_recent_chat(chat_service, "short-on-coins", "Trade market hotspot did not explain the live trading board priority order.", failures)
	if not bool(facility_panel.get("visible")) or not assertions.node_tree_contains(facility_panel, "Market Board"):
		failures.append("Trade market hotspot did not open the configured facility panel.")
	instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "Trade market return hotspot did not switch back to the main city map.", failures)
	instance.get_node("MapRoot/InteractionPoints/GuildGardenHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "social_guild_garden_v1", "Guild hotspot did not route to the Image 2 guild garden map.", failures)
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/GuildGardenHotspot").call("activate")
	await process_frame
	assertions.assert_recent_chat(chat_service, "guild desk", "Guild garden hotspot reused the wrong panel/action instead of its own status notice.", failures)
	if not bool(facility_panel.get("visible")) or not assertions.node_tree_contains(facility_panel, "Guild Board"):
		failures.append("Guild garden hotspot did not open the configured facility panel.")
	instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "Guild garden return hotspot did not switch back to the main city map.", failures)
	instance.get_node("MapRoot/InteractionPoints/WorkshopHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_spring_workshop_v1", "Workshop hotspot did not route to the Image 2 spring workshop map.", failures)
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/WorkshopHotspot").call("activate")
	await process_frame
	assertions.assert_recent_chat(chat_service, "Crafting stations", "Spring workshop hotspot did not add its crafting status notice.", failures)
	instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "Spring workshop return hotspot did not switch back to the main city map.", failures)
	instance.get_node("MapRoot/InteractionPoints/MineHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "life_crystal_mine_v1", "Mine hotspot did not route to the Image 2 crystal mine map.", failures)
	await assertions.wait_hotspot_debounce(self)
	instance.get_node("MapRoot/InteractionPoints/MineHotspot").call("activate")
	await process_frame
	assertions.assert_recent_chat(chat_service, "Mining nodes", "Crystal mine hotspot did not add its mining status notice.", failures)
	instance.get_node("MapRoot/InteractionPoints/ReturnCityHotspot").call("activate")
	await process_frame
	assertions.assert_current_map(map_runtime, "city_forest_dawn_v1", "Crystal mine return hotspot did not switch back to the main city map.", failures)
	var event_guide := instance.get_node_or_null("MapRoot/NPCRoot/event_guide")
	if event_guide == null:
		failures.append("Event guide NPC was missing after returning to the main city map.")
	else:
		event_guide.call("activate")
		await process_frame
	var npc_dialog := hud.get_node("Root/MainCityNPCDialog")
	if event_guide != null:
		if not bool(npc_dialog.get("visible")):
			failures.append("Event guide NPC did not open the service dialog.")
		else:
			var body_label := npc_dialog.get_node("Margin/Rows/BodyLabel") as Label
			if body_label == null or not body_label.text.contains("town board"):
				failures.append("NPC service dialog did not show localized dialogue.")
			var portrait_texture := npc_dialog.get_node("Margin/Rows/HeaderRow/PortraitFrame/PortraitMargin/PortraitTexture") as TextureRect
			var role_label := npc_dialog.get_node("Margin/Rows/HeaderRow/HeaderTextRows/RoleLabel") as Label
			var duty_label := npc_dialog.get_node("Margin/Rows/HeaderRow/HeaderTextRows/DutyLabel") as Label
			if portrait_texture == null or portrait_texture.texture == null or role_label == null or not role_label.text.contains("Role:") or duty_label == null or duty_label.text.is_empty():
				failures.append("NPC service dialog missing profession portrait, role, or duty.")

	var game_host := instance.get_node_or_null("MapRoot/NPCRoot/game_host")
	if game_host == null:
		failures.append("Game Host NPC was missing after returning to the main city map.")
	else:
		panel.visible = false
		game_host.call("activate")
		await process_frame
		var primary_button := npc_dialog.get_node("Margin/Rows/ActionRow/PrimaryButton") as Button
		if primary_button == null or primary_button.text != "Open Game Hall":
			failures.append("Game Host NPC dialog did not expose the Game Hall primary action.")
		else:
			primary_button.pressed.emit()
			await process_frame
			if map_runtime == null or str(map_runtime.get("current_map_id")) != "social_minigame_arcade_hall_v1":
				failures.append("Game Host NPC primary action did not route to the arcade hall map.")
			else:
				panel.visible = false
				game_host = instance.get_node_or_null("MapRoot/NPCRoot/game_host")
				if game_host != null:
					game_host.call("activate")
					await process_frame
					primary_button.pressed.emit()
					await process_frame
				if not bool(panel.get("visible")):
					failures.append("Arcade Game Host NPC primary action did not open the room panel.")
	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	if failures.is_empty():
		print("main city interactions smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
