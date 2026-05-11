class_name MapAtlasRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MapAtlasCategoryTabsScript := preload("res://scripts/UI/Panels/MapAtlasCategoryTabs.gd")
const MainCityMapDiscoveryScript := preload("res://scripts/main_city/MainCityMapDiscovery.gd")
const MapActivityProgressScript := preload("res://scripts/Systems/Map/MapActivityProgress.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CATEGORY_ORDER := ["main_city", "life_skill", "social_function", "seasonal", "random_exploration"]

var _points_by_map: Dictionary = {}

func render(parent: VBoxContainer, compact: bool, travel_callback: Callable) -> void:
	var records := _available_maps()
	if records.is_empty():
		_add_label(parent, App.t_key("world.map.category.empty"), 11, PanelTextThemeScript.MUTED)
		return
	var point_config: Dictionary = ConfigLoader.load_config("map_points")
	_points_by_map = point_config.get("maps", {}) as Dictionary
	var discovery := MainCityMapDiscoveryScript.new()
	_add_summary(parent, records, discovery, compact)
	_add_progress(parent, compact)
	var categories := _visible_categories(records, discovery)
	var single_column := compact and _screen_width(parent) < 900.0
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8 if compact else 10)
	MapAtlasCategoryTabsScript.new().render(parent, compact, categories, func(category: String) -> void:
		_refresh_categories(content, category, categories, records, compact, travel_callback, discovery, single_column)
	)
	parent.add_child(content)
	_refresh_categories(content, "all", categories, records, compact, travel_callback, discovery, single_column)

func _refresh_categories(
	parent: VBoxContainer,
	active_category: String,
	categories: Array[String],
	records: Array[Dictionary],
	compact: bool,
	travel_callback: Callable,
	discovery: RefCounted,
	single_column: bool
) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var visible: Array[String] = []
	if active_category == "all":
		visible.append_array(categories)
	else:
		visible.append(active_category)
	if single_column or visible.size() == 1:
		for category in visible:
			_add_category_column(parent, category, records, compact, travel_callback, discovery)
		return
	var current_row: HBoxContainer = null
	for index in range(visible.size()):
		if index % 2 == 0:
			current_row = HBoxContainer.new()
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			current_row.add_theme_constant_override("separation", 12)
			parent.add_child(current_row)
		_add_category_column(current_row, visible[index], records, compact, travel_callback, discovery)

func _visible_categories(records: Array[Dictionary], discovery: RefCounted) -> Array[String]:
	var categories: Array[String] = []
	for category in CATEGORY_ORDER:
		var rows := _records_for_category(records, category, discovery)
		if not rows.is_empty():
			categories.append(category)
	return categories

func _screen_width(parent: Control) -> float:
	var browser_width := _browser_inner_width()
	if browser_width > 0.0:
		return browser_width
	return parent.get_viewport_rect().size.x

func _browser_inner_width() -> float:
	if not Engine.has_singleton("JavaScriptBridge"):
		return 0.0
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if bridge == null or not bridge.has_method("eval"):
		return 0.0
	var width_value: Variant = bridge.call("eval", "window.innerWidth", true)
	if typeof(width_value) == TYPE_INT or typeof(width_value) == TYPE_FLOAT:
		return float(width_value)
	return 0.0

