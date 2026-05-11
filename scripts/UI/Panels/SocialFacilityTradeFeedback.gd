class_name SocialFacilityTradeFeedback
extends RefCounted

static func text_for_response(response: Dictionary, action_type: String, price_values: Dictionary) -> String:
	if response.has("message_key"):
		return _t_key(str(response.get("message_key", "")))
	if bool(response.get("ok", false)):
		return _t_key(success_key(action_type))
	return text_for_error(str(response.get("error", "")), action_type, price_values)

static func text_for_error(error_id: String, action_type: String, price_values: Dictionary) -> String:
	var error_key := key_for_error(error_id, action_type)
	if error_key == "facility.trade.price.invalid":
		return _format_key(error_key, price_values)
	return _t_key(error_key)

static func success_key(action_type: String) -> String:
	match action_type:
		"create_trade_listing":
			return "facility.trade.create.success"
		"cancel_trade_listing":
			return "facility.trade.cancel.success"
		_:
			return "facility.trade.purchase.success"

static func key_for_error(error_id: String, action_type: String) -> String:
	match error_id:
		"invalid_listing":
			return "facility.trade.price.invalid"
		"listing_not_found":
			return "facility.trade.purchase.race_lost" if action_type == "buy_trade_listing" else "facility.trade.cancel.inactive"
		"listing_inactive":
			return "facility.trade.purchase.race_lost" if action_type == "buy_trade_listing" else "facility.trade.cancel.inactive"
		"item_unavailable":
			if action_type == "buy_trade_listing":
				return "facility.trade.purchase.escrow_missing"
			return "facility.trade.create.unavailable"
		"insufficient_funds":
			return "facility.trade.purchase.insufficient"
		"self_purchase_forbidden":
			return "facility.trade.purchase.self"
		"forbidden":
			return "facility.trade.cancel.forbidden"
		"unauthorized":
			return "facility.trade.error.auth"
		"invalid_request":
			return "facility.trade.error.invalid_request"
		"trade_unavailable", "inventory_unavailable", "request_start_failed", "online_disabled", "http_0", "request_timeout":
			return "facility.trade.error.connection"
		_:
			return "facility.trade.purchase.failed"

static func _t_key(key: String) -> String:
	var app := _app()
	if app != null and app.has_method("t_key"):
		return str(app.call("t_key", key))
	return key

static func _format_key(key: String, values: Dictionary) -> String:
	var app := _app()
	if app != null and app.has_method("format_key"):
		return str(app.call("format_key", key, values))
	return key

static func _app() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("App")
	return null
