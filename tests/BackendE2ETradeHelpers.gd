extends RefCounted

const Helpers := preload("res://tests/BackendE2EHelpers.gd")

static func verify_dual_player_trade(
	root: Node,
	seller_client: Node,
	seller_id: String,
	save_system: Node,
	failures: Array
) -> void:
	var price := 7
	var seller_profile: Dictionary = await seller_client.call("fetch_profile")
	var seller_wallet := _wallet_coin(seller_profile)
	var seller_inventory: Dictionary = await seller_client.call("fetch_inventory")
	if _item_count(_items_from_client(seller_inventory), "trail_token", "available") < 1:
		failures.append("Dual trade seller did not have a tradeable trail token.")
		return

	var created: Dictionary = await seller_client.call("create_trade_listing", "trail_token", price, {
		"title_key": "facility.trade.listing.trail_token.title",
		"body_key": "facility.trade.listing.trail_token.body",
		"icon_id": "icon.map"
	})
	if not Helpers.ok(created):
		failures.append("Dual trade listing create failed: %s" % str(created))
		return
	var listing: Dictionary = _dict(_dict(created.get("data", {})).get("listing", {}))
	var listing_id := str(listing.get("id", ""))
	if listing_id.is_empty() or str(listing.get("escrow_status", "")) != "locked":
		failures.append("Dual trade listing did not enter locked escrow: %s" % str(created))
		return
	var locked_inventory: Dictionary = await seller_client.call("fetch_inventory")
	var locked_items := _items_from_client(locked_inventory)
	if _item_count(locked_items, "trail_token", "locked") != 1:
		failures.append("Dual trade create did not lock seller trail token: %s" % str(locked_inventory))

	var self_buy: Dictionary = await seller_client.call("purchase_trade_listing", listing_id)
	if Helpers.ok(self_buy) or int(self_buy.get("status", 0)) != 403:
		failures.append("Dual trade self-purchase was not rejected: %s" % str(self_buy))

	var buyer := await _guest_session(root, failures)
	if buyer.is_empty():
		return
	var buyer_id := str(buyer.get("player_id", ""))
	var buyer_token := str(buyer.get("access_token", ""))
	var buyer_cancel := await Helpers.raw_json(
		root,
		HTTPClient.METHOD_POST,
		"/trade/listings/%s/cancel" % listing_id.uri_encode(),
		{"seller_id": buyer_id},
		buyer_token
	)
	if int(buyer_cancel.get("status", 0)) != 403:
		failures.append("Dual trade cross-player cancel was not rejected.")
	var listing_active := await _listing_has_status(root, buyer_id, buyer_token, listing_id, "active")
	if not listing_active:
		failures.append("Dual trade listing disappeared before purchase.")

	var purchase := await Helpers.raw_json(
		root,
		HTTPClient.METHOD_POST,
		"/trade/listings/%s/buy" % listing_id.uri_encode(),
		{"buyer_id": buyer_id},
		buyer_token
	)
	if int(purchase.get("status", 0)) != 200:
		failures.append("Dual trade purchase failed: %s" % str(purchase))
		return
	_verify_purchase_body(_dict(purchase.get("body", {})), listing_id, buyer_id, seller_wallet, price, failures)

	var buyer_inventory := await Helpers.raw_json(
		root,
		HTTPClient.METHOD_GET,
		"/inventory?player_id=%s" % buyer_id.uri_encode(),
		{},
		buyer_token
	)
	if _item_count(_items_from_raw(buyer_inventory), "trail_token", "owned") != 1:
		failures.append("Dual trade buyer did not receive trail token: %s" % str(buyer_inventory))

	var seller_after: Dictionary = await seller_client.call("fetch_inventory")
	var seller_items := _items_from_client(seller_after)
	if _item_count(seller_items, "trail_token", "owned") != 0 or _item_count(seller_items, "trail_token", "locked") != 0:
		failures.append("Dual trade seller inventory did not release sold escrow: %s" % str(seller_after))
	var seller_after_profile: Dictionary = await seller_client.call("fetch_profile")
	if _wallet_coin(seller_after_profile) != seller_wallet + price:
		failures.append("Dual trade seller wallet did not receive buyer coins.")
	if int(save_system.call("get_coin_balance")) != seller_wallet + price:
		failures.append("Dual trade did not resync the local seller wallet.")
	var seller_ledger: Dictionary = await seller_client.call("fetch_coin_ledger", seller_id)
	if not Helpers.ledger_has_source_prefix(seller_ledger, "trade.sale."):
		failures.append("Dual trade seller ledger did not record the sale source.")

	var sold_cancel: Dictionary = await seller_client.call("cancel_trade_listing", listing_id)
	if Helpers.ok(sold_cancel) or int(sold_cancel.get("status", 0)) != 409:
		failures.append("Dual trade sold listing cancel did not return 409.")
	var replay_buy := await Helpers.raw_json(
		root,
		HTTPClient.METHOD_POST,
		"/trade/listings/%s/buy" % listing_id.uri_encode(),
		{"buyer_id": buyer_id},
		buyer_token
	)
	if int(replay_buy.get("status", 0)) != 409:
		failures.append("Dual trade replay purchase did not return 409.")

