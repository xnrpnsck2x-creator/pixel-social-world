extends SceneTree

const InventoryAuditRowsScript := preload("res://scripts/UI/Panels/InventoryAuditRows.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var rows := VBoxContainer.new()
	root.add_child(rows)
	InventoryAuditRowsScript.render(rows, {
		"totals": {
			"owned": 3,
			"locked": 2,
			"available": 1,
			"housing_reservations": 1,
			"trade_reservations": 1,
			"legacy_reservations": 0
		},
		"flags": [{
			"code": "locked_without_reservation",
			"item_id": "legacy_chair",
			"quantity": 1,
			"severity": "warn"
		}],
		"items": [{
			"item_id": "simple_chair",
			"owned": 2,
			"locked": 1,
			"available": 1,
			"reservations": [{
				"reason": "housing",
				"quantity": 1,
				"source_id": "housing:player:simple_chair:1"
			}]
		}, {
			"item_id": "arcade_cabinet",
			"owned": 1,
			"locked": 1,
			"available": 0,
			"reservations": [{
				"reason": "trade",
				"quantity": 1,
				"source_id": "trade:listing-a"
			}]
		}]
	})
	await process_frame
	for text in ["Inventory Audit", "owned 3", "Repair Flags", "locked_without_reservation", "simple_chair", "housing x1", "trade:listing-a"]:
		if not _node_text_contains(rows, text):
			failures.append("Inventory audit rows missing text: %s" % text)
	rows.queue_free()
	if failures.is_empty():
		print("inventory audit rows smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false
