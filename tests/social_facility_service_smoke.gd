extends SceneTree

const SocialFacilityServiceScript := preload("res://scripts/Systems/Social/SocialFacilityService.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var service := SocialFacilityServiceScript.new()
	root.add_child(service)
	service.initialize()
	await process_frame

	var catalog: Dictionary = service.call("get_catalog")
	if str(catalog.get("source", "")) != "local":
		failures.append("SocialFacilityService did not start from the local catalog.")
	var trade: Dictionary = service.call("get_facility", "trade")
	if str(trade.get("map_id", "")) != "social_trade_market_v1":
		failures.append("Trade facility did not resolve to the trade market map.")
	var rows: Array = trade.get("rows", []) as Array
	if rows.is_empty() or str((rows[0] as Dictionary).get("title_key", "")) != "facility.trade.wallet.title":
		failures.append("Trade facility did not expose the wallet balance row.")
	if _find_row_with_title(rows, "facility.trade.board.title").is_empty():
		failures.append("Trade facility did not expose the configured board row.")
	var save_system := root.get_node("SaveSystem")
	var original_balance := int(save_system.call("get_coin_balance"))
	save_system.call("sync_coin_balance", 25, "social_facility_service_smoke")
	root.get_node("OnlineClient").set("player_id", "service-trader")
	service.trade_listings = [{
		"id": "own_listing",
		"price": 8,
		"status": "active",
		"seller_id": "service-trader",
		"title_key": "facility.trade.listing.arcade_cabinet.title",
		"body_key": "facility.trade.listing.arcade_cabinet.body",
		"icon_id": "icon.gift"
	}, {
		"id": "listing_one",
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
	service.trade_inventory = [{
		"item_id": "simple_chair",
		"available": 1,
		"locked": 1
	}, {
		"item_id": "potted_plant",
		"available": 0,
		"locked": 1
	}]
	service.trade_history = [{
		"id": "event_cancelled",
		"type": "cancelled",
		"listing_id": "old_listing",
		"price": 9,
		"title_key": "facility.trade.listing.simple_chair.title",
		"icon_id": "icon.home"
	}]
	trade = service.call("get_facility", "trade")
	rows = trade.get("rows", []) as Array
	var buy_row := _find_action_row(rows, "buy_trade_listing")
	if buy_row.is_empty() or str(buy_row.get("action_key", "")) != "facility.trade.action.buy":
		failures.append("Live trade listing row did not expose the buy action.")
	elif int((buy_row.get("state_values", {}) as Dictionary).get("coins", 0)) != 7:
		failures.append("Live trade listing row did not expose its server price.")
	if _find_action_row(rows, "cancel_trade_listing").is_empty():
		failures.append("Own live trade listing did not expose the cancel action.")
	var short_row := _find_row_by_id(rows, "listing.expensive_listing")
	if short_row.is_empty() or not bool(short_row.get("disabled", false)):
		failures.append("Unaffordable live listing did not disable its buy action.")
	elif str(short_row.get("state_key", "")) != "facility.trade.price_missing_format":
		failures.append("Unaffordable live listing did not show the missing-coins state.")
	elif int((short_row.get("state_values", {}) as Dictionary).get("missing", 0)) != 55:
		failures.append("Unaffordable live listing did not compute the missing coin amount.")
	var create_row := _find_action_row(rows, "create_trade_listing")
	if create_row.is_empty() or not bool(create_row.get("price_input", false)):
		failures.append("Trade inventory did not expose price input posting.")
	if create_row.is_empty() or str(create_row.get("state_key", "")) != "facility.trade.inventory_state_format":
		failures.append("Trade facility did not expose inventory escrow state.")
	var locked_row := _find_row_by_id(rows, "inventory.potted_plant")
	if locked_row.is_empty() or str(locked_row.get("body_key", "")) != "facility.trade.inventory.locked.body":
		failures.append("Locked trade inventory did not use the locked-stock body copy.")
	var ordered_ids := [
		"trade.wallet",
		"listing.listing_one",
		"listing.own_listing",
		"inventory.simple_chair",
		"inventory.potted_plant",
		"listing.expensive_listing"
	]
	if not _rows_start_with_ids(rows, ordered_ids):
		failures.append("Trade rows were not ordered for wallet, buy, own listing, sell, locked, short.")
	var history_row := _find_row_by_id(rows, "trade.history.event_cancelled")
	if history_row.is_empty() or str(history_row.get("state_key", "")) != "facility.trade.history.cancelled.state":
		failures.append("Trade facility did not expose the server history row.")
	var missing: Dictionary = service.call("get_facility", "missing")
	if not missing.is_empty():
		failures.append("Unknown facility should return an empty record.")

	save_system.call("sync_coin_balance", original_balance, "social_facility_service_smoke.restore")
	service.queue_free()
	await process_frame
	if failures.is_empty():
		print("social facility service smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _find_row_with_title(rows: Array, title_key: String) -> Dictionary:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("title_key", "")) == title_key:
			return row as Dictionary
	return {}

func _find_action_row(rows: Array, action_type: String) -> Dictionary:
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = (row as Dictionary).get("action", {}) as Dictionary
		if str(action.get("type", "")) == action_type:
			return row as Dictionary
	return {}

func _find_row_by_id(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == id:
			return row as Dictionary
	return {}

func _rows_start_with_ids(rows: Array, expected_ids: Array) -> bool:
	if rows.size() < expected_ids.size():
		return false
	for index in range(expected_ids.size()):
		if str((rows[index] as Dictionary).get("id", "")) != str(expected_ids[index]):
			return false
	return true
