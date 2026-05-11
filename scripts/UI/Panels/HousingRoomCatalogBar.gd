class_name HousingRoomCatalogBar
extends PanelContainer

signal item_pressed(item_id: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var housing_service: Node
var art: RefCounted
var is_visit_mode := false
var _compact_layout := false
var margin_container: MarginContainer
var rows_container: VBoxContainer
var status_label: Label
var catalog_scroll: ScrollContainer
var catalog_row: HBoxContainer

func _ready() -> void:
	WorldHUDAssetsScript.configure_hud_strip_frame(self)
	_build_ui()

func bind_catalog(new_service: Node, new_art: RefCounted, read_only: bool) -> void:
	housing_service = new_service
	art = new_art
	is_visit_mode = read_only
	if status_label != null:
		status_label.text = App.t_key("housing.visit_read_only" if is_visit_mode else "housing.catalog_hint")
	_rebuild_catalog()

func set_status_key(key: String) -> void:
	if status_label != null:
		status_label.text = App.t_key(key)

func set_status_text(text: String) -> void:
	if status_label != null:
		status_label.text = text

func set_selected_item(item: Dictionary) -> void:
	if status_label == null:
		return
	status_label.text = App.format_key("housing.selected_format", {
		"item": App.t_key(str(item.get("name_key", "")))
	})

func select_first_placeable() -> void:
	if is_visit_mode or housing_service == null:
		return
	for item in housing_service.get_catalog():
		if str(item.get("item_type", "")) != "surface":
			item_pressed.emit(str(item.get("id", "")))
			return

func _build_ui() -> void:
	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 6)
	margin_container = WorldHUDAssetsScript.add_margin_child(self, rows_container, Vector4(34, 8, 34, 8))

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.modulate = PanelTextThemeScript.PRIMARY
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_font_size_override("font_size", 12)
	rows_container.add_child(status_label)

	catalog_scroll = ScrollContainer.new()
	catalog_scroll.name = "CatalogScroll"
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_scroll.set("follow_focus", false)
	catalog_scroll.custom_minimum_size = Vector2(0, 54)
	rows_container.add_child(catalog_scroll)

	catalog_row = HBoxContainer.new()
	catalog_row.name = "CatalogRow"
	catalog_row.add_theme_constant_override("separation", 8)
	catalog_scroll.add_child(catalog_row)

func set_compact_layout(enabled: bool) -> void:
	if _compact_layout == enabled:
		return
	_compact_layout = enabled
	_apply_spacing()
	if catalog_scroll != null:
		catalog_scroll.custom_minimum_size = Vector2(0, 34) if _compact_layout else Vector2(0, 54)
		catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _compact_layout else ScrollContainer.SCROLL_MODE_AUTO
		call_deferred("_reset_catalog_scroll")
	if status_label != null:
		status_label.custom_minimum_size = Vector2(0, 12) if _compact_layout else Vector2.ZERO
		status_label.add_theme_font_size_override("font_size", 9 if _compact_layout else 12)
	_apply_button_layout()

func _apply_spacing() -> void:
	if rows_container != null:
		rows_container.add_theme_constant_override("separation", 2 if _compact_layout else 6)
	if catalog_row != null:
		catalog_row.add_theme_constant_override("separation", 4 if _compact_layout else 8)
	if margin_container == null:
		return
	var margin := Vector4(18, 4, 18, 4) if _compact_layout else Vector4(34, 8, 34, 8)
	margin_container.add_theme_constant_override("margin_left", int(margin.x))
	margin_container.add_theme_constant_override("margin_top", int(margin.y))
	margin_container.add_theme_constant_override("margin_right", int(margin.z))
	margin_container.add_theme_constant_override("margin_bottom", int(margin.w))

func _rebuild_catalog() -> void:
	if catalog_row == null:
		return
	for child in catalog_row.get_children():
		child.queue_free()
	if is_visit_mode or housing_service == null:
		return
	for item in housing_service.get_catalog():
		_add_catalog_button(item)
	call_deferred("_reset_catalog_scroll")

func _add_catalog_button(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var button := Button.new()
	button.custom_minimum_size = _button_size()
	button.text = "%s %d" % [App.t_key(str(item.get("name_key", ""))), int(item.get("price", 0))]
	button.set_meta("catalog_full_text", button.text)
	button.set_meta("catalog_compact_text", _compact_button_text(item))
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.tooltip_text = App.t_key(str(item.get("description_key", "")))
	if art != null:
		button.icon = art.item_texture(item)
	_apply_button_content(button)
	button.pressed.connect(func() -> void:
		item_pressed.emit(item_id)
		if _compact_layout:
			call_deferred("_reset_catalog_scroll")
	)
	WorldHUDAssetsScript.configure_button_frame(button)
	catalog_row.add_child(button)

func _apply_button_layout() -> void:
	if catalog_row == null:
		return
	for child in catalog_row.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size = _button_size()
			_apply_button_content(button)

func _button_size() -> Vector2:
	return Vector2(100, 28) if _compact_layout else Vector2(132, 40)

func _compact_button_text(item: Dictionary) -> String:
	return "%s %d" % [App.t_key("housing.item.%s.compact_name" % str(item.get("id", ""))), int(item.get("price", 0))]

func _reset_catalog_scroll() -> void:
	if catalog_scroll != null:
		catalog_scroll.scroll_horizontal = 0

func _apply_button_content(button: Button) -> void:
	if button.icon != null and not button.has_meta("catalog_icon"):
		button.set_meta("catalog_icon", button.icon)
	if _compact_layout:
		button.icon = null
		button.expand_icon = false
		button.text = str(button.get_meta("catalog_compact_text", button.text))
		button.add_theme_font_size_override("font_size", 9)
		return
	button.text = str(button.get_meta("catalog_full_text", button.text))
	var original_icon := button.get_meta("catalog_icon", null) as Texture2D
	if original_icon != null:
		button.icon = original_icon
	button.expand_icon = button.icon != null
	button.remove_theme_font_size_override("font_size")
