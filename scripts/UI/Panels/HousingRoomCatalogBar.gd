class_name HousingRoomCatalogBar
extends PanelContainer

signal item_pressed(item_id: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var housing_service: Node
var art: RefCounted
var is_visit_mode := false
var _compact_layout := false
var status_label: Label
var catalog_scroll: ScrollContainer
var catalog_row: HBoxContainer

func _ready() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
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
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	WorldHUDAssetsScript.add_margin_child(self, rows, Vector4(12, 8, 12, 8))

	status_label = Label.new()
	status_label.name = "StatusLabel"
	rows.add_child(status_label)

	catalog_scroll = ScrollContainer.new()
	catalog_scroll.name = "CatalogScroll"
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_scroll.custom_minimum_size = Vector2(0, 54)
	rows.add_child(catalog_scroll)

	catalog_row = HBoxContainer.new()
	catalog_row.name = "CatalogRow"
	catalog_row.add_theme_constant_override("separation", 8)
	catalog_scroll.add_child(catalog_row)

func set_compact_layout(enabled: bool) -> void:
	if _compact_layout == enabled:
		return
	_compact_layout = enabled
	if catalog_scroll != null:
		catalog_scroll.custom_minimum_size = Vector2(0, 42) if _compact_layout else Vector2(0, 54)
	if status_label != null:
		status_label.custom_minimum_size = Vector2(0, 18) if _compact_layout else Vector2.ZERO
	_apply_button_layout()

func _rebuild_catalog() -> void:
	if catalog_row == null:
		return
	for child in catalog_row.get_children():
		child.queue_free()
	if is_visit_mode or housing_service == null:
		return
	for item in housing_service.get_catalog():
		_add_catalog_button(item)

func _add_catalog_button(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var button := Button.new()
	button.custom_minimum_size = _button_size()
	button.text = "%s %d" % [App.t_key(str(item.get("name_key", ""))), int(item.get("price", 0))]
	button.tooltip_text = App.t_key(str(item.get("description_key", "")))
	if art != null:
		button.icon = art.item_texture(item)
	button.expand_icon = button.icon != null
	button.pressed.connect(func() -> void: item_pressed.emit(item_id))
	WorldHUDAssetsScript.configure_button_frame(button)
	catalog_row.add_child(button)

func _apply_button_layout() -> void:
	if catalog_row == null:
		return
	for child in catalog_row.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = _button_size()

func _button_size() -> Vector2:
	return Vector2(118, 34) if _compact_layout else Vector2(148, 44)
