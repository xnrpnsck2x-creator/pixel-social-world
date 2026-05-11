class_name MainCityMapUnlocker
extends RefCounted

const SOURCE_ARRIVAL := "arrival"
const SOURCE_NPC := "npc"

var map_runtime

func bind(new_map_runtime) -> void:
	map_runtime = new_map_runtime

func sync_from_backend() -> void:
	if map_runtime == null:
		return
	await map_runtime.discovery.sync_from_backend()

func unlock_map(map_id: String, source: String = SOURCE_ARRIVAL) -> Dictionary:
	if map_runtime == null or map_id.is_empty():
		return {"unlocked": false, "map_id": map_id, "source": source}
	var unlocked := bool(map_runtime.unlock_map(map_id, source))
	await map_runtime.discovery.push_remote(map_id, source)
	return {"unlocked": unlocked, "map_id": map_id, "source": source}
