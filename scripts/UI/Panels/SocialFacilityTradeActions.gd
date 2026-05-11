class_name SocialFacilityTradeActions
extends RefCounted

const MIN_TRADE_PRICE := 1
const MAX_TRADE_PRICE := 9999

static func action_type(action: Dictionary) -> String:
	return str(action.get("type", ""))

static func action_key(action: Dictionary) -> String:
	var current_action_type := action_type(action)
	match current_action_type:
		"buy_trade_listing", "cancel_trade_listing":
			return "%s:%s" % [current_action_type, str(action.get("listing_id", ""))]
		"create_trade_listing":
			return "%s:%s" % [current_action_type, str(action.get("item_id", ""))]
	return current_action_type

static func needs_price(action: Dictionary) -> bool:
	return action_type(action) == "create_trade_listing"

static func has_valid_price(price_input: LineEdit) -> bool:
	return price_from_input(price_input) > 0

static func price_from_input(price_input: LineEdit) -> int:
	if price_input == null:
		return 0
	var price_text := price_input.text.strip_edges()
	if not price_text.is_valid_int():
		return 0
	var price := int(price_text)
	if price < MIN_TRADE_PRICE or price > MAX_TRADE_PRICE:
		return 0
	return price

static func price_range_values() -> Dictionary:
	return {"min": MIN_TRADE_PRICE, "max": MAX_TRADE_PRICE}

static func perform(facility_service: Node, action: Dictionary, price_input: LineEdit = null) -> Dictionary:
	if facility_service == null:
		return {}
	var current_action_type := action_type(action)
	match current_action_type:
		"buy_trade_listing":
			if facility_service.has_method("buy_trade_listing"):
				return await facility_service.call("buy_trade_listing", str(action.get("listing_id", "")))
		"create_trade_listing":
			if facility_service.has_method("create_trade_listing"):
				return await facility_service.call(
					"create_trade_listing",
					str(action.get("item_id", "")),
					price_from_input(price_input),
					action.get("metadata", {}) as Dictionary
				)
		"cancel_trade_listing":
			if facility_service.has_method("cancel_trade_listing"):
				return await facility_service.call("cancel_trade_listing", str(action.get("listing_id", "")))
	return {}
