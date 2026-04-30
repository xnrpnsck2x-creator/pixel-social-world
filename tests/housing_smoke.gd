extends SceneTree

const HousingServiceScript := preload("res://scripts/Systems/Housing/HousingService.gd")
const HousingRoomEditControllerScript := preload("res://scripts/UI/Panels/HousingRoomEditController.gd")
const HOUSING_SCENE := "res://scenes/housing/HousingRoom.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system: Node = root.get_node("SaveSystem")
	var original_profile: Dictionary = save_system.call("load_profile").duplicate(true)
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

	var service: Node = HousingServiceScript.new()
	root.add_child(service)
	service.initialize()
	if service.get("online_sync") == null:
		failures.append("Housing service online sync boundary was not initialized.")

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
		if catalog_scroll == null or (catalog_scroll as Control).custom_minimum_size.y > 42.0:
			failures.append("Housing compact catalog did not reduce scroll height.")
