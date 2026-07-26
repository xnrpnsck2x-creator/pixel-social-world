class_name OnlineClientCreator
extends RefCounted

var _client

func _init(client_ref) -> void:
	_client = client_ref

func submit_draft(request: Dictionary) -> Dictionary:
	var payload := request.duplicate(true)
	payload["author"] = _client.player_id
	_normalize_submit_numbers(payload)
	return await _client._request_json(HTTPClient.METHOD_POST, "/creator-submissions/draft", payload)

func submit_package(request: Dictionary) -> Dictionary:
	var payload := request.duplicate(true)
	payload["author"] = _client.player_id
	_normalize_submit_numbers(payload)
	_normalize_resolved_manifest(payload.get("resolved_manifest", {}) as Dictionary)
	var files: Array = payload.get("files", []) as Array
	for value in files:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var file := value as Dictionary
		if file.has("size_bytes"):
			file["size_bytes"] = int(file.get("size_bytes", 0))
	return await _client._request_json(HTTPClient.METHOD_POST, "/creator-submissions/package", payload)

func fetch_registry(filters: Dictionary = {}) -> Dictionary:
	var query: Array[String] = []
	for key in ["kind", "mode_id", "locale", "q", "cursor", "limit"]:
		if not filters.has(key):
			continue
		var value := str(filters.get(key, "")).strip_edges()
		if value.is_empty():
			continue
		query.append("%s=%s" % [key, value.uri_encode()])
	var route := "/creator-registry"
	if not query.is_empty():
		route += "?" + "&".join(query)
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_registry_entry(entry_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_GET,
		"/creator-registry/%s" % entry_id.uri_encode()
	)

func discover_keywords(
	text: String,
	mode_id: String = "",
	locale: String = "en",
	limit: int = 12
) -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_POST, "/creator-discovery/keywords", {
		"player_id": _client.player_id,
		"text": text,
		"mode_id": mode_id,
		"locale": locale,
		"limit": limit
	})

func resolve_manifest(manifest: Dictionary) -> Dictionary:
	var normalized_manifest := manifest.duplicate(true)
	_normalize_resolved_manifest(normalized_manifest)
	var response: Dictionary = await _client._request_json(
		HTTPClient.METHOD_POST,
		"/creator-manifests/resolve",
		{
		"player_id": _client.player_id,
		"manifest": normalized_manifest
		}
	)
	var data := response.get("data", {}) as Dictionary
	_normalize_resolved_manifest(data.get("resolved_manifest", {}) as Dictionary)
	return response

func fetch_submission_status(game_id: String) -> Dictionary:
	var route := "/creator-submissions/%s/status?player_id=%s" % [
		game_id.uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_submission_history(game_id: String) -> Dictionary:
	var route := "/creator-submissions/%s/history?player_id=%s" % [
		game_id.uri_encode(),
		_client.player_id.uri_encode()
	]
	return await _client._request_json(HTTPClient.METHOD_GET, route)

func fetch_published_catalog() -> Dictionary:
	return await _client._request_json(HTTPClient.METHOD_GET, "/minigames/catalog")

func fetch_published_runtime(game_id: String) -> Dictionary:
	return await _client._request_json(
		HTTPClient.METHOD_GET,
		"/minigames/%s/runtime" % game_id.uri_encode()
	)

func _normalize_submit_numbers(payload: Dictionary) -> void:
	for key in ["min_players", "max_players", "asset_budget_bytes"]:
		if payload.has(key):
			payload[key] = int(payload.get(key, 0))

func _normalize_resolved_manifest(manifest: Dictionary) -> void:
	if manifest.has("schema_version"):
		manifest["schema_version"] = int(manifest.get("schema_version", 0))
