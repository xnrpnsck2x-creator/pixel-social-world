class_name OnlineClientTrade
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func fetch_trade_history(limit: int = 5) -> Dictionary:
	var route := "/trade/history?player_id=%s&limit=%d" % [
		_client.player_id.uri_encode(),
		limit
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)
