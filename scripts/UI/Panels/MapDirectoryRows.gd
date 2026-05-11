class_name MapDirectoryRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MainCityMapDiscoveryScript := preload("res://scripts/main_city/MainCityMapDiscovery.gd")
const MapActivityProgressScript := preload("res://scripts/Systems/Map/MapActivityProgress.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CURRENT_COLOR := Color(0.12, 0.38, 0.28, 1.0)
const UNLOCKED_COLOR := Color(0.52, 0.32, 0.06, 1.0)
const LOCKED_COLOR := Color(0.48, 0.38, 0.30, 1.0)
const CATEGORY_ORDER := ["main_city", "life_skill", "social_function", "seasonal", "random_exploration"]

var _points_by_map: Dictionary = {}

func render(parent: VBoxContainer, compact: bool, travel_callback: Callable, atlas_callback: Callable = Callable()) -> void:
	var records := _available_maps()
	if records.is_empty():
		_add_empty_row(parent)
		return
	var discovery := MainCityMapDiscoveryScript.new()
	var point_config: Dictionary = ConfigLoader.load_config("map_points")
	_points_by_map = point_config.get("maps", {}) as Dictionary
	_add_collection_summary(parent, records, discovery, compact)
	if atlas_callback.is_valid():
		_add_atlas_button(parent, compact, atlas_callback)
	_add_progress_summary(parent, compact)
	for category in CATEGORY_ORDER:
		var category_records := _records_for_category(records, category, discovery)
		if category_records.is_empty():
			continue
		_add_category_label(parent, category, category_records.size())
		for record in category_records:
			_add_map_row(parent, record, compact, travel_callback, discovery)

func _available_maps() -> Array[Dictionary]:
	var catalog: Dictionary = ConfigLoader.load_config("map_catalog")
	var rows: Array[Dictionary] = []
	for record in catalog.get("maps", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data := record as Dictionary
		if str(data.get("asset_path", "")).is_empty() or str(data.get("metadata_path", "")).is_empty():
			continue
		rows.append(data)
	return rows

func _records_for_category(records: Array[Dictionary], category: String, discovery: RefCounted) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record in records:
		if str(record.get("category", "")) == category:
			rows.append(record)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a := _row_rank(a, discovery)
		var rank_b := _row_rank(b, discovery)
		if rank_a != rank_b:
			return rank_a < rank_b
		return _display_name(a) < _display_name(b)
	)
	return rows

func _row_rank(record: Dictionary, discovery: RefCounted) -> int:
	var map_id := str(record.get("id", ""))
	if map_id == _current_map_id():
		return 0
	if discovery.call("can_travel_to", map_id, record):
		return 1
	if discovery.call("is_discovered", map_id):
		return 2
	if str(record.get("status", "")) == "route_exposed":
		return 3
	return 4

func _add_category_label(parent: VBoxContainer, category: String, count: int = -1) -> void:
	var label := Label.new()
	var category_text := App.t_key("world.map.category.%s" % category)
	label.text = category_text if count < 0 else App.format_key("world.panel.map.category_format", {
		"category": category_text,
		"count": count
	})
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = PanelTextThemeScript.PRIMARY
	parent.add_child(label)

func _add_collection_summary(parent: VBoxContainer, records: Array[Dictionary], discovery: RefCounted, compact: bool) -> void:
	var discovered_count := 0
	var current_name := ""
	var current_id := _current_map_id()
	for record in records:
		var map_id := str(record.get("id", ""))
		if discovery.call("is_discovered", map_id):
			discovered_count += 1
		if map_id == current_id:
			current_name = _display_name(record)
	var label := Label.new()
	label.text = App.format_key("world.panel.map.summary_format", {
		"discovered": discovered_count,
		"total": records.size(),
		"current": current_name
	})
	label.add_theme_font_size_override("font_size", 9 if compact else 11)
	label.modulate = PanelTextThemeScript.MUTED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _add_atlas_button(parent: VBoxContainer, compact: bool, atlas_callback: Callable) -> void:
	var button := Button.new()
	button.text = App.t_key("world.panel.map.open_atlas_action")
	button.tooltip_text = App.t_key("world.panel.map.open_atlas_tooltip")
	button.custom_minimum_size = Vector2(0, 24) if compact else Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(func() -> void:
		atlas_callback.call()
	)
	parent.add_child(button)

func _add_progress_summary(parent: VBoxContainer, compact: bool) -> void:
	var total_xp := 0
	for value in MapActivityProgressScript.skill_xp().values():
		total_xp += int(value)
	var total_items := 0
	for value in MapActivityProgressScript.inventory().values():
		if typeof(value) == TYPE_DICTIONARY:
			total_items += int((value as Dictionary).get("quantity", 0))
	if total_xp <= 0 and total_items <= 0:
		return
	var label := Label.new()
	label.text = App.format_key("world.panel.map.progress_format", {
		"xp": total_xp,
		"items": total_items
	})
	label.add_theme_font_size_override("font_size", 9 if compact else 11)
	label.modulate = PanelTextThemeScript.MUTED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _add_map_row(parent: VBoxContainer, record: Dictionary, compact: bool, travel_callback: Callable, discovery: RefCounted) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5 if compact else 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var map_id := str(record.get("id", ""))
	var current := map_id == _current_map_id()
	var discovered := bool(discovery.call("is_discovered", map_id))
	var travelable := bool(discovery.call("can_travel_to", map_id, record))
	if not travelable:
		row.modulate = Color(0.96, 0.92, 0.84, 1.0)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22) if compact else Vector2(28, 28)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(_icon_id(record))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 0)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.custom_minimum_size = Vector2(112, 0) if compact else Vector2(160, 0)
	row.add_child(labels)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	labels.add_child(title_row)
	var title := _add_label(title_row, _display_name(record), 12 if compact else 14, PanelTextThemeScript.PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_state_label(title_row, _state_id(current, discovered, travelable), compact)
	var point_record := _point_record(map_id)
	_add_label(labels, _detail(record, point_record), 8 if compact else 10, PanelTextThemeScript.MUTED)
	if discovered:
		_add_label(labels, _entry_hint(record), 8 if compact else 9, PanelTextThemeScript.MUTED)
	else:
		_add_label(labels, _unlock_hint(record), 8 if compact else 9, PanelTextThemeScript.MUTED)
	var button := Button.new()
	button.text = _button_text(current, discovered, travelable)
	button.disabled = current or not travelable
	button.custom_minimum_size = Vector2(52, 26) if compact else Vector2(64, 28)
	WorldHUDAssetsScript.configure_button_frame(button)
	var target_map_id := map_id
	button.pressed.connect(func() -> void:
		if travel_callback.is_valid():
			travel_callback.call(target_map_id)
	)
	row.add_child(button)

func _add_state_label(parent: Control, state_id: String, compact: bool) -> void:
	var label := Label.new()
	label.text = App.t_key("world.panel.map.state.%s" % state_id)
	label.custom_minimum_size = Vector2(32, 14) if compact else Vector2(42, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 7 if compact else 8)
	label.modulate = _state_color(state_id)
	parent.add_child(label)

func _state_id(current: bool, discovered: bool, travelable: bool) -> String:
	if current:
		return "current"
	if travelable:
		return "unlocked"
	if discovered:
		return "preview"
	return "locked"

func _state_color(state_id: String) -> Color:
	match state_id:
		"current":
			return CURRENT_COLOR
		"unlocked":
			return UNLOCKED_COLOR
		"preview":
			return PanelTextThemeScript.MUTED
	return LOCKED_COLOR

func _button_text(current: bool, discovered: bool, travelable: bool) -> String:
	if current:
		return App.t_key("world.panel.map.current_action")
	if not discovered:
		return App.t_key("world.panel.map.undiscovered_action")
	if not travelable:
		return App.t_key("world.panel.map.preview_action")
	return App.t_key("world.panel.map.travel_action")

func _add_empty_row(parent: VBoxContainer) -> void:
	_add_category_label(parent, "empty")

func _add_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, font_size + 4)
	label.modulate = color
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _display_name(record: Dictionary) -> String:
	var names: Dictionary = record.get("name", {}) as Dictionary
	var locale := "zh" if App.current_locale.begins_with("zh") else App.current_locale
	return str(names.get(locale, names.get("en", record.get("id", ""))))

