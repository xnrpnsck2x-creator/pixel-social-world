extends Node

const CONFIG_ROOT := "res://configs/"

var _cache: Dictionary = {}

func load_config(config_name: String) -> Dictionary:
	if _cache.has(config_name):
		return _cache[config_name].duplicate(true)

	var path: String = CONFIG_ROOT + config_name + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing config file: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Config file is not a JSON object: %s" % path)
		return {}

	var data: Dictionary = parsed as Dictionary
	_cache[config_name] = data
	return data.duplicate(true)

func get_value(config_name: String, key_path: Array, fallback: Variant = null) -> Variant:
	var cursor: Variant = load_config(config_name)
	for key in key_path:
		if typeof(cursor) != TYPE_DICTIONARY or not cursor.has(key):
			return fallback
		cursor = cursor[key]
	return cursor

func clear_cache() -> void:
	_cache.clear()
