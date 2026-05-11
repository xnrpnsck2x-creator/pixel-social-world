class_name HousingOnlineSync
extends RefCounted

var _service: Node

func _init(service_ref: Node) -> void:
	_service = service_ref

func has_online_connection() -> bool:
	if not _has_service():
		return false
	var client := _online_client()
	if client == null:
		return false
	if client.has_method("has_authenticated_session"):
		return bool(client.call("has_authenticated_session"))
	return bool(client.get("online_enabled")) and not str(client.get("access_token")).strip_edges().is_empty()

func sync_layout_from_online() -> void:
	if not has_online_connection():
		return
	if bool(_service.get("can_edit")):
		await sync_inventory_from_online()
	if not has_online_connection():
		return
	var response: Dictionary
	var owner_id := str(_service.get("owner_id"))
	var client := _online_client()
	if client == null:
		return
	if bool(_service.get("can_edit")):
		response = await client.call("fetch_housing_layout", owner_id)
	else:
		response = await client.call("visit_housing", owner_id)
	if not _has_service() or not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	apply_remote_layout(data.get("layout", data) as Dictionary)
	if data.has("can_edit"):
		_service.set("can_edit", bool(data.get("can_edit", _service.get("can_edit"))))
	var save_system := _save_system()
	if save_system != null:
		save_system.call("set_profile_value", "house_sync_required", false)
		save_system.call("save_profile")

func sync_inventory_from_online() -> void:
	if not has_online_connection():
		return
	var owner_id := str(_service.get("owner_id"))
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call("fetch_inventory", owner_id)
	if not _has_service() or not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	if data.has("items"):
		var save_system := _save_system()
		if save_system != null:
			save_system.call("set_profile_value", "online_inventory_items", data.get("items", []))
			save_system.call("save_profile")

func submit_place(item_id: String, tile: Vector2i, rotation: int) -> void:
	if not has_online_connection():
		return
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call(
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
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call(
		"apply_housing_style",
		str(_service.get("owner_id")),
		category,
		item_id
	)
	await _apply_online_response(response)

func submit_move(item: Dictionary, target_tile: Vector2i, target_rotation: int) -> void:
	if not has_online_connection():
		return
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call(
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
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = await client.call(
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
		var save_system := _save_system()
		if data.has("balance") and save_system != null:
			save_system.call("sync_coin_balance", int(data.get("balance", 0)), "server.housing_reject")
		if has_online_connection():
			var owner_id := str(_service.get("owner_id"))
			var client := _online_client()
			if client == null:
				return
			var layout_response: Dictionary = await client.call("fetch_housing_layout", owner_id)
			if _has_service() and bool(layout_response.get("ok", false)):
				apply_remote_layout(layout_response.get("data", {}) as Dictionary)
				return
		_mark_sync_required(true)
		if _has_service():
			_service.emit_signal("placement_failed", "error.network")
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	var save_system := _save_system()
	if data.has("balance") and save_system != null:
		save_system.call("sync_coin_balance", int(data.get("balance", 0)), "server.housing")
	if data.has("inventory_items") and save_system != null:
		save_system.call("set_profile_value", "online_inventory_items", data.get("inventory_items", []))
	if data.has("layout"):
		apply_remote_layout(data.get("layout", {}) as Dictionary)
	_mark_sync_required(false)

func _mark_sync_required(required: bool) -> void:
	if not _has_service():
		return
	var save_system := _save_system()
	if save_system == null:
		return
	save_system.call("set_profile_value", "house_sync_required", required)
	save_system.call("save_profile")

func _online_client() -> Node:
	return _root_node("OnlineClient")

func _save_system() -> Node:
	return _root_node("SaveSystem")

func _has_service() -> bool:
	return _service != null and is_instance_valid(_service)

func _root_node(node_name: String) -> Node:
	var tree := _scene_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)

func _scene_tree() -> SceneTree:
	if _has_service() and _service.is_inside_tree():
		return _service.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null
