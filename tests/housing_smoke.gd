extends SceneTree

const HousingServiceScript := preload("res://scripts/Systems/Housing/HousingService.gd")
const HousingRoomEditControllerScript := preload("res://scripts/UI/Panels/HousingRoomEditController.gd")
const HOUSING_SCENE := "res://scenes/housing/HousingRoom.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system: Node = root.get_node("SaveSystem")
	var online_client: Node = root.get_node("OnlineClient")
	var original_profile: Dictionary = save_system.call("load_profile").duplicate(true)
	var original_online_state := {
		"is_connected": bool(online_client.get("is_connected")),
		"access_token": str(online_client.get("access_token")),
		"player_id": str(online_client.get("player_id"))
	}
	save_system.set("profile", {
		"display_name": "Housing Test",
		"locale": "en",
		"coin_balance": 100,
		"current_route": "home_edit",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": []
	})
	online_client.set("is_connected", true)
	online_client.set("access_token", "")
	online_client.set("player_id", "offline-player")

	var service: Node = HousingServiceScript.new()
	root.add_child(service)
	service.initialize()
	if service.get("online_sync") == null:
		failures.append("Housing service online sync boundary was not initialized.")
	elif bool(service.get("online_sync").has_online_connection()):
		failures.append("Housing accepted a stale online session without an access token.")

	if not service.place_item("simple_chair", Vector2i(1, 1)):
		failures.append("Failed to place simple_chair.")
	if int(save_system.call("get_coin_balance")) != 75:
		failures.append("simple_chair did not spend 25 coins.")

	if not service.place_item("wooden_floor", Vector2i.ZERO):
		failures.append("Failed to apply floor style.")
	if int(save_system.call("get_coin_balance")) != 67:
		failures.append("wooden_floor did not spend 8 coins.")

	var styles: Dictionary = service.get_styles()
	if str(styles.get("floor", "")) != "wooden_floor":
		failures.append("Floor style was not saved.")
	if service.place_item("tiny_table", Vector2i(7, 4)):
		failures.append("Out-of-bounds furniture placement was allowed.")
	if service.place_item("potted_plant", Vector2i(1, 1)):
		failures.append("Overlapping furniture placement was allowed.")
	if int(save_system.call("get_coin_balance")) != 67:
		failures.append("Invalid furniture placement spent coins.")

	var placed_item: Dictionary = service.get_item_at_tile(Vector2i(1, 1))
	if placed_item.is_empty():
		failures.append("Could not select a placed furniture item.")
	elif not service.move_item(placed_item, Vector2i(2, 2), 0):
		failures.append("Failed to move placed furniture.")
	if int(save_system.call("get_coin_balance")) != 67:
		failures.append("Moving furniture changed the local wallet.")
	var moved_item: Dictionary = service.get_item_at_tile(Vector2i(2, 2))
	if moved_item.is_empty():
		failures.append("Moved furniture was not found at the target tile.")
	elif not service.rotate_item(moved_item):
		failures.append("Failed to rotate placed furniture.")
	var rotated_item: Dictionary = service.get_item_at_tile(Vector2i(2, 2))
	if int(rotated_item.get("rotation", 0)) != 90:
		failures.append("Rotated furniture did not store 90 degree rotation.")
	var edit_controller = HousingRoomEditControllerScript.new()
	root.add_child(edit_controller)
	edit_controller.bind(service)
	var status_texts: Array[String] = []
	edit_controller.status_text_requested.connect(func(text: String) -> void:
		status_texts.append(text)
	)
	var status_keys: Array[String] = []
	edit_controller.status_key_requested.connect(func(key: String) -> void:
		status_keys.append(key)
	)
	save_system.call("sync_coin_balance", 0, "test.empty_wallet")
	edit_controller.handle_catalog_item("tiny_table")
	if not edit_controller.selected_item_id.is_empty():
		failures.append("Unaffordable catalog item stayed selected.")
	if status_keys.is_empty() or status_keys.back() != "housing.error.not_enough_coins":
		failures.append("Unaffordable catalog item did not report the coin error.")

	online_client.set("access_token", "test-token")
	save_system.call("sync_coin_balance", 25, "test.online_low_wallet")
	save_system.call("set_profile_value", "online_inventory_items", [])
	status_keys.clear()
	edit_controller.handle_catalog_item("potted_plant")
	if not edit_controller.selected_item_id.is_empty():
		failures.append("Online unaffordable catalog item stayed selected without inventory.")
	if status_keys.is_empty() or status_keys.back() != "housing.error.not_enough_coins":
		failures.append("Online unaffordable catalog item did not report the coin error.")
	if service.place_item("potted_plant", Vector2i(4, 4)):
		failures.append("Online service allowed unaffordable placement without inventory.")
	save_system.call("set_profile_value", "online_inventory_items", [{
		"item_id": "potted_plant",
		"owned": 1,
		"available": 1,
		"locked": 0
	}])
	edit_controller.handle_catalog_item("potted_plant")
	if edit_controller.selected_item_id != "potted_plant":
		failures.append("Online catalog item backed by inventory was not selected.")
	elif not edit_controller.handle_tile(Vector2i(4, 4)):
		failures.append("Online edit controller rejected a placement backed by available inventory.")
	if not edit_controller.selected_item_id.is_empty():
		failures.append("Edit controller kept furniture selected after successful placement.")
	online_client.set("access_token", "")
	save_system.call("set_profile_value", "online_inventory_items", [])
	save_system.call("sync_coin_balance", 67, "test.restore_wallet")
	edit_controller.select_placed_item(rotated_item)
	if status_texts.is_empty() or not status_texts.back().contains("Undo covers"):
		failures.append("Edit controller did not explain move affordance and one-step undo.")
	if not edit_controller.move_selected_to(Vector2i(3, 3)):
		failures.append("Edit controller failed to move selected furniture.")
	if not edit_controller.can_undo():
		failures.append("Edit controller did not enable undo after a move.")
	if not edit_controller.undo_last_transform():
		failures.append("Edit controller failed to undo the last move.")
	var undo_item: Dictionary = service.get_item_at_tile(Vector2i(2, 2))
	if undo_item.is_empty() or int(undo_item.get("rotation", 0)) != 90:
		failures.append("Undo did not restore the moved furniture.")
	edit_controller.free()
	if int(service.sell_refund_amount("simple_chair")) != 12:
		failures.append("Configured simple_chair sell refund was not 12 coins.")
	if not service.remove_item(rotated_item):
		failures.append("Failed to sell placed furniture.")
	if int(save_system.call("get_coin_balance")) != 79:
		failures.append("Selling simple_chair did not refund the configured amount.")

	var visit_service: Node = HousingServiceScript.new()
	root.add_child(visit_service)
	visit_service.initialize("friend-player", true)
	if visit_service.place_item("simple_chair", Vector2i(2, 2)):
		failures.append("Visitor mode allowed furniture placement.")
	if int(save_system.call("get_coin_balance")) != 79:
		failures.append("Visitor mode changed the local wallet.")
	visit_service.free()

	var room_scene: PackedScene = load(HOUSING_SCENE)
	save_system.call("set_profile_value", "active_home_owner_id", "offline-player")
	save_system.call("set_profile_value", "active_home_visit_mode", false)
	var edit_room: Node = room_scene.instantiate()
	root.add_child(edit_room)
	await process_frame
	if not _catalog_has_image2_icon(edit_room):
		failures.append("Housing catalog buttons did not load Image 2 item icons.")
	if not _uses_script(edit_room.find_child("BottomPanel", true, false), "HousingRoomCatalogBar.gd"):
		failures.append("Housing bottom panel is not using the catalog bar component.")
	if edit_room.find_child("SocialController", true, false) == null:
		failures.append("Housing social services were not split into SocialController.")
	if edit_room.find_child("EditController", true, false) == null:
		failures.append("Housing edit services were not split into EditController.")
	_assert_compact_layout_controls(edit_room.find_child("SocialPanel", true, false), edit_room.find_child("BottomPanel", true, false), failures)
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	edit_room.call("_unhandled_input", cancel_event)
	await process_frame
	await process_frame
	if str(save_system.call("get_profile_value", "current_route", "")) != "main_city":
		failures.append("Housing screen did not route back to main_city on ui_cancel.")
	edit_room.free()

	save_system.call("set_profile_value", "active_home_owner_id", "friend-player")
	save_system.call("set_profile_value", "active_home_visit_mode", true)
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	await process_frame
	if not _has_image2_panel(room.find_child("TopPanel", true, false)):
		failures.append("Housing top panel is not using an Image 2 frame.")
	var social_panel := room.find_child("SocialPanel", true, false)
	if not _has_image2_panel(social_panel):
		failures.append("Housing social panel is not using an Image 2 frame.")
	var bottom_panel := room.find_child("BottomPanel", true, false)
	if not _has_image2_panel(bottom_panel):
		failures.append("Housing bottom panel is not using an Image 2 frame.")
	_assert_compact_layout_controls(social_panel, bottom_panel, failures)
	room.free()
	service.free()

	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	online_client.set("is_connected", original_online_state.get("is_connected", false))
	online_client.set("access_token", original_online_state.get("access_token", ""))
	online_client.set("player_id", original_online_state.get("player_id", "offline-player"))

	if failures.is_empty():
		print("housing smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _has_image2_panel(node: Node) -> bool:
	if not node is PanelContainer:
		return false
	var style := (node as PanelContainer).get_theme_stylebox("panel")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func _catalog_has_image2_icon(root_node: Node) -> bool:
	var row := root_node.find_child("CatalogRow", true, false)
	if row == null:
		return false
	for child in row.get_children():
		if child is Button and (child as Button).icon != null:
			return true
	return false

func _uses_script(node: Node, script_name: String) -> bool:
	if node == null:
		return false
	var script: Resource = node.get_script()
	return script != null and script.resource_path.ends_with(script_name)

func _assert_compact_layout_controls(social_panel: Node, bottom_panel: Node, failures: Array[String]) -> void:
	if social_panel != null and social_panel.has_method("set_compact_layout"):
		social_panel.call("set_compact_layout", true)
		var chat_preview := social_panel.find_child("ChatPreviewLabel", true, false)
		if chat_preview == null or bool(chat_preview.get("visible")):
			failures.append("Housing compact social panel did not hide chat preview.")
	if bottom_panel != null and bottom_panel.has_method("set_compact_layout"):
		bottom_panel.call("set_compact_layout", true)
		var catalog_scroll := bottom_panel.find_child("CatalogScroll", true, false)
		if catalog_scroll == null or (catalog_scroll as Control).custom_minimum_size.y > 40.0:
			failures.append("Housing compact catalog did not reduce scroll height.")
		elif int(catalog_scroll.get("scroll_horizontal")) != 0:
			failures.append("Housing compact catalog did not keep the first item aligned.")
		elif int(catalog_scroll.get("horizontal_scroll_mode")) != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
			failures.append("Housing compact catalog did not hide the horizontal scrollbar.")
		var catalog_row := bottom_panel.find_child("CatalogRow", true, false)
		if catalog_row != null:
			for child in catalog_row.get_children():
				if child is Button and (child as Button).custom_minimum_size.y > 32.0:
					failures.append("Housing compact catalog buttons stayed too tall.")
					break
				if child is Button and (child as Button).custom_minimum_size.x < 96.0:
					failures.append("Housing compact catalog buttons are too narrow for readable item labels.")
					break
				if child is Button and (child as Button).text.length() > 10:
					failures.append("Housing compact catalog buttons kept long full item names.")
					break
				if child is Button and (child as Button).text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
					failures.append("Housing compact catalog buttons did not trim long labels.")
					break
				if child is Button and (child as Button).get_theme_font_size("font_size") > 10:
					failures.append("Housing compact catalog buttons kept a large font.")
					break
