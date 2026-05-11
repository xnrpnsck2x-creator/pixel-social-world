class_name MapActivityInventoryRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const INVENTORY_KEY := "map_activity_inventory"
const SKILL_XP_KEY := "map_activity_skill_xp"

func render(parent: VBoxContainer, compact: bool, include_drops: bool = true) -> void:
	_render_skill_rows(parent, compact)
	if include_drops:
		_render_drop_rows(parent, compact)

func _render_skill_rows(parent: VBoxContainer, compact: bool) -> void:
	var skills := _profile_dictionary(SKILL_XP_KEY)
	var ids := skills.keys()
	ids.sort()
	if ids.is_empty():
		return
	_add_category(parent, _t("world.panel.inventory.activity_skills"))
	for skill_id in ids:
		var xp := int(skills[skill_id])
		if xp <= 0:
			continue
		_add_row(
			parent,
			WorldHUDAssetsScript.load_ui_texture("icon.quest"),
			_format("world.panel.inventory.skill_row_format", {
				"skill": _translated_or_title("map_activity.skill.%s" % str(skill_id), str(skill_id)),
				"xp": xp
			}),
			_t("world.panel.inventory.skill_detail"),
			compact
		)

func _render_drop_rows(parent: VBoxContainer, compact: bool) -> void:
	var inventory := _profile_dictionary(INVENTORY_KEY)
	var ids := inventory.keys()
	ids.sort()
	if ids.is_empty():
		return
	_add_category(parent, _t("world.panel.inventory.activity_drops"))
	for item_id in ids:
		var record: Dictionary = inventory[item_id] as Dictionary
		var quantity := int(record.get("quantity", 0))
		if quantity <= 0:
			continue
		var rarity := str(record.get("rarity", "common"))
		_add_row(
			parent,
			WorldHUDAssetsScript.load_ui_texture("icon.backpack"),
			_format("world.panel.inventory.drop_row_format", {
				"item": _translated_or_title("map_activity.item.%s" % str(item_id), str(item_id)),
				"count": quantity
			}),
			_format("world.panel.inventory.drop_detail_format", {
				"rarity": _translated_or_title("map_activity.rarity.%s" % rarity, rarity)
			}),
			compact
		)

func _add_category(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = PanelTextThemeScript.PRIMARY
	parent.add_child(label)

func _add_row(parent: VBoxContainer, texture: Texture2D, title: String, detail: String, compact: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6 if compact else 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
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

func _autoload(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(node_name)

func _profile_dictionary(key: String) -> Dictionary:
	var save_system := _autoload("SaveSystem")
	if save_system == null:
		return {}
	var value: Variant = save_system.call("get_profile_value", key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}