func _available_maps() -> Array[Dictionary]:
	var catalog: Dictionary = ConfigLoader.load_config("map_catalog")
	var rows: Array[Dictionary] = []
	for record in catalog.get("maps", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data := record as Dictionary
		if not str(data.get("asset_path", "")).is_empty() and not str(data.get("metadata_path", "")).is_empty():
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
	if bool(discovery.call("can_travel_to", map_id, record)):
		return 1
	if bool(discovery.call("is_discovered", map_id)):
		return 2
	return 3

func _add_summary(parent: VBoxContainer, records: Array[Dictionary], discovery: RefCounted, compact: bool) -> void:
	var discovered_count := 0
	var current_name := ""
	for record in records:
		var map_id := str(record.get("id", ""))
		if bool(discovery.call("is_discovered", map_id)):
			discovered_count += 1
		if map_id == _current_map_id():
			current_name = _display_name(record)
	_add_label(parent, App.format_key("world.panel.map.summary_format", {
		"discovered": discovered_count,
		"total": records.size(),
		"current": current_name
	}), 9 if compact else 11, PanelTextThemeScript.MUTED)

func _add_progress(parent: VBoxContainer, compact: bool) -> void:
	var total_xp := 0
	for value in MapActivityProgressScript.skill_xp().values():
		total_xp += int(value)
	var total_items := 0
	for value in MapActivityProgressScript.inventory().values():
		if typeof(value) == TYPE_DICTIONARY:
			total_items += int((value as Dictionary).get("quantity", 0))
	if total_xp > 0 or total_items > 0:
		_add_label(parent, App.format_key("world.panel.map.progress_format", {
			"xp": total_xp,
			"items": total_items
		}), 9 if compact else 11, PanelTextThemeScript.MUTED)

func _add_category_column(
	parent: Control,
	category: String,
	all_records: Array[Dictionary],
	compact: bool,
	travel_callback: Callable,
	discovery: RefCounted
) -> void:
	var records := _records_for_category(all_records, category, discovery)
	var box := PanelListFrameScript.new().add_section(
		parent,
		compact,
		Vector2(300, 0) if compact else Vector2(420, 0)
	)
	var category_text := App.t_key("world.map.category.%s" % category)
	_add_label(box, App.format_key("world.panel.map.category_format", {
		"category": category_text,
		"count": records.size()
	}), 13 if compact else 14, PanelTextThemeScript.PRIMARY)
	for record in records:
		_add_map_row(box, record, compact, travel_callback, discovery)

func _add_map_row(parent: VBoxContainer, record: Dictionary, compact: bool, travel_callback: Callable, discovery: RefCounted) -> void:
	var map_id := str(record.get("id", ""))
	var current := map_id == _current_map_id()
	var discovered := bool(discovery.call("is_discovered", map_id))
	var travelable := bool(discovery.call("can_travel_to", map_id, record))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4 if compact else 6)
	row.modulate = Color(0.96, 0.92, 0.84, 1.0) if not travelable else Color.WHITE
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28) if compact else Vector2(30, 30)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(_icon_id(record))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 0)
	row.add_child(labels)
	_add_label(labels, _display_name(record), 12 if compact else 13, PanelTextThemeScript.PRIMARY)
	_add_label(labels, _detail(record), 9 if compact else 10, PanelTextThemeScript.MUTED)
	var button := Button.new()
	button.text = _button_text(current, discovered, travelable)
	button.disabled = current or not travelable
	button.custom_minimum_size = Vector2(64, 28) if compact else Vector2(70, 30)
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(func() -> void:
		if travel_callback.is_valid():
			travel_callback.call(map_id)
	)
	row.add_child(button)

func _add_label(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

func _detail(record: Dictionary) -> String:
	var point_record := _point_record(str(record.get("id", "")))
	return App.format_key("world.panel.map.row_detail_format", {
		"category": App.t_key("world.map.category.%s" % str(record.get("category", ""))),
		"status": App.t_key("world.map.status.%s" % str(record.get("status", ""))),
		"routes": _point_count(point_record, "portals"),
		"activities": _point_count(point_record, "life_skill_nodes") + _point_count(point_record, "interaction_points")
	})

func _button_text(current: bool, discovered: bool, travelable: bool) -> String:
	if current:
		return App.t_key("world.panel.map.current_action")
	if not discovered:
		return App.t_key("world.panel.map.undiscovered_action")
	if not travelable:
		return App.t_key("world.panel.map.preview_action")
	return App.t_key("world.panel.map.travel_action")

func _display_name(record: Dictionary) -> String:
	var names: Dictionary = record.get("name", {}) as Dictionary
	var locale := "zh" if App.current_locale.begins_with("zh") else App.current_locale
	return str(names.get(locale, names.get("en", record.get("id", ""))))

func _current_map_id() -> String:
	return str(SaveSystem.get_profile_value("current_world_map_id", "city_forest_dawn_v1"))

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
