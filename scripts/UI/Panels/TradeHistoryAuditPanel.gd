class_name TradeHistoryAuditPanel
extends PanelContainer

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const MAX_ROWS := 6

var compact_layout := false
var _embedded_admin_mode := false
var _built := false
var _token_input: LineEdit
var _status_label: Label
var _refresh_button: Button
var _export_button: Button
var _type_filter: OptionButton
var _player_filter: LineEdit
var _item_filter: LineEdit
var _rows: VBoxContainer
var _snapshot: Dictionary = {}

func _ready() -> void:
	_build()
	_apply_image2_style()

func set_compact_layout(enabled: bool) -> void:
	compact_layout = enabled
	if _rows != null:
		_rows.add_theme_constant_override("separation", 4 if enabled else 6)
	if _refresh_button != null:
		_refresh_button.custom_minimum_size = Vector2(64, 30) if enabled else Vector2(72, 32)
	if _export_button != null:
		_export_button.custom_minimum_size = Vector2(76, 30) if enabled else Vector2(92, 32)

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token

func set_embedded_admin_mode(enabled: bool) -> void:
	_embedded_admin_mode = enabled
	_build()
	if _token_input != null:
		_token_input.visible = not enabled

func set_trade_history_snapshot(snapshot: Dictionary) -> void:
	_build()
	_snapshot = snapshot.duplicate(true)
	_render_rows()

func refresh_trade_history() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("trade_history_audit.console.loading")
	var response: Dictionary = await _online_client().call("fetch_trade_history_audit_admin", token, _filters())
	if bool(response.get("ok", false)):
		set_trade_history_snapshot(response.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
		_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 220)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_add_header(layout)
	_add_filters(layout)
	_add_scroll_rows(layout)

func _add_header(layout: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	_add_icon(header, "icon.coin", Vector2(34, 34))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("trade_history_audit.console.title")
	labels.add_child(title)
	_status_label = Label.new()
	_status_label.text = App.t_key("trade_history_audit.console.empty")
	_status_label.modulate = PanelTextThemeScript.MUTED
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelTextThemeScript.apply_primary([title])
	labels.add_child(_status_label)
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_trade_history)
	header.add_child(_refresh_button)
	_export_button = Button.new()
	_export_button.text = App.t_key("ui.action.export_csv")
	_export_button.custom_minimum_size = Vector2(92, 32)
	_export_button.pressed.connect(export_trade_history)
	header.add_child(_export_button)

func export_trade_history() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_export_button.disabled = true
	_status_label.text = App.t_key("reviewer.console.exporting")
	var response: Dictionary = await _online_client().call("export_trade_history_audit_admin", token, _filters())
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		_status_label.text = App.format_key("reviewer.console.export_ready_format", {"bytes": int(data.get("bytes", 0))})
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
	_export_button.disabled = false

func _add_filters(layout: VBoxContainer) -> void:
	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.visible = not _embedded_admin_mode
	layout.add_child(_token_input)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	layout.add_child(filters)
	_type_filter = OptionButton.new()
	for key in ["all", "sold", "created", "cancelled"]:
		_type_filter.add_item(App.t_key("trade_history_audit.filter.%s" % key))
	_type_filter.custom_minimum_size = Vector2(84, 30)
	filters.add_child(_type_filter)
	_player_filter = _filter_input("trade_history_audit.filter.player")
	filters.add_child(_player_filter)
	_item_filter = _filter_input("trade_history_audit.filter.item")
	filters.add_child(_item_filter)

func _add_scroll_rows(layout: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 118)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

func _render_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var items: Array = _snapshot.get("items", []) as Array
	_status_label.text = App.format_key("trade_history_audit.console.summary_format", {
		"count": int(_snapshot.get("count", items.size())),
		"matched": int(_snapshot.get("matched", items.size()))
	})
	if items.is_empty():
		_add_label(PanelListFrameScript.new().add_hbox(_rows, compact_layout), App.t_key("trade_history_audit.console.empty"), true)
		_refresh_button.disabled = false
		return
	for item in items.slice(0, MAX_ROWS):
		if typeof(item) == TYPE_DICTIONARY:
			_add_history_row(item as Dictionary)
	_refresh_button.disabled = false

func _add_history_row(item: Dictionary) -> void:
	var row := PanelListFrameScript.new().add_hbox(_rows, compact_layout)
	_add_icon(row, str(item.get("icon_id", "icon.coin")), Vector2(26, 26))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	_add_label(labels, App.format_key("trade_history_audit.console.row_title_format", {
		"price": int(item.get("price", 0)),
		"type": str(item.get("type", "-"))
	}), false)
	_add_label(labels, App.format_key("trade_history_audit.console.row_detail_format", {
		"buyer": _dash(str(item.get("buyer_id", ""))),
		"item": str(item.get("item_id", "-")),
		"listing": str(item.get("listing_id", "-")),
		"seller": str(item.get("seller_id", "-"))
	}), true)

func _filters() -> Dictionary:
	var type_values := ["", "sold", "created", "cancelled"]
	return {
		"limit": 25,
		"type": type_values[_type_filter.selected],
		"player_id": _player_filter.text.strip_edges(),
		"item_id": _item_filter.text.strip_edges()
	}

func _filter_input(key: String) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = App.t_key(key)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(80, 30)
	return input

func _add_label(parent: Control, text: String, wrap: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = PanelTextThemeScript.MUTED if wrap else PanelTextThemeScript.PRIMARY
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _add_icon(parent: Control, icon_id: String, size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)

func _dash(value: String) -> String:
	return "-" if value.is_empty() else value

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	for control in [_refresh_button, _export_button, _type_filter, _token_input, _player_filter, _item_filter]:
		if control is Button:
			WorldHUDAssetsScript.configure_button_frame(control)
		elif control is LineEdit:
			WorldHUDAssetsScript.configure_line_edit_frame(control)

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
