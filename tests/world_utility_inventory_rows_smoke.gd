extends SceneTree

const InventoryRowsScript := preload("res://scripts/UI/Panels/WorldUtilityInventoryRows.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "inventory-rows-smoke",
		"device_id": "test-device",
		"display_name": "Inventory Rows",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"inventory": [],
		"owned_items": ["starter_wallpaper"],
		"house_items": [],
		"map_activity_inventory": {"trail_token": {"item_id": "trail_token", "quantity": 2, "rarity": "common"}},
		"map_activity_skill_xp": {"exploration": 4}
	})
	save_system.call("_apply_defaults")

	var online_rows := VBoxContainer.new()
	root.add_child(online_rows)
	InventoryRowsScript.new().render(online_rows, false, [
		{"item_id": "trail_token", "owned": 2, "available": 1, "locked": 1},
		{"item_id": "simple_chair", "owned": 1, "available": 1, "locked": 0}
	], true)
	if not _contains(online_rows, "Server Inventory") or not _contains(online_rows, "Trail Token"):
		failures.append("Online inventory rows did not render server-backed items.")
	if not _contains(online_rows, "Owned 2 / Avail 1 / Lock 1"):
		failures.append("Online inventory rows did not render escrow state.")
	if not _contains(online_rows, "Starter Wallpaper"):
		failures.append("Online inventory rows dropped local room goods.")
	if not _contains(online_rows, "Exploration"):
		failures.append("Online inventory rows dropped activity skill progress.")
	if _count_labels(online_rows, "Trail Token") != 1:
		failures.append("Online inventory rows duplicated map drops already present in server inventory.")
	online_rows.queue_free()

	var offline_rows := VBoxContainer.new()
	root.add_child(offline_rows)
	InventoryRowsScript.new().render(offline_rows, false, [], false)
	if not _contains(offline_rows, "Activity Finds") or not _contains(offline_rows, "Trail Token x2"):
		failures.append("Offline inventory rows did not keep local activity drops.")
	offline_rows.queue_free()

	save_system.set("profile", original_profile)
	await process_frame
	if failures.is_empty():
		print("world utility inventory rows smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _contains(child, text):
			return true
	return false

func _count_labels(node: Node, text: String) -> int:
	var total := 0
	if node is Label and (node as Label).text.contains(text):
		total += 1
	for child in node.get_children():
		total += _count_labels(child, text)
	return total
