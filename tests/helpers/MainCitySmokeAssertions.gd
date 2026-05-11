extends RefCounted

func assert_image2_hotspot_art(instance: Node, failures: Array[String]) -> void:
	for marker_path in [
		"MapRoot/FishingPierMarker",
		"MapRoot/Entrances/HomeGateHotspot/Marker",
		"MapRoot/InteractionPoints/FishingPierHotspot/Marker",
		"MapRoot/InteractionPoints/GamesHallHotspot/Marker",
		"MapRoot/InteractionPoints/ShopHotspot/Marker",
		"MapRoot/InteractionPoints/TradeMarketHotspot/Marker",
		"MapRoot/InteractionPoints/GuildGardenHotspot/Marker",
		"MapRoot/InteractionPoints/ReturnCityHotspot/Marker",
	]:
		var marker := instance.get_node(marker_path)
		if not marker is Sprite2D:
			failures.append("%s is still a blockout marker." % marker_path)
			continue
		if (marker as Sprite2D).texture == null:
			failures.append("%s is missing an Image 2 texture." % marker_path)
	for prompt_path in [
		"MapRoot/Entrances/HomeGateHotspot/PromptLabel",
		"MapRoot/InteractionPoints/FishingPierHotspot/PromptLabel",
		"MapRoot/InteractionPoints/GamesHallHotspot/PromptLabel",
		"MapRoot/InteractionPoints/ShopHotspot/PromptLabel",
		"MapRoot/InteractionPoints/TradeMarketHotspot/PromptLabel",
		"MapRoot/InteractionPoints/GuildGardenHotspot/PromptLabel",
	]:
		var prompt := instance.get_node(prompt_path) as Label
		if prompt.visible:
			failures.append("%s should be hidden until the hotspot is hovered." % prompt_path)

func assert_image2_terrain(instance: Node, failures: Array[String]) -> void:
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

func assert_main_city_npcs(instance: Node, failures: Array[String]) -> void:
	var npc_root := instance.get_node("MapRoot/NPCRoot")
	if npc_root.get_child_count() < 6:
		failures.append("Main city did not spawn the first NPC batch.")
	for child in npc_root.get_children():
		var sprite := child.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			failures.append("%s is missing an Image 2 NPC texture." % child.name)
		if str(child.get("npc_visual_id")).is_empty():
			failures.append("%s is not bound to a formal Image 2 NPC profession visual." % child.name)
		if str(child.get("avatar_id")).is_empty():
			failures.append("%s is not bound to a formal Image 2 avatar profile." % child.name)
		var shadow := child.get_node_or_null("Shadow") as Polygon2D
		if shadow == null or not shadow.visible:
			failures.append("%s is missing the unified NPC grounding shadow." % child.name)
	if npc_root.get_node_or_null("event_guide") == null:
		failures.append("Main city event guide NPC is missing.")

func assert_runtime_map_bounds(instance: Node, failures: Array[String]) -> void:
	var map_metadata = instance.get("_map_metadata")
	var player := instance.get_node("PlayerRoot/LocalPlayer")
	if map_metadata == null:
		failures.append("Main city did not bind runtime map metadata.")
		return
	if not bool(player.call("can_enter_world_position", player.global_position)):
		failures.append("Default spawn is not accepted by the runtime map bounds.")
	var guild_roof: Vector2 = map_metadata.call("point_to_world", {"x": 220, "y": 100})
	if bool(player.call("can_enter_world_position", guild_roof)):
		failures.append("Runtime map bounds allowed walking into a blocked guild roof.")
	var outside_canvas: Vector2 = map_metadata.call("point_to_world", {"x": -4, "y": 450})
	if bool(player.call("can_enter_world_position", outside_canvas)):
		failures.append("Runtime map bounds allowed walking outside the generated map canvas.")

func utility_rows_contain(panel: Node, text: String) -> bool:
	var rows := panel.find_child("ItemsRows", true, false)
	return rows != null and node_tree_contains(rows, text)

func utility_row_card_count(panel: Node) -> int:
	var rows := panel.find_child("ItemsRows", true, false)
	return _panel_descendant_count(rows) if rows != null else 0

func has_image2_panel(node: Node) -> bool:
	if not node is PanelContainer:
		return false
	var style := (node as PanelContainer).get_theme_stylebox("panel")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func has_image2_button(node: Node) -> bool:
	if not node is Button:
		return false
	var style := (node as Button).get_theme_stylebox("normal")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func has_image2_line_edit(node: Node) -> bool:
	if not node is LineEdit:
		return false
	var style := (node as LineEdit).get_theme_stylebox("normal")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func item_index_for_metadata(picker: OptionButton, value: String) -> int:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			return index
	return -1

func recent_chat_contains(chat_service: Node, text: String) -> bool:
	for message in chat_service.call("get_recent_messages", 8):
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")).contains(text):
			return true
	return false

func assert_recent_chat(chat_service: Node, text: String, failure_text: String, failures: Array[String]) -> void:
	if not recent_chat_contains(chat_service, text):
		failures.append(failure_text)

func assert_current_map(map_runtime, expected_map_id: String, failure_text: String, failures: Array[String]) -> void:
	if map_runtime == null or str(map_runtime.get("current_map_id")) != expected_map_id:
		failures.append(failure_text)

func chat_rows_contain(messages: Array, text: String) -> bool:
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and str((message as Dictionary).get("body", "")).contains(text):
			return true
	return false

func wait_hotspot_debounce(tree: SceneTree) -> void:
	await tree.create_timer(0.5).timeout

func node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if node_tree_contains(child, text):
			return true
	return false

func _panel_descendant_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is PanelContainer:
			count += 1
		count += _panel_descendant_count(child)
	return count
