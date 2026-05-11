extends RefCounted

const Helpers := preload("res://tests/BackendE2EHelpers.gd")

static func verify_housing_inventory_flow(client: Node, player_id: String, failures: Array) -> String:
	var place_response: Dictionary = await client.call(
		"place_housing_item",
		player_id,
		"simple_chair",
		Vector2i(1, 2),
		0
	)
	if not Helpers.ok(place_response):
		failures.append("Housing place failed: %s" % str(place_response))
	var place_data: Dictionary = place_response.get("data", {}) as Dictionary
	if int(place_data.get("balance", -1)) != 25 or str(place_data.get("inventory_source", "")) != "owned":
		failures.append("Housing starter place did not use owned inventory.")
	var place_inventory: Array = place_data.get("inventory_items", []) as Array
	if not Helpers.inventory_has_count(place_inventory, "simple_chair", "locked", 1):
		failures.append("Housing starter place did not lock owned inventory.")
	if str(place_data.get("reservation_id", "")).is_empty():
		failures.append("Housing starter place did not return a reservation id.")
	if _reservation_reason_count(place_inventory, "simple_chair", "housing") != 1:
		failures.append("Housing starter place did not expose a housing reservation.")

	var moved_house_item := {
		"item_id": "simple_chair",
		"tile": {"x": 1, "y": 2},
		"rotation": 0
	}
	var move_response: Dictionary = await client.call(
		"move_housing_item",
		player_id,
		moved_house_item,
		Vector2i(2, 2),
		90
	)
	if not Helpers.ok(move_response):
		failures.append("Housing move failed: %s" % str(move_response))
	var moved_layout: Dictionary = (move_response.get("data", {}) as Dictionary).get("layout", {}) as Dictionary
	var moved_items: Array = moved_layout.get("items", []) as Array
	if moved_items.is_empty() or int((moved_items[0] as Dictionary).get("rotation", -1)) != 90:
		failures.append("Housing move did not persist rotation.")

	var room_id := await _verify_invite_and_purchase(client, player_id, failures)
	await _verify_remove_returns_inventory(client, player_id, failures)
	return room_id

static func _verify_invite_and_purchase(client: Node, player_id: String, failures: Array) -> String:
	var house_invite: Dictionary = await client.call("create_housing_invite", player_id)
	if not Helpers.ok(house_invite):
		failures.append("Housing invite failed: %s" % str(house_invite))
	var room_id := str((house_invite.get("data", {}) as Dictionary).get("room_id", ""))
	if room_id != "home:%s" % player_id:
		failures.append("Housing invite returned an unexpected room id: %s" % room_id)
	var purchased_place: Dictionary = await client.call(
		"place_housing_item",
		player_id,
		"simple_chair",
		Vector2i(4, 2),
		0
	)
	if not Helpers.ok(purchased_place):
		failures.append("Second housing place did not purchase an inventory-backed chair: %s" % str(purchased_place))
	var purchase_data: Dictionary = purchased_place.get("data", {}) as Dictionary
	if int(purchase_data.get("balance", -1)) != 0 or str(purchase_data.get("inventory_source", "")) != "purchased":
		failures.append("Second housing place did not spend into inventory-backed placement.")
	var purchase_inventory: Array = purchase_data.get("inventory_items", []) as Array
	if _reservation_reason_count(purchase_inventory, "simple_chair", "housing") != 2:
		failures.append("Second housing place did not expose two housing reservations.")
	var ledger: Dictionary = await client.call("fetch_coin_ledger", player_id)
	if not Helpers.ok(ledger):
		failures.append("Ledger fetch failed: %s" % str(ledger))
	var events: Array = (ledger.get("data", {}) as Dictionary).get("events", []) as Array
	if events.size() < 2:
		failures.append("Backend ledger did not include init and housing purchase events.")
	var reject_response: Dictionary = await client.call(
		"place_housing_item",
		player_id,
		"simple_chair",
		Vector2i(5, 2),
		0
	)
	if Helpers.ok(reject_response) or int(reject_response.get("status", 0)) != 402:
		failures.append("Expected third housing place to fail with 402.")
	if not bool(client.get("is_connected")):
		failures.append("HTTP 402 should not mark OnlineClient disconnected.")
	return room_id

static func _verify_remove_returns_inventory(client: Node, player_id: String, failures: Array) -> void:
	var remove_response: Dictionary = await client.call("remove_housing_item", player_id, {
		"item_id": "simple_chair",
		"tile": {"x": 2, "y": 2},
		"rotation": 90
	})
	if not Helpers.ok(remove_response):
		failures.append("Housing remove failed: %s" % str(remove_response))
	var remove_data: Dictionary = remove_response.get("data", {}) as Dictionary
	if int(remove_data.get("refund", -1)) != 0 or int(remove_data.get("balance", -1)) != 0:
		failures.append("Housing remove did not return inventory without a coin refund.")
	var remove_inventory: Array = remove_data.get("inventory_items", []) as Array
	if not Helpers.inventory_has_count(remove_inventory, "simple_chair", "available", 1):
		failures.append("Housing remove did not unlock one chair back to inventory.")
	if _reservation_reason_count(remove_inventory, "simple_chair", "housing") != 1:
		failures.append("Housing remove did not release exactly one housing reservation.")

static func _reservation_reason_count(items: Array, item_id: String, reason: String) -> int:
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw as Dictionary
		if str(item.get("item_id", "")) != item_id:
			continue
		var total := 0
		for raw_reservation in item.get("reservations", []):
			if typeof(raw_reservation) != TYPE_DICTIONARY:
				continue
			var reservation: Dictionary = raw_reservation as Dictionary
			if str(reservation.get("reason", "")) == reason:
				total += int(reservation.get("quantity", 0))
		return total
	return 0