func _current_map_id() -> String:
	return str(SaveSystem.get_profile_value("current_world_map_id", "city_forest_dawn_v1"))

func _detail(record: Dictionary, point_record: Dictionary) -> String:
	return App.format_key("world.panel.map.row_detail_format", {
		"category": App.t_key("world.map.category.%s" % str(record.get("category", ""))),
		"status": App.t_key("world.map.status.%s" % str(record.get("status", ""))),
		"routes": _point_count(point_record, "portals"),
		"activities": _point_count(point_record, "life_skill_nodes") + _point_count(point_record, "interaction_points")
	})

func _entry_hint(record: Dictionary) -> String:
	var key := str(record.get("unlock_hint_key", "world.map.unlock.generic"))
	return App.format_key("world.panel.map.entry_hint_format", {
		"hint": App.t_key(key)
	})

func _unlock_hint(record: Dictionary) -> String:
	var key := str(record.get("unlock_hint_key", "world.map.unlock.generic"))
	return App.format_key("world.panel.map.unlock_hint_format", {
		"hint": App.t_key(key)
	})

func _point_record(map_id: String) -> Dictionary:
	if _points_by_map.has(map_id) and typeof(_points_by_map[map_id]) == TYPE_DICTIONARY:
		return _points_by_map[map_id] as Dictionary
	return {}

func _point_count(point_record: Dictionary, key: String) -> int:
	var value: Variant = point_record.get(key, [])
	return (value as Array).size() if typeof(value) == TYPE_ARRAY else 0

func _icon_id(record: Dictionary) -> String:
	match str(record.get("category", "")):
		"life_skill":
			return "icon.fishing"
		"social_function":
			return "icon.friends"
		"main_city":
			return "icon.map"
	return "icon.quest"
