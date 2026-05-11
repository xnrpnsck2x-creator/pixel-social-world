class_name SocialFacilityService
extends Node

signal facilities_updated(facilities: Dictionary)

const TradeRows := preload("res://scripts/Systems/Social/SocialFacilityTradeRows.gd")

var facilities: Dictionary = {}
var trade_listings: Array = []
var trade_inventory: Array = []
var trade_history: Array = []
var source := "local"
var server_time := 0
var trade_server_time := 0

func initialize() -> void:
	_apply_catalog(_config_loader().call("load_config", "social_facilities"), "local")
	call_deferred("_refresh_online")

func refresh() -> void:
	await _refresh_online()

func get_facility(facility_id: String) -> Dictionary:
	var record: Dictionary = facilities.get(facility_id, {}).duplicate(true) as Dictionary
	if facility_id == "trade":
		record = _trade_facility_record(record)
	return record

func get_catalog() -> Dictionary:
	return {
		"schema_version": 1,
		"source": source,
		"server_time": server_time,
		"facilities": facilities.duplicate(true)
	}

func _refresh_online() -> void:
	if not _remote_enabled():
		await _refresh_trade_online()
		return
	if not _online_client_connected():
		return
	var response: Dictionary = await _online_client().call("fetch_social_facilities")
	if not bool(response.get("ok", false)):
		await _refresh_trade_online()
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	if _is_valid_catalog(data):
		_apply_catalog(data, "remote")
	await _refresh_trade_online()

func buy_trade_listing(listing_id: String) -> Dictionary:
	if not _trade_backend_enabled() or not _online_client_connected():
		return {"ok": false, "message_key": "facility.trade.offline"}
	var response: Dictionary = await _online_client().call("purchase_trade_listing", listing_id)
	if bool(response.get("ok", false)):
		_sync_wallet_from_trade_response(response)
	await _refresh_trade_after_action()
	return _with_message(response, "facility.trade.purchase.success")

func create_trade_listing(item_id: String, price: int, metadata: Dictionary) -> Dictionary:
	if not _trade_backend_enabled() or not _online_client_connected():
		return {"ok": false, "message_key": "facility.trade.offline"}
	var response: Dictionary = await _online_client().call("create_trade_listing", item_id, price, metadata)
	await _refresh_trade_after_action()
	return _with_message(response, "facility.trade.create.success")

func cancel_trade_listing(listing_id: String) -> Dictionary:
	if not _trade_backend_enabled() or not _online_client_connected():
		return {"ok": false, "message_key": "facility.trade.offline"}
	var response: Dictionary = await _online_client().call("cancel_trade_listing", listing_id)
	await _refresh_trade_after_action()
	return _with_message(response, "facility.trade.cancel.success")

func _refresh_trade_online() -> void:
	if not _trade_backend_enabled() or not _online_client_connected():
		return
	var response: Dictionary = await _online_client().call("fetch_trade_listings")
	if not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	trade_listings = data.get("items", []) as Array
	trade_server_time = int(data.get("server_time", 0))
	await _refresh_trade_inventory_online()
	await _refresh_trade_history_online()
	facilities_updated.emit(get_catalog())

func _refresh_trade_inventory_online() -> void:
	var client := _online_client()
	if client == null:
		return
	var response: Dictionary = {}
	if client.has_method("fetch_trade_inventory"):
		response = await client.call("fetch_trade_inventory")
	if not bool(response.get("ok", false)) and client.has_method("fetch_inventory"):
		response = await client.call("fetch_inventory")
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		trade_inventory = data.get("items", []) as Array

func _refresh_trade_history_online() -> void:
	var client := _online_client()
	if client == null or not client.has_method("fetch_trade_history"):
		return
	var response: Dictionary = await client.call("fetch_trade_history", 5)
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		trade_history = data.get("items", []) as Array

func _refresh_trade_after_action() -> void:
	if _trade_backend_enabled() and _online_client_connected():
		await _refresh_trade_online()

func _apply_catalog(data: Dictionary, next_source: String) -> void:
	if not _is_valid_catalog(data):
		return
	var next_facilities: Dictionary = data.get("facilities", {}) as Dictionary
	facilities = next_facilities.duplicate(true)
	source = next_source
	server_time = int(data.get("server_time", 0))
	facilities_updated.emit(get_catalog())

func _is_valid_catalog(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != 1:
		return false
	return typeof(data.get("facilities", {})) == TYPE_DICTIONARY

func _online_client_connected() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("is_connected"))

func _online_client() -> Node:
	if not has_node("/root/OnlineClient"):
		return null
	return get_node("/root/OnlineClient")

func _config_loader() -> Node:
	return get_node("/root/ConfigLoader")

func _remote_enabled() -> bool:
	return _feature_enabled("social_facilities_remote")

func _trade_backend_enabled() -> bool:
	return _feature_enabled("trade_backend")

func _feature_enabled(flag_id: String) -> bool:
	if not has_node("/root/App"):
		return false
	var app := get_node("/root/App")
	var config: Dictionary = app.get("app_config") as Dictionary
	var flags: Dictionary = config.get("feature_flags", {}) as Dictionary
	return bool(flags.get(flag_id, false))

func _trade_facility_record(record: Dictionary) -> Dictionary:
	var result: Dictionary = TradeRows.build_facility_rows(
		record,
		trade_listings,
		trade_inventory,
		trade_history,
		_player_id(),
		_coin_balance(),
		_trade_backend_enabled() and _online_client_connected()
	)
	record["rows"] = result.get("rows", []) as Array
	if bool(result.get("has_live_rows", false)):
		record["detail_key"] = "facility.trade.detail.live"
	return record

func _player_id() -> String:
	var client := _online_client()
	if client != null:
		return str(client.get("player_id"))
	return str(_save_system().call("get_player_id"))

func _with_message(response: Dictionary, message_key: String) -> Dictionary:
	var next_response := response.duplicate(true)
	if bool(next_response.get("ok", false)):
		next_response["message_key"] = message_key
	return next_response

func _sync_wallet_from_trade_response(response: Dictionary) -> void:
	var data: Dictionary = response.get("data", {}) as Dictionary
	var transfer: Dictionary = data.get("transfer", {}) as Dictionary
	var from_wallet: Dictionary = transfer.get("from", {}) as Dictionary
	if from_wallet.has("balance"):
		_save_system().call("sync_coin_balance", int(from_wallet.get("balance", _coin_balance())), "trade.purchase")

func _coin_balance() -> int:
	return int(_save_system().call("get_coin_balance"))

func _save_system() -> Node:
	return get_node("/root/SaveSystem")