static func _guest_session(root: Node, failures: Array) -> Dictionary:
	var login := await Helpers.raw_json(root, HTTPClient.METHOD_POST, "/auth/guest", {
		"device_id": "backend-e2e-trade-buyer-%d" % Time.get_ticks_usec(),
		"display_name": "Trade Buyer E2E"
	}, "")
	if int(login.get("status", 0)) != 200:
		failures.append("Dual trade buyer login failed: %s" % str(login))
		return {}
	var body := _dict(login.get("body", {}))
	if str(body.get("player_id", "")).is_empty() or str(body.get("access_token", "")).is_empty():
		failures.append("Dual trade buyer login returned an incomplete session.")
		return {}
	return body

static func _listing_has_status(root: Node, player_id: String, token: String, listing_id: String, status: String) -> bool:
	var response := await Helpers.raw_json(
		root,
		HTTPClient.METHOD_GET,
		"/trade/listings?player_id=%s" % player_id.uri_encode(),
		{},
		token
	)
	for raw in _items_from_raw(response):
		var listing := _dict(raw)
		if str(listing.get("id", "")) == listing_id:
			return str(listing.get("status", "")) == status
	return false

static func _verify_purchase_body(
	body: Dictionary,
	listing_id: String,
	buyer_id: String,
	seller_start_wallet: int,
	price: int,
	failures: Array
) -> void:
	var listing := _dict(body.get("listing", {}))
	if str(listing.get("id", "")) != listing_id or str(listing.get("buyer_id", "")) != buyer_id:
		failures.append("Dual trade purchase did not mark the expected buyer.")
	if str(listing.get("status", "")) != "sold" or str(listing.get("escrow_status", "")) != "delivered":
		failures.append("Dual trade purchase did not deliver escrow: %s" % str(body))
	var transfer := _dict(body.get("transfer", {}))
	if int(_dict(transfer.get("from", {})).get("balance", -1)) != 25 - price:
		failures.append("Dual trade buyer wallet did not decrease by price.")
	if int(_dict(transfer.get("to", {})).get("balance", -1)) != seller_start_wallet + price:
		failures.append("Dual trade seller transfer did not increase by price.")
	var item_transfer := _dict(body.get("item_transfer", {}))
	if str(item_transfer.get("item_id", "")) != "trail_token":
		failures.append("Dual trade purchase did not transfer the listed item.")

static func _items_from_client(response: Dictionary) -> Array:
	return _array(_dict(response.get("data", {})).get("items", []))

static func _items_from_raw(response: Dictionary) -> Array:
	return _array(_dict(response.get("body", {})).get("items", []))

static func _item_count(items: Array, item_id: String, field: String) -> int:
	for raw in items:
		var item := _dict(raw)
		if str(item.get("item_id", "")) == item_id:
			return int(item.get(field, 0))
	return 0

static func _wallet_coin(profile_response: Dictionary) -> int:
	return int(_dict(_dict(profile_response.get("data", {})).get("wallet", {})).get("coin", -1))

static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
