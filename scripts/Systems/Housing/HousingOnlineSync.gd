class_name HousingOnlineSync
extends RefCounted

var _service: Node

func _init(service_ref: Node) -> void:
	_service = service_ref

func has_online_connection() -> bool:
	if not _has_service() or not _service.has_node("/root/OnlineClient"):
		return false
	return bool(_online_client().get("is_connected"))

func sync_layout_from_online() -> void:
	if not has_online_connection():
		return
	var response: Dictionary
	var owner_id := str(_service.get("owner_id"))
	if bool(_service.get("can_edit")):
		response = await _online_client().call("fetch_housing_layout", owner_id)
	else:
		response = await _online_client().call("visit_housing", owner_id)
	if not _has_service() or not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	apply_remote_layout(data.get("layout", data) as Dictionary)
	if data.has("can_edit"):
		_service.set("can_edit", bool(data.get("can_edit", _service.get("can_edit"))))
	_save_system().call("set_profile_value", "house_sync_required", false)
	_save_system().call("save_profile")

func submit_place(item_id: String, tile: Vector2i, rotation: int) -> void:
	if not has_online_connection():
		return
	var response: Dictionary = await _online_client().call(
		"place_housing_item",
		str(_service.get("owner_id")),
		item_id,
		tile,
		rotation
	)
	await _apply_online_response(response)

func submit_style(category: String, item_id: String) -> void:
	if not has_online_connection():
		return
	var response: Dictionary = await _online_client().call(
		"apply_housing_style",
		str(_service.get("owner_id")),
		category,
		item_id
	)
	await _apply_online_response(response)

func submit_move(item: Dictionary, target_tile: Vector2i, target_rotation: int) -> void:
	if not has_online_connection():
		return
	var response: Dictionary = await _online_client().call(
		"move_housing_item",
		str(_service.get("owner_id")),
		item,
		target_tile,
		target_rotation
	)
	await _apply_online_response(response)

func submit_remove(item: Dictionary) -> void:
	if not has_online_connection():
		return
	var response: Dictionary = await _online_client().call(
		"remove_housing_item",
		str(_service.get("owner_id")),
		item
	)
	await _apply_online_response(response)

func apply_remote_layout(layout: Dictionary) -> void:
	if not _has_service():
		return
	var remote_items: Array[Dictionary] = []
	for item in layout.get("items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_dict: Dictionary = item as Dictionary
		remote_items.append({
			"item_id": str(item_dict.get("item_id", "")),
			"tile": {
				"x": int(item_dict.get("tile_x", 0)),
				"y": int(item_dict.get("tile_y", 0))
			},
			"rotation": int(item_dict.get("rotation", 0))
		})
	_service.set("placed_items", remote_items)
	var remote_styles: Variant = layout.get("styles", {})
	if typeof(remote_styles) == TYPE_DICTIONARY:
		_service.set("styles", (remote_styles as Dictionary).duplicate(true))
	_service.call("_save_layout")
	_service.emit_signal("layout_loaded")

func _apply_online_response(response: Dictionary) -> void:
	if not _has_service():
		return
	if not bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		if data.has("balance"):
			_save_system().call("sync_coin_balance", int(data.get("balance", 0)), "server.housing_reject")
		if has_online_connection():
			var owner_id := str(_service.get("owner_id"))
			var layout_response: Dictionary = await _online_client().call("fetch_housing_layout", owner_id)
			if _has_service() and bool(layout_response.get("ok", false)):
				apply_remote_layout(layout_response.get("data", {}) as Dictionary)
				return
		_mark_sync_required(true)
		if _has_service():
			_service.emit_signal("placement_failed", "error.network")
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	if data.has("balance"):
		_save_system().call("sync_coin_balance", int(data.get("balance", 0)), "server.housing")
	if data.has("layout"):
		apply_remote_layout(data.get("layout", {}) as Dictionary)
	_mark_sync_required(false)

func _mark_sync_required(required: bool) -> void:
	if not _has_service():
		return
	_save_system().call("set_profile_value", "house_sync_required", required)
	_save_system().call("save_profile")

func _online_client() -> Node:
	return _service.get_node("/root/OnlineClient")

func _save_system() -> Node:
	return _service.get_node("/root/SaveSystem")

func _has_service() -> bool:
	return _service != null and is_instance_valid(_service)
