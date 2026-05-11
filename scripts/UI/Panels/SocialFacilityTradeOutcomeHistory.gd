class_name SocialFacilityTradeOutcomeHistory
extends RefCounted

const MAX_ROWS := 3

var _rows: Array = []

func add(response: Dictionary, action_type: String) -> void:
	var row := _row_for_response(response, action_type)
	if row.is_empty():
		return
	_rows.push_front(row)
	while _rows.size() > MAX_ROWS:
		_rows.pop_back()

func clear_failed() -> void:
	var kept: Array = []
	for row_record in _rows:
		var row := row_record as Dictionary
		if str(row.get("state_key", "")) != "facility.trade.outcome.failed":
			kept.append(row)
	_rows = kept

func rows() -> Array:
	var result: Array = []
	for row_record in _rows:
		result.append((row_record as Dictionary).duplicate(true))
	return result

func _row_for_response(response: Dictionary, action_type: String) -> Dictionary:
	var ok := bool(response.get("ok", false))
	var key_id := action_type.replace("_trade_listing", "")
	if not ok:
		key_id = "failed"
	var row := {
		"id": "trade.outcome.%s.%s" % [key_id, str(Time.get_ticks_msec())],
		"title_key": "facility.trade.outcome.%s.title" % key_id,
		"body_key": "facility.trade.outcome.%s.body" % key_id,
		"state_key": "facility.trade.outcome.ok" if ok else "facility.trade.outcome.failed",
		"icon_id": "icon.coin" if ok else "icon.gift"
	}
	var detail := _outcome_detail(key_id, response)
	if not detail.is_empty():
		row["body_key"] = str(detail.get("body_key", row.get("body_key", "")))
		row["body_values"] = detail.get("body_values", {})
	if not ok:
		row["action_key"] = "facility.trade.refresh.short"
		row["action"] = {"type": "refresh_trade_board"}
	return row

func _outcome_detail(key_id: String, response: Dictionary) -> Dictionary:
	var data: Dictionary = response.get("data", {}) as Dictionary
	var listing: Dictionary = data.get("listing", {}) as Dictionary
	match key_id:
		"buy":
			return _buy_outcome_detail(data, listing)
		"create":
			return _create_outcome_detail(listing)
		"cancel":
			return _cancel_outcome_detail(listing)
	return {}

func _buy_outcome_detail(data: Dictionary, listing: Dictionary) -> Dictionary:
	var transfer: Dictionary = data.get("transfer", {}) as Dictionary
	var wallet: Dictionary = transfer.get("from", {}) as Dictionary
	var coins := absi(int(wallet.get("delta", 0)))
	if coins <= 0:
		coins = int(listing.get("price", 0))
	if coins <= 0 or not wallet.has("balance"):
		return {}
	return {
		"body_key": "facility.trade.outcome.buy.delta_body",
		"body_values": {"coins": coins, "balance": int(wallet.get("balance", 0))}
	}

func _create_outcome_detail(listing: Dictionary) -> Dictionary:
	var coins := int(listing.get("price", 0))
	if coins <= 0:
		return {}
	return {
		"body_key": "facility.trade.outcome.create.delta_body",
		"body_values": {"coins": coins}
	}

func _cancel_outcome_detail(listing: Dictionary) -> Dictionary:
	var item_id := str(listing.get("item_id", ""))
	if item_id.is_empty():
		return {}
	return {
		"body_key": "facility.trade.outcome.cancel.delta_body",
		"body_values": {"item": item_id}
	}
