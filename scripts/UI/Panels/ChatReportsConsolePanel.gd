class_name ChatReportsConsolePanel
extends PanelContainer

signal report_action_completed(report_id: String, status: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const MAX_ROWS := 6

var compact_layout := false
var _built := false
var _token_input: LineEdit
var _status_label: Label
var _items_rows: VBoxContainer
var _refresh_button: Button

func _ready() -> void:
	_build()
	_apply_image2_style()

func set_compact_layout(enabled: bool) -> void:
	compact_layout = enabled
	if _items_rows != null:
		_items_rows.add_theme_constant_override("separation", 4 if enabled else 6)

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token

func set_reports_snapshot(snapshot: Dictionary) -> void:
	_build()
	var items: Array = snapshot.get("items", []) as Array
	_render_items(items)
	_status_label.text = App.format_key("chat_reports.console.summary_format", {"count": items.size()})
	if _refresh_button != null:
		_refresh_button.disabled = false

func refresh_reports() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("chat_reports.console.loading")
	var response: Dictionary = await _online_client().call("fetch_chat_reports_admin", token, "open")
	if bool(response.get("ok", false)):
		set_reports_snapshot(response.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
		_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(380, 240)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	rows.add_child(header)
	_add_icon(header, "icon.chat", Vector2(36, 36))
	_add_header_labels(header)
	_add_refresh_button(header)

	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	rows.add_child(_token_input)

	_status_label = Label.new()
	_status_label.text = App.t_key("chat_reports.console.empty")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 124)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	_items_rows = VBoxContainer.new()
	_items_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_rows)

func _add_header_labels(header: HBoxContainer) -> void:
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("chat_reports.console.title")
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.t_key("chat_reports.console.detail")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)

func _add_refresh_button(header: HBoxContainer) -> void:
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_reports)
	header.add_child(_refresh_button)

func _render_items(items: Array) -> void:
	for child in _items_rows.get_children():
		child.queue_free()
	if items.is_empty():
		_add_empty_row()
		return
	for item in items.slice(0, MAX_ROWS):
		if typeof(item) == TYPE_DICTIONARY:
			_add_report_row(item as Dictionary)

func _add_report_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_rows.add_child(row)
	_add_icon(row, "icon.mail", Vector2(30, 30))
	_add_report_labels(row, item)
	_add_action_buttons(row, item)

func _add_report_labels(row: HBoxContainer, item: Dictionary) -> void:
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title := Label.new()
	title.text = App.format_key("chat_reports.console.row_title_format", {
		"sender": str(item.get("message_sender_name", "-")),
		"room": str(item.get("room_id", "-")),
		"status": str(item.get("status", "open"))
	})
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.format_key("chat_reports.console.row_detail_format", {
		"reason": str(item.get("reason", "-")),
		"body": _clamp_body(str(item.get("message_body", "")))
	})
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)

func _add_action_buttons(row: HBoxContainer, item: Dictionary) -> void:
	if str(item.get("status", "open")) != "open":
		return
	_add_action_button(row, item, "mute_1h", "_run_mute_action")
	for status in ["reviewed", "dismissed"]:
		_add_action_button(row, item, status, "_run_review_action")

func _add_action_button(row: HBoxContainer, item: Dictionary, action_id: String, callback_name: String) -> void:
	var button := Button.new()
	button.text = App.t_key("chat_reports.console.action.%s" % action_id)
	button.custom_minimum_size = Vector2(64, 30) if compact_layout else Vector2(78, 32)
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(Callable(self, callback_name).bind(item, action_id))
	row.add_child(button)

func _run_review_action(item: Dictionary, status: String) -> void:
	var report_id := str(item.get("id", ""))
	if report_id.is_empty():
		return
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_status_label.text = App.format_key("reviewer.console.action_running_format", {"action": status})
	var response: Dictionary = await _online_client().call(
		"review_chat_report_admin",
		report_id,
		status,
		token,
		"handled_from_console"
	)
	if bool(response.get("ok", false)):
		report_action_completed.emit(report_id, status)
		await refresh_reports()
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})

func _run_mute_action(item: Dictionary, _action_id: String) -> void:
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	var report_id := str(item.get("id", ""))
	var target_id := str(item.get("message_sender_id", ""))
	if report_id.is_empty() or target_id.is_empty():
		_status_label.text = App.t_key("chat_reports.console.action.missing_target")
		return
	_status_label.text = App.t_key("chat_reports.console.action.muting")
	var response: Dictionary = await _online_client().call("apply_chat_moderation_admin", {
		"target_player_id": target_id,
		"target_name": str(item.get("message_sender_name", "")),
		"action": "mute",
		"scope": "room",
		"room_id": str(item.get("room_id", "")),
		"duration_seconds": 3600,
		"reason": str(item.get("reason", "player_report")),
		"report_id": report_id
	}, token)
	if not bool(response.get("ok", false)):
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
		return
	await _run_review_action(item, "reviewed")

func _add_empty_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_items_rows.add_child(row)
	_add_icon(row, "icon.check", Vector2(30, 30))
	var label := Label.new()
	label.text = App.t_key("chat_reports.console.empty")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

func _clamp_body(body: String) -> String:
	if body.length() <= 72:
		return body
	return body.substr(0, 72) + "..."

func _add_icon(parent: Control, icon_id: String, size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	if _refresh_button != null:
		WorldHUDAssetsScript.configure_button_frame(_refresh_button)

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
