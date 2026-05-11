class_name SocialFacilityTradeRows
extends RefCounted

static func build_facility_rows(
	record: Dictionary,
	trade_listings: Array,
	trade_inventory: Array,
	trade_history: Array,
	player_id: String,
	coin_balance: int,
	include_empty_inventory: bool
) -> Dictionary:
	var rows: Array = [_wallet_row(coin_balance)]
	var has_live_rows := false
	var affordable_rows: Array = []
	var own_listing_rows: Array = []
	var sellable_rows: Array = []
	var locked_rows: Array = []
	var unaffordable_rows: Array = []
	for listing in trade_listings:
		if typeof(listing) != TYPE_DICTIONARY or str((listing as Dictionary).get("status", "")) != "active":
			continue
		var listing_row := _listing_row(listing as Dictionary, player_id, coin_balance)
		var action: Dictionary = listing_row.get("action", {}) as Dictionary
		if str(action.get("type", "")) == "cancel_trade_listing":
			own_listing_rows.append(listing_row)
		elif bool(listing_row.get("disabled", false)):
			unaffordable_rows.append(listing_row)
		else:
			affordable_rows.append(listing_row)
		has_live_rows = true
	for item in trade_inventory:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_row := _inventory_row(item as Dictionary)
		if bool(item_row.get("price_input", false)):
			sellable_rows.append(item_row)
		else:
			locked_rows.append(item_row)
		has_live_rows = true
	rows.append_array(affordable_rows)
	rows.append_array(own_listing_rows)
	rows.append_array(sellable_rows)
	rows.append_array(locked_rows)
	rows.append_array(unaffordable_rows)
	rows.append_array(_history_rows(trade_history))
	if include_empty_inventory and trade_inventory.is_empty():
		rows.append(_empty_inventory_row())
		has_live_rows = true
	for row in record.get("rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			rows.append((row as Dictionary).duplicate(true))
	return {"rows": rows, "has_live_rows": has_live_rows}

static func _listing_row(listing: Dictionary, player_id: String, coin_balance: int) -> Dictionary:
	var price := int(listing.get("price", 0))
	var row := {
		"id": "listing.%s" % str(listing.get("id", "")),
		"title_key": str(listing.get("title_key", "facility.trade.listing.title")),
		"body_key": str(listing.get("body_key", "facility.trade.listing.body")),
		"state_key": "facility.trade.price_format",
		"state_values": {"coins": price},
		"icon_id": str(listing.get("icon_id", "icon.gift")),
	}
	if str(listing.get("seller_id", "")) == player_id:
		row["action_key"] = "facility.trade.action.cancel_listing"
		row["action"] = {"type": "cancel_trade_listing", "listing_id": str(listing.get("id", ""))}
	elif price > coin_balance:
		row["state_key"] = "facility.trade.price_missing_format"
		row["state_values"] = {"price": price, "missing": price - coin_balance}
		row["action_key"] = "facility.trade.action.need_coins"
		row["action"] = {"type": "buy_trade_listing", "listing_id": str(listing.get("id", ""))}
		row["disabled"] = true
	else:
		row["action_key"] = "facility.trade.action.buy"
		row["action"] = {"type": "buy_trade_listing", "listing_id": str(listing.get("id", ""))}
	return row

static func _history_rows(trade_history: Array) -> Array:
	var rows: Array = []
	for raw_event in trade_history:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		rows.append(_history_row(raw_event as Dictionary))
		if rows.size() >= 3:
			break
	return rows

static func _history_row(event: Dictionary) -> Dictionary:
	var event_type := str(event.get("type", "created"))
	var event_id := str(event.get("id", str(event.get("listing_id", ""))))
	return {
		"id": "trade.history.%s" % event_id,
		"title_key": str(event.get("title_key", "facility.trade.listing.title")),
		"body_key": "facility.trade.history.%s.body" % _history_key_id(event_type),
		"body_values": {"coins": int(event.get("price", 0))},
		"state_key": "facility.trade.history.%s.state" % _history_key_id(event_type),
		"icon_id": str(event.get("icon_id", "icon.coin"))
	}

static func _history_key_id(event_type: String) -> String:
	match event_type:
		"sold":
			return "sold"
		"cancelled":
			return "cancelled"
		_:
			return "created"

static func _inventory_row(item: Dictionary) -> Dictionary:
	var metadata := _listing_metadata_for_item(str(item.get("item_id", "")))
	var row := {
		"id": "inventory.%s" % str(item.get("item_id", "")),
		"title_key": str(metadata.get("title_key", "facility.trade.inventory.title")),
		"body_key": "facility.trade.inventory.body",
		"state_key": "facility.trade.inventory_state_format",
		"state_values": {
			"available": int(item.get("available", 0)),
			"locked": int(item.get("locked", 0))
		},
		"icon_id": "icon.backpack"
	}
	if int(item.get("available", 0)) > 0:
		row["price_input"] = true
		row["price_default"] = 7
		row["action_key"] = "facility.trade.action.create_listing"
		row["action"] = {
			"type": "create_trade_listing",
			"item_id": str(item.get("item_id", "")),
			"metadata": metadata
		}
	else:
		row["body_key"] = "facility.trade.inventory.locked.body"
	return row

static func _wallet_row(coin_balance: int) -> Dictionary:
	return {
		"id": "trade.wallet",
		"title_key": "facility.trade.wallet.title",
		"body_key": "facility.trade.wallet.body",
		"state_key": "facility.trade.wallet_balance_format",
		"state_values": {"coins": coin_balance},
		"icon_id": "icon.coin"
	}

static func _empty_inventory_row() -> Dictionary:
	return {
		"id": "trade.inventory.empty",
		"title_key": "facility.trade.inventory.empty.title",
		"body_key": "facility.trade.inventory.empty.body",
		"state_key": "facility.trade.inventory.empty.state",
		"icon_id": "icon.backpack"
	}

static func _listing_metadata_for_item(item_id: String) -> Dictionary:
	var key_id := "simple_chair" if item_id.is_empty() else item_id
	var title_key := "facility.trade.listing.title"
	var body_key := "facility.trade.listing.body"
	match key_id:
		"simple_chair":
			title_key = "facility.trade.listing.simple_chair.title"
			body_key = "facility.trade.listing.simple_chair.body"
		"arcade_cabinet":
			title_key = "facility.trade.listing.arcade_cabinet.title"
			body_key = "facility.trade.listing.arcade_cabinet.body"
		"potted_plant":
			title_key = "facility.trade.listing.potted_plant.title"
			body_key = "facility.trade.listing.potted_plant.body"
	return {"title_key": title_key, "body_key": body_key, "icon_id": "icon.home"}
