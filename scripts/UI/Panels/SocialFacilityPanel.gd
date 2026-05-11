class_name SocialFacilityPanel
extends PanelContainer
signal text_input_added(input: LineEdit)
const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const TradeActions := preload("res://scripts/UI/Panels/SocialFacilityTradeActions.gd")
const TradeFeedback := preload("res://scripts/UI/Panels/SocialFacilityTradeFeedback.gd")
const TradeToolbarScript := preload("res://scripts/UI/Panels/SocialFacilityTradeToolbar.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var active_facility_id := ""
var _compact_layout := false
var _facility_service: Node
var _trade_toolbar: HBoxContainer
var _pending_trade_actions := {}
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var body_label: Label = %BodyLabel
@onready var detail_label: Label = %DetailLabel
@onready var rows_scroll: ScrollContainer = %RowsScroll
@onready var rows: VBoxContainer = %RowsList
func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_panel)
	App.locale_changed.connect(_on_locale_changed)
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_button_frame(close_button)
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	close_button.expand_icon = true
	close_button.custom_minimum_size = Vector2(38, 38)
	PanelTextThemeScript.apply_primary([title_label])
	PanelTextThemeScript.apply_muted([body_label, detail_label])
	_add_trade_toolbar()
	set_compact_layout(_compact_layout)

func bind_service(facility_service: Node) -> void:
	_facility_service = facility_service
	if _facility_service != null and _facility_service.has_signal("facilities_updated"):
		var callback := Callable(self, "_on_facilities_updated")
		if not _facility_service.is_connected("facilities_updated", callback):
			_facility_service.connect("facilities_updated", callback)
	if visible:
		_refresh()

func show_facility(facility_id: String) -> void:
	active_facility_id = facility_id
	visible = true
	_refresh()
	if facility_id == "trade":
		call_deferred("_request_trade_refresh")

func hide_panel() -> void: visible = false

func set_compact_layout(enabled: bool) -> void:
	_compact_layout = enabled
	custom_minimum_size = Vector2(278, 176) if enabled else Vector2(316, 198)
	icon_rect.custom_minimum_size = Vector2(24, 24) if enabled else Vector2(34, 34)
	close_button.custom_minimum_size = Vector2(30, 30) if enabled else Vector2(38, 38)
	var margin := $Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 7 if enabled else 10)
	margin.add_theme_constant_override("margin_top", 5 if enabled else 8)
	margin.add_theme_constant_override("margin_right", 7 if enabled else 10)
	margin.add_theme_constant_override("margin_bottom", 5 if enabled else 8)
	($Margin/Rows as VBoxContainer).add_theme_constant_override("separation", 3 if enabled else 6)
	($Margin/Rows/HeaderRow as HBoxContainer).add_theme_constant_override("separation", 4 if enabled else 6)
	rows.add_theme_constant_override("separation", 3 if enabled else 5)
	body_label.custom_minimum_size = Vector2(0, 14) if enabled else Vector2(0, 34)
	body_label.max_lines_visible = 1 if enabled else -1
	detail_label.max_lines_visible = 1 if enabled else -1
	rows_scroll.custom_minimum_size = Vector2(0, 148) if enabled else Vector2(0, 108)
	if _trade_toolbar != null:
		_trade_toolbar.set_compact_layout(enabled)
	if visible:
		_refresh()

func _refresh() -> void:
	var record := _facility_record()
	close_button.text = ""
	close_button.tooltip_text = App.t_key("ui.action.close")
	title_label.text = App.t_key(str(record.get("title_key", "facility.unknown.title")))
	body_label.text = App.t_key(str(record.get("body_key", "facility.unknown.body")))
	body_label.visible = not _compact_layout or active_facility_id != "trade"
	detail_label.text = App.t_key(str(record.get("detail_key", "facility.unknown.detail")))
	icon_rect.texture = WorldHUDAssetsScript.load_ui_texture(str(record.get("icon_id", "icon.quest")))
	if _trade_toolbar != null:
		_trade_toolbar.visible = active_facility_id == "trade"
		_trade_toolbar.call("refresh_text")
	var row_records: Array = record.get("rows", []) as Array
	if active_facility_id == "trade" and _trade_toolbar != null:
		row_records = _trade_toolbar.call("filter_rows", row_records) as Array
	_render_rows(row_records)

