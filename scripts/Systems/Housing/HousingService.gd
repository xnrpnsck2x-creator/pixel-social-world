class_name HousingService
extends Node

signal item_placed(item: Dictionary)
signal item_moved(item: Dictionary)
signal item_removed(item: Dictionary)
signal layout_loaded()
signal style_changed(category: String, item_id: String)
signal placement_failed(reason_key: String)

const GRID_SIZE := Vector2i(8, 5)
const HousingLayoutRulesScript := preload("res://scripts/Systems/Housing/HousingLayoutRules.gd")
const HousingOnlineSyncScript := preload("res://scripts/Systems/Housing/HousingOnlineSync.gd")

var catalog_by_id: Dictionary = {}
var placed_items: Array[Dictionary] = []
var styles: Dictionary = {}
var owner_id := ""
var can_edit := true
var online_sync

func initialize(new_owner_id: String = "", read_only: bool = false) -> void:
	online_sync = HousingOnlineSyncScript.new(self)
	catalog_by_id.clear()
	owner_id = new_owner_id if not new_owner_id.is_empty() else str(_save_system().call("get_player_id"))
	can_edit = not read_only and owner_id == str(_save_system().call("get_player_id"))
	var config: Dictionary = _config_loader().call("load_config", "housing_items")
	for item in config.get("items", []):
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			catalog_by_id[str(item["id"])] = item
	_load_layout()
	call_deferred("_sync_layout_from_online")

func get_catalog() -> Array:
	return catalog_by_id.values()

func place_item(item_id: String, tile: Vector2i) -> bool:
	if not can_edit:
		placement_failed.emit("housing.error.visit_read_only")
		return false
	if not catalog_by_id.has(item_id):
		push_warning("Unknown housing item: %s" % item_id)
		return false
	if not can_place_item(item_id, tile):
		placement_failed.emit(_placement_error_key(item_id, tile))
		return false

	var item: Dictionary = catalog_by_id[item_id]
	var price := int(item.get("price", 0))
	if not bool(_save_system().call("spend_coins", price, "housing.%s" % item_id)):
		placement_failed.emit("housing.error.not_enough_coins")
		return false

	if str(item.get("item_type", "")) == "surface":
		var category := str(item.get("category", "style"))
		styles[category] = item_id
		_save_layout()
		style_changed.emit(category, item_id)
		_online_sync().submit_style(category, item_id)
		return true

	var placed_item: Dictionary = {
		"item_id": item_id,
		"tile": {"x": tile.x, "y": tile.y},
		"rotation": 0
	}
	placed_items.append(placed_item)
	_save_layout()
	item_placed.emit(placed_item)
	_online_sync().submit_place(item_id, tile, 0)
	return true

func get_placed_items() -> Array[Dictionary]:
	return placed_items.duplicate(true)

func get_item_at_tile(tile: Vector2i) -> Dictionary:
	return HousingLayoutRulesScript.item_at_tile(catalog_by_id, placed_items, tile)

func get_styles() -> Dictionary:
	return styles.duplicate(true)

func get_owner_id() -> String:
	return owner_id

func can_edit_room() -> bool:
	return can_edit

func apply_remote_layout(layout: Dictionary) -> void:
	_online_sync().apply_remote_layout(layout)

func get_item(item_id: String) -> Dictionary:
	if catalog_by_id.has(item_id):
		return catalog_by_id[item_id] as Dictionary
	return {}

func can_place_item(item_id: String, tile: Vector2i) -> bool:
	return can_place_item_with_rotation(item_id, tile, 0)

func can_place_item_with_rotation(item_id: String, tile: Vector2i, rotation: int) -> bool:
	return HousingLayoutRulesScript.can_place(catalog_by_id, placed_items, GRID_SIZE, item_id, tile, rotation)

func can_move_item_to(item: Dictionary, target_tile: Vector2i, target_rotation: int = -1) -> bool:
	var index := HousingLayoutRulesScript.placed_index(placed_items, item)
	if index < 0:
		return false
	var item_id := str(item.get("item_id", ""))
	var rotation := int(item.get("rotation", 0)) if target_rotation < 0 else target_rotation
	return HousingLayoutRulesScript.can_place(
		catalog_by_id,
		placed_items,
		GRID_SIZE,
		item_id,
		target_tile,
		rotation,
		index
	)

