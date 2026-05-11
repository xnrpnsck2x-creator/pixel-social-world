class_name MainCityMapDiscovery
extends RefCounted

const DEFAULT_MAP_ID := "city_forest_dawn_v1"
const PROFILE_KEY := "discovered_world_map_ids"
const PROFILE_RECORDS_KEY := "discovered_world_map_records"
const SOURCE_ARRIVAL := "arrival"
const SOURCE_SYNC := "sync"
const TRAVEL_STATUSES := ["route_exposed", "playtest_candidate"]

func discover(map_id: String, source: String = SOURCE_ARRIVAL) -> bool:
	if map_id.is_empty():
		return false
	var ids := discovered_ids()
	var discovered := not ids.has(map_id)
	if not ids.has(map_id):
		ids.append(map_id)
	SaveSystem.set_profile_value(PROFILE_KEY, ids)
	_upsert_local_record(map_id, source)
	SaveSystem.save_profile()
	return discovered

func sync_from_backend() -> void:
	var client := _online_client()
	if not _has_online_session(client):
		return
	var response: Dictionary = await client.call("_request_json", HTTPClient.METHOD_POST, "/players/maps/discovered/sync", {
		"player_id": str(client.get("player_id")),
		"map_ids": discovered_ids(),
		"source": SOURCE_SYNC
	})
	if bool(response.get("ok", false)):
		_apply_remote_ids(response.get("data", {}) as Dictionary)

func push_remote(map_id: String, source: String = SOURCE_ARRIVAL) -> void:
	if map_id.is_empty():
		return
	var client := _online_client()
	if not _has_online_session(client):
		return
	var response: Dictionary = await client.call("_request_json", HTTPClient.METHOD_POST, "/players/maps/discovered", {
		"player_id": str(client.get("player_id")),
		"map_id": map_id,
		"source": source
	})
	if bool(response.get("ok", false)):
		_apply_remote_ids(response.get("data", {}) as Dictionary)

func is_discovered(map_id: String) -> bool:
	return discovered_ids().has(map_id)

func can_travel_to(map_id: String, record: Dictionary) -> bool:
	if not is_discovered(map_id):
		return false
	return TRAVEL_STATUSES.has(str(record.get("status", "")))

func discovered_ids() -> Array[String]:
	var raw: Variant = SaveSystem.get_profile_value(PROFILE_KEY, [DEFAULT_MAP_ID])
	var ids: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw as Array:
			var map_id := str(value)
			if not map_id.is_empty() and not ids.has(map_id):
				ids.append(map_id)
	if not ids.has(DEFAULT_MAP_ID):
		ids.append(DEFAULT_MAP_ID)
	return ids

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("OnlineClient")

func _has_online_session(client: Node) -> bool:
	if client == null:
		return false
	return bool(client.get("online_enabled")) and not str(client.get("access_token")).is_empty()

func _apply_remote_ids(data: Dictionary) -> void:
	var raw_maps: Variant = data.get("maps", [])
	var records: Array[Dictionary] = []
	var ids: Array[String] = []
	if typeof(raw_maps) == TYPE_ARRAY and not (raw_maps as Array).is_empty():
		for value in raw_maps as Array:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var row := value as Dictionary
			var map_id := str(row.get("map_id", ""))
			if map_id.is_empty():
				continue
			ids.append(map_id)
			records.append({
				"map_id": map_id,
				"source": str(row.get("source", SOURCE_SYNC)),
				"discovered_at": int(row.get("discovered_at", 0))
			})
	else:
		var raw_ids: Variant = data.get("map_ids", [])
		if typeof(raw_ids) == TYPE_ARRAY:
			for value in raw_ids as Array:
				var map_id := str(value)
				if not map_id.is_empty() and not ids.has(map_id):
					ids.append(map_id)
					records.append(_record(map_id, SOURCE_SYNC))
	if not ids.has(DEFAULT_MAP_ID):
		ids.append(DEFAULT_MAP_ID)
		records.append(_record(DEFAULT_MAP_ID, "default"))
	SaveSystem.set_profile_value(PROFILE_KEY, ids)
	SaveSystem.set_profile_value(PROFILE_RECORDS_KEY, records)
	SaveSystem.save_profile()

func _upsert_local_record(map_id: String, source: String) -> void:
	var records := _local_records()
	for index in range(records.size()):
		var row := records[index]
		if str(row.get("map_id", "")) == map_id:
			if str(row.get("source", "")) != SOURCE_SYNC or source == SOURCE_SYNC:
				return
			records[index] = _record(map_id, source)
			SaveSystem.set_profile_value(PROFILE_RECORDS_KEY, records)
			return
	records.append(_record(map_id, source))
	SaveSystem.set_profile_value(PROFILE_RECORDS_KEY, records)

func _local_records() -> Array[Dictionary]:
	var raw: Variant = SaveSystem.get_profile_value(PROFILE_RECORDS_KEY, [])
	var records: Array[Dictionary] = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw as Array:
			if typeof(value) == TYPE_DICTIONARY:
				records.append(value as Dictionary)
	return records

func _record(map_id: String, source: String) -> Dictionary:
	return {
		"map_id": map_id,
		"source": source,
		"discovered_at": int(Time.get_unix_time_from_system())
	}
