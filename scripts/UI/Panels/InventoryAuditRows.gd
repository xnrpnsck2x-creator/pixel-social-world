class_name InventoryAuditRows
extends RefCounted

const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")

static func render(parent: VBoxContainer, snapshot: Dictionary, compact: bool = false) -> void:
	_clear(parent)
	if snapshot.is_empty():
		_add_label(parent, _t("ops.console.inventory.audit_empty"), compact)
		return
	var totals: Dictionary = snapshot.get("totals", {}) as Dictionary
	_add_label(parent, _t("ops.console.inventory.audit_title"), compact)
	_add_label(parent, _format("ops.console.inventory.audit_summary", {
		"available": int(totals.get("available", 0)),
		"housing": int(totals.get("housing_reservations", 0)),
		"legacy": int(totals.get("legacy_reservations", 0)),
		"locked": int(totals.get("locked", 0)),
		"owned": int(totals.get("owned", 0)),
		"trade": int(totals.get("trade_reservations", 0))
	}), compact)
	_add_flags(parent, snapshot.get("flags", []) as Array, compact)
	var items: Array = snapshot.get("items", []) as Array
	if items.is_empty():
		_add_label(parent, _t("ops.console.inventory.audit_no_items"), compact)
		return
	var shown := 0
	for raw_item in items:
		if shown >= 6:
			break
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		_add_item(parent, raw_item as Dictionary, compact)
		shown += 1

static func _add_item(parent: VBoxContainer, item: Dictionary, compact: bool) -> void:
	_add_label(parent, _format("ops.console.inventory.audit_item", {
		"available": int(item.get("available", 0)),
		"id": str(item.get("item_id", "")),
		"locked": int(item.get("locked", 0)),
		"owned": int(item.get("owned", 0))
	}), compact)
	for raw_reservation in item.get("reservations", []):
		if typeof(raw_reservation) != TYPE_DICTIONARY:
			continue
		var reservation: Dictionary = raw_reservation as Dictionary
		_add_label(parent, _format("ops.console.inventory.audit_reservation", {
			"quantity": int(reservation.get("quantity", 0)),
			"reason": str(reservation.get("reason", "reservation")),
			"source": str(reservation.get("source_id", ""))
		}), compact)

static func _add_flags(parent: VBoxContainer, flags: Array, compact: bool) -> void:
	if flags.is_empty():
		return
	_add_label(parent, _t("ops.console.inventory.audit_flags_title"), compact)
	for raw_flag in flags:
		if typeof(raw_flag) != TYPE_DICTIONARY:
			continue
		var flag: Dictionary = raw_flag as Dictionary
		_add_label(parent, _format("ops.console.inventory.audit_flag", {
			"code": str(flag.get("code", "")),
			"item": str(flag.get("item_id", "")),
			"quantity": int(flag.get("quantity", 0)),
			"severity": str(flag.get("severity", "warn"))
		}), compact)

static func _clear(parent: VBoxContainer) -> void:
	for child in parent.get_children():
		child.queue_free()

static func _add_label(parent: VBoxContainer, text: String, compact: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = PanelTextThemeScript.MUTED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelListFrameScript.new().add_hbox(parent, compact).add_child(label)

static func _t(key: String) -> String:
	var app := _app()
	if app != null and app.has_method("t_key"):
		return str(app.call("t_key", key))
	return key

static func _format(key: String, values: Dictionary) -> String:
	var app := _app()
	if app != null and app.has_method("format_key"):
		return str(app.call("format_key", key, values))
	var text := key
	for token in values.keys():
		text = text.replace("{" + str(token) + "}", str(values[token]))
	return text

static func _app() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("App")
