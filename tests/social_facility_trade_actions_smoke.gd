extends SceneTree

class FakeOnlineClient:
	extends Node
	var is_connected := true
	var player_id := "trade-buyer"
	var created: Dictionary = {}
	var cancelled_id := ""
	var generic_inventory_fetches := 0
	var trade_inventory_fetches := 0
	var listings := [{
		"id": "peer_listing",
		"price": 7,
		"status": "active",
		"seller_id": "trade-seller",
		"title_key": "facility.trade.listing.simple_chair.title",
		"body_key": "facility.trade.listing.simple_chair.body",
		"icon_id": "icon.home"
	}]
	var inventory := [{"item_id": "arcade_cabinet", "available": 1, "locked": 0}]

	func fetch_trade_listings() -> Dictionary:
		return {"ok": true, "data": {"items": listings, "server_time": 1}}

	func fetch_trade_inventory() -> Dictionary:
		trade_inventory_fetches += 1
		return {"ok": true, "data": {"items": inventory, "server_time": 1}}

	func fetch_inventory() -> Dictionary:
		generic_inventory_fetches += 1
		return {"ok": true, "data": {"items": inventory, "server_time": 1}}

	func purchase_trade_listing(listing_id: String) -> Dictionary:
		_set_listing_status(listing_id, "sold")
		return {
			"ok": true,
			"data": {
				"listing": {"id": listing_id, "status": "sold"},
				"transfer": {"from": {"balance": 18}}
			}
		}

	func create_trade_listing(item_id: String, price: int, metadata: Dictionary) -> Dictionary:
		created = {"item_id": item_id, "price": price, "metadata": metadata}
		listings.append({
			"id": "own_listing",
			"price": price,
			"status": "active",
			"seller_id": player_id,
			"item_id": item_id,
			"title_key": str(metadata.get("title_key", "facility.trade.listing.title")),
			"body_key": str(metadata.get("body_key", "facility.trade.listing.body")),
			"icon_id": "icon.gift"
		})
		inventory = [{"item_id": item_id, "available": 0, "locked": 1}]
		return {"ok": true, "data": {"listing": {"id": "own_listing", "status": "active"}}}

	func cancel_trade_listing(listing_id: String) -> Dictionary:
		cancelled_id = listing_id
		_set_listing_status(listing_id, "cancelled")
		inventory = [{"item_id": "arcade_cabinet", "available": 1, "locked": 0}]
		return {"ok": true, "data": {"listing": {"id": listing_id, "status": "cancelled"}}}

	func _set_listing_status(listing_id: String, status: String) -> void:
		for index in range(listings.size()):
			var listing := listings[index] as Dictionary
			if str(listing.get("id", "")) == listing_id:
				listing["status"] = status
				listings[index] = listing
				return

class TestSocialFacilityService:
	extends SocialFacilityService
	var fake_client: Node

	func _online_client() -> Node:
		return fake_client

	func _online_client_connected() -> bool:
		return true

	func _trade_backend_enabled() -> bool:
		return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var fake_client := FakeOnlineClient.new()
	var service := TestSocialFacilityService.new()
	service.fake_client = fake_client
	root.add_child(service)
	var save_system := root.get_node("SaveSystem")
	var original_balance := int(save_system.call("get_coin_balance"))
	save_system.call("sync_coin_balance", 25, "trade.action_smoke")

	var purchase: Dictionary = await service.call("buy_trade_listing", "peer_listing")
	if not bool(purchase.get("ok", false)) or int(save_system.call("get_coin_balance")) != 18:
		failures.append("Trade purchase did not sync wallet balance from server response.")
	if fake_client.trade_inventory_fetches != 1 or fake_client.generic_inventory_fetches != 0:
		failures.append("Trade refresh did not prefer the trade inventory endpoint.")

	var metadata := {"title_key": "facility.trade.listing.arcade_cabinet.title"}
	var created: Dictionary = await service.call("create_trade_listing", "arcade_cabinet", 12, metadata)
	if not bool(created.get("ok", false)) or int(fake_client.created.get("price", 0)) != 12:
		failures.append("Trade create did not forward item, price, and metadata to OnlineClient.")
	var listed_item := service.trade_inventory[0] as Dictionary
	if int(listed_item.get("available", -1)) != 0 or int(listed_item.get("locked", -1)) != 1:
		failures.append("Trade create did not refresh inventory escrow state.")

	var cancelled: Dictionary = await service.call("cancel_trade_listing", "own_listing")
	if not bool(cancelled.get("ok", false)) or fake_client.cancelled_id != "own_listing":
		failures.append("Trade cancel did not forward the listing id to OnlineClient.")
	var restored_item := service.trade_inventory[0] as Dictionary
	if int(restored_item.get("available", -1)) != 1 or int(restored_item.get("locked", -1)) != 0:
		failures.append("Trade cancel did not refresh returned inventory state.")

	save_system.call("sync_coin_balance", original_balance, "trade.action_smoke.restore")
	service.queue_free()
	fake_client.free()
	await process_frame
	if failures.is_empty():
		print("social facility trade actions smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
