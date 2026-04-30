class_name EmoteCatalog
extends RefCounted

const CONFIG_PATH := "res://configs/ui_assets.json"
const EMOTES_PATH := "res://configs/emotes.json"

static func load_texture(emote_id: String) -> Texture2D:
	var asset_path := get_asset_path(emote_id)
	if asset_path.is_empty():
		push_warning("Missing emote asset id: %s" % emote_id)
		return null

	var resource := ResourceLoader.load(asset_path)
	if resource is Texture2D:
		return resource as Texture2D
	if resource == null:
		push_warning("Unable to load emote asset: %s" % emote_id)
	else:
		push_warning("Emote asset is not a texture: %s" % emote_id)

	return null

static func get_asset_path(emote_id: String) -> String:
	var config: Dictionary = _load_config()
	for asset in config.get("assets", []):
		if typeof(asset) != TYPE_DICTIONARY:
			continue
		if str(asset.get("id", "")) == emote_id:
			return str(asset.get("path", ""))
	return ""

static func get_starter_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for entry in get_palette_entries():
		if typeof(entry) == TYPE_DICTIONARY:
			ids.append(str(entry.get("id", "")))
	return ids

static func get_palette_entries() -> Array:
	var data: Dictionary = _load_json(EMOTES_PATH)
	var emotes: Variant = data.get("emotes", [])
	if typeof(emotes) == TYPE_ARRAY:
		return emotes as Array

	return []

static func _load_config() -> Dictionary:
	return _load_json(CONFIG_PATH)

static func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Missing emote config: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Emote config is not a JSON object: %s" % path)
		return {}

	return parsed as Dictionary
