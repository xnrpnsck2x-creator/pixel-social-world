class_name OnlineClientEconomy
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func fetch_coin_ledger(player_id_override: String = "") -> Dictionary:
	var safe_player: String = _client._owner_or_player(player_id_override).uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, "/economy/ledger/%s" % safe_player)

func fetch_inventory(player_id_override: String = "") -> Dictionary:
	var safe_player: String = _client._owner_or_player(player_id_override).uri_encode()
	return await _client._request_json(HTTPClient.METHOD_GET, "/inventory?player_id=%s" % safe_player)

func claim_first_session_reward(completed_step_ids: Array = []) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/economy/first-session/claim", {
		"player_id": _client.player_id,
		"completed_step_ids": completed_step_ids
	})

func claim_map_activity(map_id: String, action_id: String) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/map-activities/claim", {
		"player_id": _client.player_id,
		"map_id": map_id,
		"action_id": action_id
	})