func move_item(item: Dictionary, target_tile: Vector2i, target_rotation: int = 0) -> bool:
	if not can_edit:
		placement_failed.emit("housing.error.visit_read_only")
		return false
	var index := HousingLayoutRulesScript.placed_index(placed_items, item)
	if index < 0:
		placement_failed.emit("housing.error.item_not_found")
		return false
	var item_id := str(item.get("item_id", ""))
	if not HousingLayoutRulesScript.can_place(
		catalog_by_id,
		placed_items,
		GRID_SIZE,
		item_id,
		target_tile,
		target_rotation,
		index
	):
		placement_failed.emit(_placement_error_key(item_id, target_tile, target_rotation))
		return false
	placed_items[index]["tile"] = {"x": target_tile.x, "y": target_tile.y}
	placed_items[index]["rotation"] = HousingLayoutRulesScript.normalize_rotation(target_rotation)
	_save_layout()
	item_moved.emit(placed_items[index])
	_online_sync().submit_move(item, target_tile, target_rotation)
	return true

func rotate_item(item: Dictionary) -> bool:
	var rotation := HousingLayoutRulesScript.normalize_rotation(int(item.get("rotation", 0)) + 90)
	var tile_data: Dictionary = item.get("tile", {})
	return move_item(item, Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0))), rotation)

func remove_item(item: Dictionary) -> bool:
	if not can_edit:
		placement_failed.emit("housing.error.visit_read_only")
		return false
	var index := HousingLayoutRulesScript.placed_index(placed_items, item)
	if index < 0:
		placement_failed.emit("housing.error.item_not_found")
		return false
	var removed: Dictionary = placed_items[index].duplicate(true)
	placed_items.remove_at(index)
	_save_layout()
	if not _online_connected():
		_save_system().call("grant_coins", sell_refund_amount(str(removed.get("item_id", ""))), "housing.sell")
	item_removed.emit(removed)
	_online_sync().submit_remove(removed)
	return true

func sell_refund_amount(item_id: String) -> int:
	return _sell_refund_for_item(catalog_by_id.get(item_id, {}))

func _load_layout() -> void:
	placed_items.clear()
	var save_system := _save_system()
	var saved_items: Variant = save_system.call("get_profile_value", "house_items", [])
	if typeof(saved_items) == TYPE_ARRAY:
		for item in saved_items:
			if typeof(item) == TYPE_DICTIONARY:
				placed_items.append(item)

	var saved_styles: Variant = save_system.call("get_profile_value", "house_styles", {})
	if typeof(saved_styles) == TYPE_DICTIONARY:
		styles = (saved_styles as Dictionary).duplicate(true)
	if styles.is_empty():
		styles = {"wall": "starter_wallpaper", "floor": "wooden_floor"}

func _save_layout() -> void:
	var save_system := _save_system()
	save_system.call("set_profile_value", "house_items", placed_items.duplicate(true))
	save_system.call("set_profile_value", "house_styles", styles.duplicate(true))
	save_system.call("save_profile")

func _sync_layout_from_online() -> void:
	_online_sync().sync_layout_from_online()

func _placement_error_key(item_id: String, tile: Vector2i, rotation: int = 0) -> String:
	return HousingLayoutRulesScript.placement_error_key(catalog_by_id, GRID_SIZE, item_id, tile, rotation)

func _sell_refund_for_item(catalog_item: Dictionary) -> int:
	var price := int(catalog_item.get("price", 0))
	if price <= 0:
		return 0
	var rate := float(_config_loader().call("get_value", "economy", ["housing", "sell_refund_rate"], 0.5))
	return maxi(0, floori(float(price) * clampf(rate, 0.0, 1.0)))

func _config_loader() -> Node:
	return get_node("/root/ConfigLoader")

func _save_system() -> Node:
	return get_node("/root/SaveSystem")

func _online_connected() -> bool:
	return _online_sync().has_online_connection()

func _online_sync():
	if online_sync == null:
		online_sync = HousingOnlineSyncScript.new(self)
	return online_sync
