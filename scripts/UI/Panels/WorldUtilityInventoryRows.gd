class_name WorldUtilityInventoryRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MapActivityInventoryRowsScript := preload("res://scripts/UI/Panels/MapActivityInventoryRows.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

func render(parent: VBoxContainer, compact: bool, online_items: Array, online_loaded: bool) -> void:
	if online_loaded:
		_render_online_rows(parent, compact, online_items)
	_render_local_rows(parent, compact)
	MapActivityInventoryRowsScript.new().render(parent, compact, not online_loaded)

func _render_online_rows(parent: VBoxContainer, compact: bool, online_items: Array) -> void:
	var items := _sorted_online_items(online_items)
	if items.is_empty():
		return
	_add_category(parent, _t("world.panel.inventory.online_items"))
	var housing_config := _load_config("housing_items")
	for item in items:
		var item_id := str(item.get("item_id", ""))
		var title := _item_title(housing_config, item_id)
		_add_row(
			parent,
			_item_texture(housing_config, item_id),
			title,
			_format("world.panel.inventory.online_state_format", {
				"owned": int(item.get("owned", 0)),
				"available": int(item.get("available", 0)),
				"locked": int(item.get("locked", 0))
			}),
			compact
		)

func _render_local_rows(parent: VBoxContainer, compact: bool) -> void:
	var counts := _local_inventory_counts()
	var ids := counts.keys()
	ids.sort()
	if ids.is_empty():
		return
	_add_category(parent, _t("world.panel.inventory.local_items"))
	var housing_config := _load_config("housing_items")
	for item_id in ids.slice(0, 8):
		var item := _housing_item(housing_config, str(item_id))
		if item.is_empty():
			continue
		var title := _t(str(item.get("name_key", "")))
		if int(counts[item_id]) > 1:
			title = _format("world.panel.item_count_format", {
				"item": title,
				"count": int(counts[item_id])
			})
		_add_row(
			parent,
			_load_texture_path(str(item.get("icon_path", ""))),
			title,
			_t(str(item.get("description_key", ""))),
			compact
		)

func _sorted_online_items(online_items: Array) -> Array:
	var items := []
	for raw in online_items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item := (raw as Dictionary).duplicate(true)
		if str(item.get("item_id", "")).is_empty():
			continue
		if int(item.get("owned", 0)) <= 0 and int(item.get("locked", 0)) <= 0:
			continue
		items.append(item)
	items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("item_id", "")) < str(right.get("item_id", ""))
	)
	return items

func _local_inventory_counts() -> Dictionary:
	var counts := {}
	var save_system := _save_system()
	if save_system == null:
		return counts
	for item_id in save_system.call("get_profile_value", "owned_items", []):
		_increment_count(counts, str(item_id))
	for placed in save_system.call("get_profile_value", "house_items", []):
		if typeof(placed) == TYPE_DICTIONARY:
			_increment_count(counts, str((placed as Dictionary).get("item_id", "")))
	return counts

func _increment_count(counts: Dictionary, item_id: String) -> void:
	if item_id.is_empty():
		return
	counts[item_id] = int(counts.get(item_id, 0)) + 1

func _item_title(housing_config: Dictionary, item_id: String) -> String:
	var item := _housing_item(housing_config, item_id)
	if not item.is_empty():
		return _t(str(item.get("name_key", "")))
	return _translated_or_title("map_activity.item.%s" % item_id, item_id)

func _item_texture(housing_config: Dictionary, item_id: String) -> Texture2D:
	var item := _housing_item(housing_config, item_id)
	if not item.is_empty():
		return _load_texture_path(str(item.get("icon_path", "")))
	return WorldHUDAssetsScript.load_ui_texture("icon.backpack")

func _housing_item(config: Dictionary, item_id: String) -> Dictionary:
	for item in config.get("items", []):
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("id", "")) == item_id:
			return item as Dictionary
	return {}

func _load_texture_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func _load_config(config_id: String) -> Dictionary:
	var config_loader := _autoload("ConfigLoader")
	if config_loader == null:
		return {}
	return config_loader.call("load_config", config_id) as Dictionary

func _t(key: String) -> String:
	if key.is_empty():
		return ""
	var app := _autoload("App")
	if app != null:
		return str(app.call("t_key", key))
	return key

func _format(key: String, values: Dictionary) -> String:
	var app := _autoload("App")
	if app != null:
		return str(app.call("format_key", key, values))
	return key

func _translated_or_title(key: String, fallback_id: String) -> String:
	var text := _t(key)
	if text != key:
		return text
	return fallback_id.replace("_", " ").capitalize()

func _save_system() -> Node:
	return _autoload("SaveSystem")

func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(node_name)

func _add_category(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = PanelTextThemeScript.PRIMARY
	parent.add_child(label)

func _add_row(parent: VBoxContainer, texture: Texture2D, title: String, detail: String, compact: bool) -> void:
	var row := PanelListFrameScript.new().add_hbox(parent, compact)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24) if compact else Vector2(28, 28)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	_add_label(labels, title, 11 if compact else 13, PanelTextThemeScript.PRIMARY)
	_add_label(labels, detail, 8 if compact else 10, PanelTextThemeScript.MUTED)

func _add_label(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	parent.add_child(label)
