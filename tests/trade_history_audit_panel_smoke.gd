extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/TradeHistoryAuditPanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	panel.call("set_admin_token", "admin-smoke")
	panel.call("set_trade_history_snapshot", {
		"count": 2,
		"matched": 2,
		"items": [{
			"id": "event-sold-1",
			"type": "sold",
			"listing_id": "listing-a",
			"seller_id": "seller-a",
			"buyer_id": "buyer-a",
			"item_id": "simple_chair",
			"icon_id": "icon.home",
			"price": 7
		}, {
			"id": "event-created-1",
			"type": "created",
			"listing_id": "listing-b",
			"seller_id": "seller-b",
			"item_id": "arcade_cabinet",
			"icon_id": "icon.gift",
			"price": 12
		}]
	})
	await process_frame
	for text in ["Trade History", "Export CSV", "2 shown", "sold", "seller-a", "buyer-a", "simple_chair", "created", "arcade_cabinet"]:
		if not _node_text_contains(panel, text):
			failures.append("Trade history audit panel missing text: %s" % text)
	panel.queue_free()
	if failures.is_empty():
		print("trade history audit panel smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false
