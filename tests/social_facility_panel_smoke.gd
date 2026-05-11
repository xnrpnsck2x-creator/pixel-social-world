extends SceneTree

const SocialFacilityServiceScript := preload("res://scripts/Systems/Social/SocialFacilityService.gd")
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var service := SocialFacilityServiceScript.new()
	root.add_child(service)
	service.initialize()
	root.get_node("OnlineClient").set("player_id", "panel-trader")
	var save_system := root.get_node("SaveSystem")
	var original_balance := int(save_system.call("get_coin_balance"))
	save_system.call("sync_coin_balance", 25, "social_facility_panel_smoke")
	service.trade_listings = [{
		"id": "own_listing",
		"price": 8,
		"status": "active",
		"seller_id": "panel-trader",
		"title_key": "facility.trade.listing.arcade_cabinet.title",
		"body_key": "facility.trade.listing.arcade_cabinet.body",
		"icon_id": "icon.gift"
	}, {
		"id": "peer_listing",
		"price": 7,
		"status": "active",
		"seller_id": "peer-trader",
		"title_key": "facility.trade.listing.simple_chair.title",
		"body_key": "facility.trade.listing.simple_chair.body",
		"icon_id": "icon.home"
	}, {
		"id": "expensive_listing",
		"price": 80,
		"status": "active",
		"seller_id": "peer-trader",
		"title_key": "facility.trade.listing.potted_plant.title",
		"body_key": "facility.trade.listing.potted_plant.body",
		"icon_id": "icon.home"
	}]
	service.trade_inventory = [{"item_id": "potted_plant", "available": 1, "locked": 0}]
	var panel_scene: PackedScene = load("res://scenes/ui/SocialFacilityPanel.tscn")
	var panel := panel_scene.instantiate()
	root.add_child(panel)
	panel.call("bind_service", service)
	panel.call("set_compact_layout", true)
	panel.call("show_facility", "trade")
	await process_frame
	if not _panel_uses_main_frame(panel):
		failures.append("Trade panel did not use the formal main Image 2 panel frame.")
	for text in ["Wallet", "Post", "Cancel", "Buy", "Short", "Potted Plant"]:
		if not _node_tree_contains(panel, text):
			failures.append("Trade panel missing control/text: %s" % text)
	var filter_picker := panel.find_child("TradeFilterPicker", true, false) as OptionButton
	if filter_picker == null or filter_picker.item_count < 4:
		failures.append("Trade panel did not render the compact filter picker.")
	else:
		if filter_picker.custom_minimum_size.x > 86.0:
			failures.append("Compact trade filter picker still consumes too much horizontal space.")
		if not filter_picker.get_item_text(0).contains("3") or not _picker_text_contains(filter_picker, "buy", "1"):
			failures.append("Trade filter picker did not expose live action counts.")
		_select_filter(filter_picker, "mine")
		await process_frame
		if _find_button(panel, "Cancel") == null or _find_button(panel, "Buy") != null or _find_button(panel, "Post") != null:
			failures.append("Trade mine filter did not isolate own listings.")
		_select_filter(filter_picker, "sell")
		await process_frame
		if _find_button(panel, "Post") == null or _find_button(panel, "Cancel") != null or _find_button(panel, "Buy") != null:
			failures.append("Trade sell filter did not isolate sellable inventory.")
		_select_filter(filter_picker, "buy")
		await process_frame
		if _find_button(panel, "Buy") == null or _find_button(panel, "Short") != null:
			failures.append("Trade buy filter did not isolate affordable listings.")
		_select_filter(filter_picker, "all")
		await process_frame
	var short_button := _find_button(panel, "Short")
	if short_button == null or not short_button.disabled:
		failures.append("Trade panel did not render unaffordable listings as disabled.")
	var price_input := panel.find_child("PriceInput", true, false) as LineEdit
	if price_input == null or price_input.text != "7":
		failures.append("Trade panel did not render a default price input.")
	elif not price_input.get_parent().get_parent() is HBoxContainer:
		failures.append("Compact trade actions should stay inline with the row summary.")
	elif price_input.custom_minimum_size.x > 38.0 or (price_input.get_parent() as HBoxContainer).get_theme_constant("separation") > 1:
		failures.append("Compact trade price/action row is still too wide for mobile landscape.")
	var post_button := _find_button(panel, "Post")
	if post_button == null or post_button.custom_minimum_size.x > 42.0:
		failures.append("Compact trade post button did not tighten for the small right panel.")
	service.trade_listings = []
	service.trade_inventory = []
	panel.call("show_facility", "trade")
	await process_frame
	filter_picker = panel.find_child("TradeFilterPicker", true, false) as OptionButton
	if filter_picker != null:
		_select_filter(filter_picker, "buy")
		await process_frame
		if not _node_tree_contains(panel, "No matches") or not _node_tree_contains(panel, "No affordable"):
			failures.append("Trade buy filter did not render a useful empty state.")
	panel.queue_free()
	service.queue_free()
	save_system.call("sync_coin_balance", original_balance, "social_facility_panel_smoke.restore")
	await process_frame
	if failures.is_empty():
		print("social facility panel smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_tree_contains(child, text):
			return true
	return false

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _select_filter(picker: OptionButton, filter_id: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == filter_id:
			picker.select(index)
			picker.item_selected.emit(index)
			return

func _picker_text_contains(picker: OptionButton, filter_id: String, text: String) -> bool:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == filter_id:
			return picker.get_item_text(index).contains(text)
	return false

func _panel_uses_main_frame(panel: PanelContainer) -> bool:
	var style := panel.get_theme_stylebox("panel")
	if not style is StyleBoxTexture:
		return false
	var texture := (style as StyleBoxTexture).texture
	return texture != null and texture.resource_path.ends_with("ui_panel_frame_v1_alpha.png")
