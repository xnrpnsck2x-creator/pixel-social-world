class_name SocialFacilityTradeToolbar
extends HBoxContainer

signal filter_changed(filter_id: String)
signal refresh_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const TradeOutcomeHistoryScript := preload("res://scripts/UI/Panels/SocialFacilityTradeOutcomeHistory.gd")
const FILTERS := [
	{"id": "all", "key": "facility.trade.filter.all"},
	{"id": "buy", "key": "facility.trade.filter.buy"},
	{"id": "mine", "key": "facility.trade.filter.mine"},
	{"id": "sell", "key": "facility.trade.filter.sell"},
]

var filter_id := "all"
var _compact_layout := false
var _filter_counts := {}
var _outcome_history := TradeOutcomeHistoryScript.new()
var _sync_key := "facility.trade.sync.ready"
var _picker: OptionButton
var _refresh_button: Button
var _sync_label: Label

func _ready() -> void:
	_build()
	refresh_text()

func set_compact_layout(enabled: bool) -> void:
	_compact_layout = enabled
	_apply_sizes()
	refresh_text()

func refresh_text() -> void:
	if _picker == null:
		return
	for index in range(FILTERS.size()):
		var record: Dictionary = FILTERS[index]
		_picker.set_item_text(index, _filter_text(record))
	if _refresh_button != null:
		_refresh_button.text = App.t_key("facility.trade.refresh.short" if _compact_layout else "ui.action.refresh")
		_refresh_button.tooltip_text = App.t_key("facility.trade.refresh.tooltip")
	if _sync_label != null:
		_sync_label.text = App.t_key(_sync_key)

func set_refreshing(enabled: bool) -> void:
	if _refresh_button == null:
		return
	_refresh_button.disabled = enabled
	if enabled:
		_refresh_button.text = App.t_key("facility.trade.refresh.pending_short")
		_set_sync_key("facility.trade.sync.pending")
	else:
		_refresh_button.text = App.t_key("facility.trade.refresh.short" if _compact_layout else "ui.action.refresh")

func mark_synced(clear_outcome: bool = false) -> void:
	_set_sync_key("facility.trade.sync.current")
	if clear_outcome:
		_outcome_history.clear_failed()

func set_outcome(response: Dictionary, action_type: String) -> void:
	var ok := bool(response.get("ok", false))
	_set_sync_key("facility.trade.sync.current" if ok else "facility.trade.sync.needs_refresh")
	_outcome_history.add(response, action_type)

func set_filter(next_filter_id: String) -> void:
	for index in range(FILTERS.size()):
		var record: Dictionary = FILTERS[index]
		if str(record.get("id", "")) != next_filter_id:
			continue
		filter_id = next_filter_id
		if _picker != null:
			_picker.select(index)
		return

func filter_rows(row_records: Array) -> Array:
	var rows_with_outcome := _rows_with_outcome(row_records)
	_refresh_filter_counts(rows_with_outcome)
	if filter_id == "all":
		return rows_with_outcome
	return _prioritized_filtered_rows(rows_with_outcome)

func _prioritized_filtered_rows(row_records: Array) -> Array:
	var wallet_rows: Array = []
	var action_rows: Array = []
	var passive_rows: Array = []
	var outcome_rows: Array = []
	for row_record in row_records:
		if typeof(row_record) != TYPE_DICTIONARY:
			continue
		var row := row_record as Dictionary
		var row_id := str(row.get("id", ""))
		if row_id == "trade.wallet":
			wallet_rows.append(row)
		elif row_id.begins_with("trade.outcome."):
			outcome_rows.append(row)
		elif _row_matches_filter_id(row, filter_id):
			if _is_primary_filter_action(row, filter_id):
				action_rows.append(row)
			else:
				passive_rows.append(row)

	var filtered: Array = []
	filtered.append_array(wallet_rows)
	filtered.append_array(action_rows)
	filtered.append_array(passive_rows)
	filtered.append_array(outcome_rows)
	if action_rows.is_empty() and passive_rows.is_empty() and outcome_rows.is_empty():
		filtered.append(_empty_filter_row())
	return filtered