func _render_rows(row_records: Array) -> void:
	for child in rows.get_children():
		child.queue_free()
	for row_record in row_records:
		if typeof(row_record) == TYPE_DICTIONARY:
			_add_row(row_record as Dictionary)
	if rows.get_child_count() == 0:
		_add_empty_row()

func _add_row(record: Dictionary) -> void:
	var row := PanelListFrameScript.new().add_vbox(rows, _compact_layout)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4 if _compact_layout else 8)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(top_row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20) if _compact_layout else Vector2(30, 30)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(str(record.get("icon_id", "icon.quest")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 0)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.custom_minimum_size = Vector2(64, 0) if _compact_layout else Vector2(132, 0)
	top_row.add_child(labels)
	_add_label(labels, App.t_key(str(record.get("title_key", ""))), 10 if _compact_layout else 14)
	var has_action := bool(record.get("price_input", false)) or typeof(record.get("action")) == TYPE_DICTIONARY
	_add_label(labels, _row_body_text(record, has_action), 7 if _compact_layout else 11)
	if not has_action:
		var state := Label.new()
		state.text = _state_text(record)
		state.custom_minimum_size = Vector2(58, 20) if _compact_layout else Vector2(88, 28)
		state.modulate = PanelTextThemeScript.PRIMARY
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.clip_text = true
		state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top_row.add_child(state)
	var price_input: LineEdit = null
	var action_row := _action_row_for(row, record, top_row)
	if bool(record.get("price_input", false)):
		price_input = _add_price_input(action_row, int(record.get("price_default", 7)))
	if typeof(record.get("action")) == TYPE_DICTIONARY:
		var button := Button.new()
		button.text = App.t_key(str(record.get("action_key", "facility.action.open")))
		button.custom_minimum_size = Vector2(40, 22) if _compact_layout else Vector2(70, 30)
		WorldHUDAssetsScript.configure_button_frame(button)
		button.disabled = bool(record.get("disabled", false))
		button.pressed.connect(Callable(self, "_on_action_pressed").bind(record.get("action") as Dictionary, button, price_input))
		if price_input != null:
			price_input.text_submitted.connect(func(_text: String) -> void: button.pressed.emit())
		action_row.add_child(button)

func _add_empty_row() -> void:
	_add_row({
		"title_key": "facility.empty.title",
		"body_key": "facility.empty.body",
		"state_key": "facility.state.local",
		"icon_id": "icon.quest"
	})

func _add_trade_toolbar() -> void:
	_trade_toolbar = TradeToolbarScript.new()
	_trade_toolbar.visible = false
	_trade_toolbar.filter_changed.connect(func(_filter_id: String) -> void:
		_refresh()
		call_deferred("_reset_rows_scroll")
	)
	_trade_toolbar.refresh_requested.connect(_on_trade_refresh_requested)
	var parent := detail_label.get_parent()
	parent.add_child(_trade_toolbar)
	parent.move_child(_trade_toolbar, detail_label.get_index() + 1)

func _add_label(parent: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, font_size + 4)
	label.modulate = PanelTextThemeScript.row_color(font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

func _add_price_input(parent: Control, default_price: int) -> LineEdit:
	var input := LineEdit.new()
	input.name = "PriceInput"
	input.text = str(maxi(default_price, 1))
	input.placeholder_text = App.t_key("facility.trade.price.placeholder")
	input.max_length = 5
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.select_all_on_focus = true
	input.custom_minimum_size = Vector2(36, 22) if _compact_layout else Vector2(58, 30)
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	WorldHUDAssetsScript.configure_line_edit_frame(input)
	parent.add_child(input)
	text_input_added.emit(input)
	return input

func _action_row_for(row: VBoxContainer, record: Dictionary, inline_parent: HBoxContainer) -> HBoxContainer:
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 1 if _compact_layout else 6)
	action_row.visible = bool(record.get("price_input", false)) or typeof(record.get("action")) == TYPE_DICTIONARY
	if _compact_layout:
		action_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		inline_parent.add_child(action_row)
	else:
		row.add_child(action_row)
	return action_row

func _facility_record() -> Dictionary:
	if _facility_service == null or not _facility_service.has_method("get_facility"):
		return {}
	return _facility_service.call("get_facility", active_facility_id) as Dictionary
func _state_text(record: Dictionary) -> String:
	var state_key := str(record.get("state_key", "facility.state.local"))
	if _compact_layout and str(record.get("id", "")) == "trade.wallet" and state_key == "facility.trade.wallet_balance_format":
		state_key = "facility.trade.wallet_balance_short_format"
	if typeof(record.get("state_values")) == TYPE_DICTIONARY:
		return App.format_key(state_key, record.get("state_values") as Dictionary)
	return App.t_key(state_key)

func _row_body_text(record: Dictionary, include_state: bool = false) -> String:
	var body_key := str(record.get("body_key", ""))
	var body_text := ""
	if typeof(record.get("body_values")) == TYPE_DICTIONARY:
		body_text = App.format_key(body_key, record.get("body_values") as Dictionary)
	else:
		body_text = App.t_key(body_key)
	if include_state:
		var state_text := _state_text(record)
		if _compact_layout:
			return state_text if not state_text.is_empty() else body_text
		if not state_text.is_empty():
			body_text = "%s · %s" % [body_text, state_text]
	return body_text
func _on_action_pressed(action: Dictionary, button: Button, price_input: LineEdit = null) -> void:
	if _facility_service == null:
		return
	var response: Dictionary = {}
	var action_type := TradeActions.action_type(action)
	if action_type == "refresh_trade_board":
		button.disabled = true
		await _request_trade_refresh(true)
		button.disabled = false
		return
	var action_key := TradeActions.action_key(action)
	if _pending_trade_actions.has(action_key):
		detail_label.text = App.t_key("facility.trade.action.pending_detail")
		return
	if TradeActions.needs_price(action) and not TradeActions.has_valid_price(price_input):
		detail_label.text = TradeFeedback.text_for_error("invalid_listing", action_type, TradeActions.price_range_values())
		return
	var original_text := button.text
	button.disabled = true
	button.text = App.t_key("facility.trade.action.pending")
	detail_label.text = App.t_key("facility.trade.action.pending_detail")
	_pending_trade_actions[action_key] = true
	response = await TradeActions.perform(_facility_service, action, price_input)
	_pending_trade_actions.erase(action_key)
	button.text = original_text
	button.disabled = false
	if not response.is_empty() and _trade_toolbar != null:
		_trade_toolbar.call("set_outcome", response, action_type)
		if bool(response.get("ok", false)) and action_type == "create_trade_listing":
			_trade_toolbar.call("set_filter", "mine")
		elif bool(response.get("ok", false)) and action_type == "cancel_trade_listing":
			_trade_toolbar.call("set_filter", "sell")
	if visible:
		_refresh()
		call_deferred("_reset_rows_scroll")
	if not response.is_empty():
		_show_trade_action_feedback(response, action_type)

func _show_trade_action_feedback(response: Dictionary, action_type: String) -> void:
	detail_label.text = TradeFeedback.text_for_response(response, action_type, TradeActions.price_range_values())

func _on_trade_refresh_requested() -> void:
	await _request_trade_refresh(true)

func _request_trade_refresh(clear_outcome: bool = false) -> void:
	if _facility_service == null or not _facility_service.has_method("refresh"):
		return
	_trade_toolbar.set_refreshing(true)
	detail_label.text = App.t_key("facility.trade.refresh.pending")
	await _facility_service.call("refresh")
	_trade_toolbar.call("mark_synced", clear_outcome)
	if visible:
		_refresh()
		call_deferred("_reset_rows_scroll")
	detail_label.text = App.t_key("facility.trade.refresh.done")
	_trade_toolbar.set_refreshing(false)

func _reset_rows_scroll() -> void: rows_scroll.scroll_vertical = 0

func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh()

func _on_facilities_updated(_facilities: Dictionary) -> void:
	if visible:
		_refresh()
