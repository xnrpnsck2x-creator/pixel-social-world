extends SceneTree

const TradeFeedback := preload("res://scripts/UI/Panels/SocialFacilityTradeFeedback.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("insufficient_funds", "buy_trade_listing", _price_values()),
		"Not enough coins",
		"insufficient funds"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("listing_inactive", "buy_trade_listing", _price_values()),
		"Someone bought this first",
		"race-lost purchase"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("listing_inactive", "cancel_trade_listing", _price_values()),
		"already closed",
		"closed cancel"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("item_unavailable", "create_trade_listing", _price_values()),
		"locked or unavailable",
		"locked listing stock"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("item_unavailable", "buy_trade_listing", _price_values()),
		"escrow changed",
		"escrow changed purchase"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("http_0", "buy_trade_listing", _price_values()),
		"Trade service is unavailable",
		"weak network transport failure"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_error("invalid_listing", "create_trade_listing", _price_values()),
		"9999",
		"invalid price range"
	)
	_expect_contains(
		failures,
		TradeFeedback.text_for_response(
			{"ok": true, "message_key": "facility.trade.cancel.success"},
			"cancel_trade_listing",
			_price_values()
		),
		"Listing cancelled",
		"message key success"
	)
	if failures.is_empty():
		print("social facility trade feedback smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _price_values() -> Dictionary:
	return {"min": 1, "max": 9999}

func _expect_contains(failures: Array[String], value: String, needle: String, label: String) -> void:
	if not value.contains(needle):
		failures.append("Trade feedback missing %s text. Got: %s" % [label, value])