func _build() -> void:
	if _picker != null:
		return
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)
	_picker = OptionButton.new()
	_picker.name = "TradeFilterPicker"
	for record in FILTERS:
		_picker.add_item(App.t_key(str((record as Dictionary).get("key", ""))))
		_picker.set_item_metadata(_picker.item_count - 1, str((record as Dictionary).get("id", "")))
	_picker.item_selected.connect(_on_filter_selected)
	add_child(_picker)
	_sync_label = Label.new()
	_sync_label.name = "TradeSyncState"
	_sync_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sync_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sync_label.clip_text = true
	_sync_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sync_label.modulate = PanelTextThemeScript.PRIMARY
	add_child(_sync_label)
	_refresh_button = Button.new()
	_refresh_button.name = "TradeRefreshButton"
	_refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	WorldHUDAssetsScript.configure_button_frame(_refresh_button)
	add_child(_refresh_button)
	_apply_sizes()

func _apply_sizes() -> void:
	add_theme_constant_override("separation", 3 if _compact_layout else 6)
	if _picker != null:
		_picker.custom_minimum_size = Vector2(82, 26) if _compact_layout else Vector2(112, 30)
	if _sync_label != null:
		_sync_label.custom_minimum_size = Vector2(46, 26) if _compact_layout else Vector2(56, 30)
		_sync_label.add_theme_font_size_override("font_size", 9 if _compact_layout else 12)
	if _refresh_button != null:
		_refresh_button.custom_minimum_size = Vector2(44, 26) if _compact_layout else Vector2(76, 30)
		_refresh_button.add_theme_font_size_override("font_size", 9 if _compact_layout else 12)

func _on_filter_selected(index: int) -> void:
	filter_id = str(_picker.get_item_metadata(index))
	filter_changed.emit(filter_id)

func _row_matches_filter(row: Dictionary) -> bool:
	return _row_matches_filter_id(row, filter_id)

func _row_matches_filter_id(row: Dictionary, target_filter_id: String) -> bool:
	var action: Dictionary = row.get("action", {}) as Dictionary
	var action_type := str(action.get("type", ""))
	match target_filter_id:
		"buy":
			return action_type == "buy_trade_listing" and not bool(row.get("disabled", false))
		"mine":
			return action_type == "cancel_trade_listing"
		"sell":
			return bool(row.get("price_input", false)) or str(row.get("id", "")).begins_with("inventory.")
	return true

func _is_primary_filter_action(row: Dictionary, target_filter_id: String) -> bool:
	var action: Dictionary = row.get("action", {}) as Dictionary
	var action_type := str(action.get("type", ""))
	match target_filter_id:
		"buy":
			return action_type == "buy_trade_listing" and not bool(row.get("disabled", false))
		"mine":
			return action_type == "cancel_trade_listing"
		"sell":
			return action_type == "create_trade_listing"
	return false

func _rows_with_outcome(row_records: Array) -> Array:
	var outcome_rows := _outcome_history.rows()
	if outcome_rows.is_empty():
		return row_records
	var next_rows := row_records.duplicate(true)
	var insert_index := 0
	if not next_rows.is_empty() and typeof(next_rows[0]) == TYPE_DICTIONARY and str((next_rows[0] as Dictionary).get("id", "")) == "trade.wallet":
		insert_index = 1
	for index in range(outcome_rows.size()):
		next_rows.insert(insert_index + index, outcome_rows[index])
	return next_rows

func _empty_filter_row() -> Dictionary:
	return {
		"id": "trade.filter.%s.empty" % filter_id,
		"title_key": "facility.trade.filter.empty.title",
		"body_key": "facility.trade.filter.%s.empty.body" % filter_id,
		"state_key": "facility.trade.filter.empty.state",
		"icon_id": "icon.gift"
	}

func _refresh_filter_counts(row_records: Array) -> void:
	var counts := {"buy": 0, "mine": 0, "sell": 0}
	for row_record in row_records:
		if typeof(row_record) != TYPE_DICTIONARY:
			continue
		var row := row_record as Dictionary
		for key in ["buy", "mine", "sell"]:
			if _row_matches_filter_id(row, key):
				counts[key] = int(counts.get(key, 0)) + 1
	counts["all"] = int(counts.get("buy", 0)) + int(counts.get("mine", 0)) + int(counts.get("sell", 0))
	_filter_counts = counts
	refresh_text()

func _filter_text(record: Dictionary) -> String:
	var label := App.t_key(str(record.get("key", "")))
	var key := str(record.get("id", ""))
	if _filter_counts.has(key):
		return App.format_key("facility.trade.filter.count_format", {
			"label": label,
			"count": int(_filter_counts.get(key, 0))
		})
	return label

func _set_sync_key(next_key: String) -> void:
	_sync_key = next_key
	if _sync_label != null:
		_sync_label.text = App.t_key(_sync_key)
