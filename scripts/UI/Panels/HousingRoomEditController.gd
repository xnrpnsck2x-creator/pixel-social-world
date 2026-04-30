class_name HousingRoomEditController
extends Node

signal selection_changed()
signal coin_changed()
signal status_key_requested(key: String)
signal status_text_requested(text: String)

var housing_service: Node
var selected_item_id := ""
var selected_placed_item: Dictionary = {}
var _undo_before: Dictionary = {}
var _undo_after: Dictionary = {}

func bind(new_service: Node) -> void:
	housing_service = new_service

func handle_catalog_item(item_id: String) -> void:
	_clear_placed_selection()
	var item: Dictionary = housing_service.get_item(item_id)
	if str(item.get("item_type", "")) == "surface":
		if housing_service.place_item(item_id, Vector2i.ZERO):
			coin_changed.emit()
		return
	selected_item_id = item_id
	status_text_requested.emit(_format_key("housing.selected_format", {
		"item": _t_key(str(item.get("name_key", "")))
	}))
	selection_changed.emit()

func handle_tile(tile: Vector2i) -> bool:
	var placed_item: Dictionary = housing_service.get_item_at_tile(tile)
	if not selected_placed_item.is_empty() and placed_item.is_empty():
		return move_selected_to(tile)
	if not placed_item.is_empty():
		select_placed_item(placed_item)
		return true
	if selected_item_id.is_empty():
		return false
	if housing_service.place_item(selected_item_id, tile):
		coin_changed.emit()
		selection_changed.emit()
		return true
	return false

func select_placed_item(item: Dictionary) -> void:
	selected_placed_item = item
	selected_item_id = ""
	var catalog_item: Dictionary = housing_service.get_item(str(item.get("item_id", "")))
	status_text_requested.emit(_format_key("housing.move_hint_format", {
		"item": _t_key(str(catalog_item.get("name_key", "")))
	}))
	selection_changed.emit()

func move_selected_to(tile: Vector2i) -> bool:
	if selected_placed_item.is_empty():
		return false
	var rotation := int(selected_placed_item.get("rotation", 0))
	var before := selected_placed_item.duplicate(true)
	if not housing_service.move_item(selected_placed_item, tile, rotation):
		return false
	_capture_undo(before, _transform_item(before, tile, rotation))
	_clear_placed_selection()
	coin_changed.emit()
	status_text_requested.emit(_t_key("housing.undo_ready_format"))
	return true

func rotate_selected() -> bool:
	if selected_placed_item.is_empty():
		return false
	var before := selected_placed_item.duplicate(true)
	var target_rotation := posmod(int(before.get("rotation", 0)) + 90, 360)
	if not housing_service.rotate_item(selected_placed_item):
		return false
	var tile_data: Dictionary = before.get("tile", {})
	var target_tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
	_capture_undo(before, _transform_item(before, target_tile, target_rotation))
	_clear_placed_selection()
	coin_changed.emit()
	status_text_requested.emit(_t_key("housing.undo_ready_format"))
	return true

func sell_selected() -> bool:
	if selected_placed_item.is_empty():
		return false
	var item_id := str(selected_placed_item.get("item_id", ""))
	var catalog_item: Dictionary = housing_service.get_item(item_id)
	var refund := int(housing_service.sell_refund_amount(item_id))
	if not housing_service.remove_item(selected_placed_item):
		return false
	_clear_placed_selection()
	_clear_undo()
	coin_changed.emit()
	status_text_requested.emit(_format_key("housing.sell_refund_format", {
		"item": _t_key(str(catalog_item.get("name_key", ""))),
		"coins": refund
	}))
	return true

func undo_last_transform() -> bool:
	if _undo_before.is_empty() or _undo_after.is_empty():
		return false
	var tile_data: Dictionary = _undo_before.get("tile", {})
	var target_tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
	var target_rotation := int(_undo_before.get("rotation", 0))
	if not housing_service.move_item(_undo_after, target_tile, target_rotation):
		status_key_requested.emit("housing.error.invalid_placement")
		return false
	_clear_undo()
	_clear_placed_selection()
	status_text_requested.emit(_t_key("housing.undo_applied_format"))
	return true

func has_selection() -> bool:
	return not selected_placed_item.is_empty()

func can_undo() -> bool:
	return not _undo_before.is_empty() and not _undo_after.is_empty()

func reset_selection() -> void:
	selected_item_id = ""
	selected_placed_item = {}
	selection_changed.emit()

func _clear_placed_selection() -> void:
	selected_placed_item = {}
	selection_changed.emit()

func _capture_undo(before: Dictionary, after: Dictionary) -> void:
	_undo_before = before.duplicate(true)
	_undo_after = after.duplicate(true)
	selection_changed.emit()

func _clear_undo() -> void:
	_undo_before = {}
	_undo_after = {}
	selection_changed.emit()

func _transform_item(item: Dictionary, tile: Vector2i, rotation: int) -> Dictionary:
	return {
		"item_id": str(item.get("item_id", "")),
		"tile": {"x": tile.x, "y": tile.y},
		"rotation": posmod(rotation, 360)
	}

func _t_key(key: String) -> String:
	return str(get_node("/root/App").call("t_key", key))

func _format_key(key: String, values: Dictionary) -> String:
	return str(get_node("/root/App").call("format_key", key, values))
