extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
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
	_assert_image2_hotspot_art(instance, failures)
	_assert_image2_terrain(instance, failures)
	_assert_main_city_npcs(instance, failures)

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
		var nearby_index := _item_index_for_metadata(picker, "nearby")
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
			if _chat_rows_contain(chat_service.call("get_visible_messages", 10), "nearby smoke"):
				failures.append("Global chat view leaked a nearby-only message.")
			chat_service.call("set_view_channel", "nearby")
			if not _chat_rows_contain(chat_service.call("get_visible_messages", 10), "nearby smoke"):
				failures.append("Nearby chat view did not show its own message.")

	var panel := hud.get_node("Root/OnlineRoomPanel")
	instance.get_node("MapRoot/InteractionPoints/GamesHallHotspot").call("activate")
	await process_frame
	if not bool(panel.get("visible")):
		failures.append("Games Hall hotspot did not open the room panel.")
	var presence_service := instance.get_node("ServiceRoot/PresenceService")
	var fake_members: Array[Dictionary] = [
		{"player_id": "main-city-interactions-player", "room_id": "world_town_square", "display_name": "City Smoke", "last_seen_at": int(Time.get_unix_time_from_system())},
		{"player_id": "peer-city-smoke", "room_id": "world_town_square", "display_name": "Peer City", "last_seen_at": int(Time.get_unix_time_from_system())}
	]
	presence_service.set("members", fake_members)
	panel.call("_refresh_presence")
	panel.get_node("Margin/Rows/MemberActionRow/PrivateMemberButton").pressed.emit()
	await process_frame
	var profile_card := hud.get_node("Root/PlayerProfileCard")
	if not bool(profile_card.get("visible")):
		failures.append("Room member profile action did not open the player card.")
	elif not _node_tree_contains(profile_card, "Peer City"):
		failures.append("Room member profile card did not show the selected player.")
	profile_card.get_node("%ReportButton").pressed.emit()
	await process_frame
	var report_chat_service := instance.get_node("ServiceRoot/ChatService")
	if not _recent_chat_contains(report_chat_service, "online session"):
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
			"display_name": "Peer City"
		})
		await process_frame
		if not bool(profile_card.get("visible")):
			failures.append("Remote avatar profile signal did not open the player card.")
		elif not _node_tree_contains(profile_card, "Peer City"):
			failures.append("Remote avatar profile card did not show the selected player.")
		profile_card.call("hide_card")

	instance.get_node("MapRoot/InteractionPoints/ShopHotspot").call("activate")
	await process_frame
	var chat_service := instance.get_node("ServiceRoot/ChatService")
	if not _recent_chat_contains(chat_service, "preparing stock"):
		failures.append("Shop hotspot did not add a system chat notice.")
	var utility_panel := hud.get_node("Root/WorldUtilityPanel")
	if not bool(utility_panel.get("visible")):
		failures.append("Shop hotspot did not open the utility panel.")
	else:
		var utility_title := utility_panel.get_node("Margin/Rows/HeaderRow/TitleLabel") as Label
		if utility_title == null or utility_title.text != "Item Shop":
			failures.append("Shop utility panel did not render the shop shell.")
		if not _utility_rows_contain(utility_panel, "Simple Chair"):
			failures.append("Shop utility panel did not render configured shop stock.")

	instance.get_node("MapRoot/NPCRoot/event_guide").call("activate")
	await process_frame
	var npc_dialog := hud.get_node("Root/MainCityNPCDialog")
	if not bool(npc_dialog.get("visible")):
		failures.append("Event guide NPC did not open the service dialog.")
	else:
		var body_label := npc_dialog.get_node("Margin/Rows/BodyLabel") as Label
		if body_label == null or not body_label.text.contains("town board"):
			failures.append("NPC service dialog did not show localized dialogue.")

	instance.get_node("MapRoot/NPCRoot/game_host").call("activate")
	await process_frame
	var primary_button := npc_dialog.get_node("Margin/Rows/ActionRow/PrimaryButton") as Button
	if primary_button == null or primary_button.text != "Open Game Hall":
		failures.append("Game Host NPC dialog did not expose the Game Hall primary action.")
	else:
		primary_button.pressed.emit()
		await process_frame
		if not bool(panel.get("visible")):
			failures.append("Game Host NPC primary action did not open the room panel.")

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

func _item_index_for_metadata(picker: OptionButton, value: String) -> int:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			return index
	return -1

func _recent_chat_contains(chat_service: Node, text: String) -> bool:
	for message in chat_service.call("get_recent_messages", 8):
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")).contains(text):
			return true
	return false

func _chat_rows_contain(messages: Array, text: String) -> bool:
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")).contains(text):
			return true
	return false

func _assert_image2_hotspot_art(instance: Node, failures: Array[String]) -> void:
	var marker_paths := [
		"MapRoot/FishingPierMarker",
		"MapRoot/Entrances/HomeGateHotspot/Marker",
		"MapRoot/InteractionPoints/FishingPierHotspot/Marker",
		"MapRoot/InteractionPoints/GamesHallHotspot/Marker",
		"MapRoot/InteractionPoints/ShopHotspot/Marker",
	]
	for marker_path in marker_paths:
		var marker := instance.get_node(marker_path)
		if not marker is Sprite2D:
			failures.append("%s is still a blockout marker." % marker_path)
			continue
		var sprite := marker as Sprite2D
		if sprite.texture == null:
			failures.append("%s is missing an Image 2 texture." % marker_path)

func _assert_image2_terrain(instance: Node, failures: Array[String]) -> void:
	var terrain := instance.get_node_or_null("MapRoot/TerrainPainter")
	if terrain == null:
		failures.append("Main city is missing the Image 2 terrain painter.")
		return
	for blockout_path in ["MapRoot/StonePlaza", "MapRoot/NorthPath", "MapRoot/SouthPath", "MapRoot/WaterEdge"]:
		var blockout := instance.get_node_or_null(blockout_path) as CanvasItem
		if blockout != null and blockout.visible:
			failures.append("%s blockout shape must stay hidden behind Image 2 terrain." % blockout_path)
	if terrain.get_child_count() < 120:
		failures.append("Main city terrain painter did not create the first map tile field.")
	for child in terrain.get_children():
		if child is Sprite2D:
			var sprite := child as Sprite2D
			if sprite.texture == null:
				failures.append("Main city terrain includes a sprite without an Image 2 texture.")
			if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
				failures.append("Main city terrain sprite filtering is not pixel-crisp.")
			return
	failures.append("Main city terrain painter did not create Sprite2D terrain nodes.")

func _assert_main_city_npcs(instance: Node, failures: Array[String]) -> void:
	var npc_root := instance.get_node("MapRoot/NPCRoot")
	if npc_root.get_child_count() < 6:
		failures.append("Main city did not spawn the first NPC batch.")
	for child in npc_root.get_children():
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			failures.append("%s is missing an Image 2 NPC texture." % child.name)
	if npc_root.get_node_or_null("event_guide") == null:
		failures.append("Main city event guide NPC is missing.")

func _utility_rows_contain(panel: Node, text: String) -> bool:
	var rows := panel.find_child("ItemsRows", true, false)
	if rows == null:
		return false
	return _node_tree_contains(rows, text)

func _node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _node_tree_contains(child, text):
			return true
	return false
