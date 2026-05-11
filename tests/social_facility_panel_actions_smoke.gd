extends SceneTree
class FakeFacilityService:
	extends Node
	signal facilities_updated(facilities: Dictionary)
	var calls: Array = []
	var mode := "initial"
	var buy_error := ""
	var buy_delay_frames := 0
	var refresh_count := 0
	func get_facility(_facility_id: String) -> Dictionary:
		var rows: Array = [_wallet_row()]
		if mode == "created":
			rows.append(_own_listing_row())
		else:
			rows.append(_inventory_row())
			rows.append(_peer_listing_row())
		return {
			"title_key": "facility.trade.title",
			"body_key": "facility.trade.body",
			"detail_key": "facility.trade.detail.live",
			"icon_id": "icon.coin",
			"rows": rows
		}

	func create_trade_listing(item_id: String, price: int, _metadata: Dictionary) -> Dictionary:
		calls.append({"type": "create", "item_id": item_id, "price": price})
		mode = "created"
		return {
			"ok": true,
			"message_key": "facility.trade.create.success",
			"data": {"listing": {"id": "own_listing", "item_id": item_id, "price": price}}
		}

	func cancel_trade_listing(listing_id: String) -> Dictionary:
		calls.append({"type": "cancel", "listing_id": listing_id})
		mode = "initial"
		return {
			"ok": true,
			"message_key": "facility.trade.cancel.success",
			"data": {"listing": {"id": listing_id, "item_id": "arcade_cabinet"}}
		}

	func buy_trade_listing(listing_id: String) -> Dictionary:
		calls.append({"type": "buy", "listing_id": listing_id})
		for _index in range(buy_delay_frames):
			await get_tree().process_frame
		if not buy_error.is_empty():
			return {"ok": false, "error": buy_error}
		return {
			"ok": true,
			"message_key": "facility.trade.purchase.success",
			"data": {
				"listing": {"id": listing_id, "item_id": "simple_chair", "price": 7},
				"transfer": {"from": {"delta": -7, "balance": 18}},
				"item_transfer": {"item_id": "simple_chair", "quantity": 1}
			}
		}

	func refresh() -> void:
		refresh_count += 1
		await get_tree().process_frame

	func _wallet_row() -> Dictionary:
		return {
			"title_key": "facility.trade.wallet.title",
			"body_key": "facility.trade.wallet.body",
			"state_key": "facility.trade.wallet_balance_format",
			"state_values": {"coins": 25},
			"icon_id": "icon.coin"
		}

	func _inventory_row() -> Dictionary:
		return {
			"title_key": "facility.trade.listing.arcade_cabinet.title",
			"body_key": "facility.trade.inventory.body",
			"state_key": "facility.trade.inventory_state_format",
			"state_values": {"available": 1, "locked": 0},
			"price_input": true,
			"price_default": 7,
			"action_key": "facility.trade.action.create_listing",
			"action": {"type": "create_trade_listing", "item_id": "arcade_cabinet", "metadata": {}},
			"icon_id": "icon.backpack"
		}

	func _own_listing_row() -> Dictionary:
		return {
			"title_key": "facility.trade.listing.arcade_cabinet.title",
			"body_key": "facility.trade.listing.arcade_cabinet.body",
			"state_key": "facility.trade.price_format",
			"state_values": {"coins": 12},
			"action_key": "facility.trade.action.cancel_listing",
			"action": {"type": "cancel_trade_listing", "listing_id": "own_listing"},
			"icon_id": "icon.gift"
		}

	func _peer_listing_row() -> Dictionary:
		return {
			"title_key": "facility.trade.listing.simple_chair.title",
			"body_key": "facility.trade.listing.simple_chair.body",
			"state_key": "facility.trade.price_format",
			"state_values": {"coins": 7},
			"action_key": "facility.trade.action.buy",
			"action": {"type": "buy_trade_listing", "listing_id": "peer_listing"},
			"icon_id": "icon.home"
		}

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var failures: Array[String] = []
	var service := FakeFacilityService.new()
	root.add_child(service)
	var panel_scene: PackedScene = load("res://scenes/ui/SocialFacilityPanel.tscn")
	var panel := panel_scene.instantiate()
	root.add_child(panel)
	panel.call("bind_service", service)
	panel.call("set_compact_layout", true)
	panel.call("show_facility", "trade")
	await process_frame
	await process_frame
	var sync_label := panel.find_child("TradeSyncState", true, false) as Label
	if sync_label == null or sync_label.custom_minimum_size.x < 46.0:
		failures.append("Compact trade sync label is too narrow for small-font Fresh/Check state text.")
	var price_input := panel.find_child("PriceInput", true, false) as LineEdit
	if price_input == null:
		failures.append("Trade panel did not render a price input.")
	else:
		if price_input.virtual_keyboard_type != LineEdit.KEYBOARD_TYPE_NUMBER or not price_input.select_all_on_focus:
			failures.append("Trade price input is not optimized for mobile numeric entry.")
		if service.refresh_count != 1 or not _node_tree_contains(panel, "Fresh"):
			failures.append("Trade panel did not auto-sync when opened.")
		await _press_button(panel, "Sync")
		if service.refresh_count != 2 or not _detail_text(panel).contains("Board refreshed"):
			failures.append("Trade panel refresh did not call the service and show fresh-board feedback.")
		if not _node_tree_contains(panel, "Fresh"):
			failures.append("Trade panel did not show the fresh-board sync state after refresh.")
		price_input = panel.find_child("PriceInput", true, false) as LineEdit
		if price_input == null:
			failures.append("Trade panel refresh did not restore the price input.")
			price_input = LineEdit.new()
		price_input.text = "10000"
		await _press_button(panel, "Post")
		if not service.calls.is_empty() or not _detail_text(panel).contains("9999"):
			failures.append("Trade panel accepted an out-of-range price.")
	price_input = panel.find_child("PriceInput", true, false) as LineEdit
	if price_input != null:
		price_input.text = "12"
		price_input.emit_signal("text_submitted", "12")
		await process_frame
		await process_frame
	if service.calls.size() != 1 or int((service.calls[0] as Dictionary).get("price", 0)) != 12:
		failures.append("Trade panel did not post the requested inventory item from text submit.")
	if not _detail_text(panel).contains("Listing posted"):
		failures.append("Trade panel did not show post success feedback.")
	if not _node_tree_contains(panel, "Listing live"):
		failures.append("Trade panel did not add a visible listing outcome row.")
	if not _node_tree_contains(panel, "Listed at 12 coins"):
		failures.append("Trade panel did not show posted listing price in the outcome row.")
	if _selected_trade_filter(panel) != "mine":
		failures.append("Trade panel did not focus the Mine filter after posting a listing.")
	if not _text_appears_before(panel, "Cancel", "Listing live"):
		failures.append("Trade panel did not keep the cancel action above listing outcome history.")
	await _press_button(panel, "Cancel")
	if service.calls.size() != 2 or str((service.calls[1] as Dictionary).get("type", "")) != "cancel":
		failures.append("Trade panel did not call cancel for an own listing.")
	if not _node_tree_contains(panel, "Listing closed"):
		failures.append("Trade panel did not add a visible cancel outcome row.")
	if not _node_tree_contains(panel, "Returned arcade_cabinet"):
		failures.append("Trade panel did not show returned escrow item in the cancel outcome row.")
	if _selected_trade_filter(panel) != "sell":
		failures.append("Trade panel did not focus the Sell filter after cancelling a listing.")
	if not _text_appears_before(panel, "Post", "Listing closed"):
		failures.append("Trade panel did not keep the post action above cancel outcome history.")
	_select_trade_filter(panel, "buy")
	await process_frame
	service.buy_delay_frames = 2
	var buy_button := _find_button(panel, "Buy")
	if buy_button != null:
		buy_button.emit_signal("pressed")
		buy_button.emit_signal("pressed")
		await process_frame
		if service.calls.size() != 3 or str((service.calls[2] as Dictionary).get("type", "")) != "buy":
			failures.append("Trade panel allowed duplicate buy actions while the first buy was pending.")
		await process_frame
		await process_frame
		await process_frame
	else:
		failures.append("Trade panel did not expose a buy button for pending-action guard.")
	service.buy_delay_frames = 0
	if service.calls.size() != 3 or str((service.calls[2] as Dictionary).get("type", "")) != "buy":
		failures.append("Trade panel did not call buy for a peer listing.")
	if not _node_tree_contains(panel, "Purchased"):
		failures.append("Trade panel did not add a visible purchase outcome row.")
	if not _node_tree_contains(panel, "Spent 7"):
		failures.append("Trade panel did not show purchase coin delta in the outcome row.")
	for history_text in ["Listed at 12 coins", "Returned arcade_cabinet"]:
		if not _node_tree_contains(panel, history_text):
			failures.append("Trade panel did not keep recent history row: %s" % history_text)
	service.buy_error = "insufficient_funds"
	await _press_button(panel, "Buy")
	if not _detail_text(panel).contains("Not enough coins"):
		failures.append("Trade panel did not show a specific insufficient-funds error.")
	if not _node_tree_contains(panel, "Trade issue"):
		failures.append("Trade panel did not add a visible failed-trade outcome row.")
	if not _node_tree_contains(panel, "Check"):
		failures.append("Trade panel did not show a sync-check state after failed trade.")
	if _node_tree_contains(panel, "Listed at 12 coins"):
		failures.append("Trade panel did not cap recent history to three rows.")
	await _press_button(panel, "Sync")
	if service.refresh_count != 3 or not _detail_text(panel).contains("Board refreshed"):
		failures.append("Trade panel failed outcome sync action did not refresh the board.")
	if _node_tree_contains(panel, "Trade issue"):
		failures.append("Trade panel did not clear failed history rows after sync recovery.")
	service.buy_error = "listing_inactive"
	await _press_button(panel, "Buy")
	if not _detail_text(panel).contains("Someone bought this first"):
		failures.append("Trade panel did not show a race-lost purchase error.")
	service.buy_error = "http_0"
	await _press_button(panel, "Buy")
	if not _detail_text(panel).contains("Trade service is unavailable"):
		failures.append("Trade panel did not show a connection-safe weak-network error.")
	panel.queue_free()
	service.queue_free()
	await process_frame
	if failures.is_empty():
		print("social facility panel actions smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _press_button(root_node: Node, text: String) -> void:
	var button := _find_button(root_node, text)
	if button != null:
		button.emit_signal("pressed")
	await process_frame
	await process_frame

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

func _detail_text(panel: Node) -> String:
	var label := panel.get_node("Margin/Rows/DetailLabel") as Label
	return label.text

func _selected_trade_filter(panel: Node) -> String:
	var picker := panel.find_child("TradeFilterPicker", true, false) as OptionButton
	if picker == null or picker.selected < 0:
		return ""
	return str(picker.get_item_metadata(picker.selected))

func _select_trade_filter(panel: Node, filter_id: String) -> void:
	var picker := panel.find_child("TradeFilterPicker", true, false) as OptionButton
	if picker == null:
		return
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == filter_id:
			picker.select(index)
			picker.emit_signal("item_selected", index)
			return

func _node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_tree_contains(child, text):
			return true
	return false

func _text_appears_before(node: Node, first_text: String, second_text: String) -> bool:
	var texts: Array[String] = []
	_collect_visible_texts(node, texts)
	var first_index := _text_index(texts, first_text)
	var second_index := _text_index(texts, second_text)
	return first_index >= 0 and second_index >= 0 and first_index < second_index

func _collect_visible_texts(node: Node, texts: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	for child in node.get_children():
		_collect_visible_texts(child, texts)

func _text_index(texts: Array[String], needle: String) -> int:
	for index in range(texts.size()):
		if texts[index].contains(needle):
			return index
	return -1
