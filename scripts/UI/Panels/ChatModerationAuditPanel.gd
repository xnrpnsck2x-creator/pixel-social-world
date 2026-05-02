class_name ChatModerationAuditPanel
extends PanelContainer

signal moderation_action_completed(target_player_id: String, action: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const ChatModerationAuditFiltersScript := preload("res://scripts/UI/Panels/ChatModerationAuditFilters.gd")
const MAX_ROWS := 4

var compact_layout := false
var _embedded_admin_mode := false
var _built := false
var _token_input: LineEdit
var _status_label: Label
var _active_rows: VBoxContainer
var _recent_rows: VBoxContainer
var _refresh_button: Button
var _filters

func _ready() -> void:
	_build()
	_apply_image2_style()

func set_compact_layout(enabled: bool) -> void:
	compact_layout = enabled
	if _active_rows != null:
		_active_rows.add_theme_constant_override("separation", 4 if enabled else 6)
	if _recent_rows != null:
		_recent_rows.add_theme_constant_override("separation", 4 if enabled else 6)

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token

func set_embedded_admin_mode(enabled: bool) -> void:
	_embedded_admin_mode = enabled
	_build()
	if _token_input != null:
		_token_input.visible = not enabled

func set_moderation_snapshot(snapshot: Dictionary) -> void:
	_build()
	var active: Array = snapshot.get("active", []) as Array
	var recent: Array = snapshot.get("recent", []) as Array
	_render_rows(_active_rows, active, true)
	_render_rows(_recent_rows, recent, false)
	_status_label.text = App.format_key("moderation.console.summary_format", {
		"active": active.size(),
		"recent": recent.size()
	})
	if _refresh_button != null:
		_refresh_button.disabled = false

func refresh_moderation() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("moderation.console.loading")
	var response: Dictionary = await _online_client().call(
		"fetch_chat_moderation_admin",
		token,
		_filters.target_player_id(),
		_filters.action()
	)
	if bool(response.get("ok", false)):
		set_moderation_snapshot(response.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
		_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 240)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)
	_add_header(rows)

	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.visible = not _embedded_admin_mode
	rows.add_child(_token_input)
	_filters = ChatModerationAuditFiltersScript.new()
	_filters.build()
	_filters.export_requested.connect(_export_csv)
	rows.add_child(_filters)

	_status_label = Label.new()
	_status_label.text = App.t_key("moderation.console.empty_active")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status_label)

	_active_rows = _add_section(rows, "moderation.console.active")
	_recent_rows = _add_section(rows, "moderation.console.recent")

func _add_header(rows: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	rows.add_child(header)
	_add_icon(header, "icon.check", Vector2(36, 36))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("moderation.console.title")
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.t_key("moderation.console.detail")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_moderation)
	header.add_child(_refresh_button)

func _export_csv() -> void:
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_status_label.text = App.t_key("moderation.console.exporting")
	var response: Dictionary = await _online_client().call(
		"export_chat_moderation_admin",
		token,
		_filters.target_player_id(),
		_filters.action()
	)
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		_status_label.text = App.format_key("moderation.console.export_ready_format", {"bytes": int(data.get("bytes", 0))})
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {"error": str(response.get("error", "request_failed"))})

func _add_section(rows: VBoxContainer, title_key: String) -> VBoxContainer:
	var title := Label.new()
	title.text = App.t_key(title_key)
	rows.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 86)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 6)
	scroll.add_child(container)
	return container

func _render_rows(container: VBoxContainer, items: Array, active: bool) -> void:
	for child in container.get_children():
		child.queue_free()
	if items.is_empty():
		_add_empty_row(container, active)
		return
	for item in items.slice(0, MAX_ROWS):
		if typeof(item) == TYPE_DICTIONARY:
			_add_action_row(container, item as Dictionary, active)

func _add_action_row(container: VBoxContainer, item: Dictionary, active: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(row)
	_add_icon(row, "icon.mail", Vector2(28, 28))
	_add_action_labels(row, item, active)
	if active and str(item.get("action", "")) != "restore":
		_add_restore_button(row, item)

func _add_action_labels(row: HBoxContainer, item: Dictionary, active: bool) -> void:
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title := Label.new()
	title.text = App.format_key("moderation.console.row_title_format", {
		"target": _target_label(item),
		"action": str(item.get("action", "-")),
		"scope": str(item.get("scope", "-"))
	})
	labels.add_child(title)
	var detail := Label.new()
	var duration := _duration_text(item) if active else _created_text(item)
	detail.text = App.format_key("moderation.console.row_detail_format", {
		"room": str(item.get("room_id", "-")),
		"duration": duration,
		"reason": str(item.get("reason", "-"))
	})
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)

func _add_restore_button(row: HBoxContainer, item: Dictionary) -> void:
	var button := Button.new()
	button.text = App.t_key("moderation.console.action.restore")
	button.custom_minimum_size = Vector2(64, 30) if compact_layout else Vector2(76, 32)
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(_run_restore_action.bind(item))
	row.add_child(button)

func _run_restore_action(item: Dictionary) -> void:
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	var target_id := str(item.get("target_player_id", ""))
	if target_id.is_empty():
		_status_label.text = App.t_key("moderation.console.missing_target")
		return
	_status_label.text = App.t_key("moderation.console.restoring")
	var response: Dictionary = await _online_client().call("apply_chat_moderation_admin", {
		"target_player_id": target_id,
		"target_name": str(item.get("target_name", "")),
		"action": "restore",
		"scope": str(item.get("scope", "room")),
		"room_id": str(item.get("room_id", "")),
		"reason": "restore_from_console",
		"report_id": str(item.get("report_id", ""))
	}, token)
	if bool(response.get("ok", false)):
		moderation_action_completed.emit(target_id, "restore")
		await refresh_moderation()
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})

func _add_empty_row(container: VBoxContainer, active: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	container.add_child(row)
	_add_icon(row, "icon.check", Vector2(28, 28))
	var label := Label.new()
	label.text = App.t_key("moderation.console.empty_active" if active else "moderation.console.empty_recent")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

func _target_label(item: Dictionary) -> String:
	var name := str(item.get("target_name", ""))
	if not name.is_empty():
		return name
	return str(item.get("target_player_id", "-"))

func _duration_text(item: Dictionary) -> String:
	var expires_at := int(item.get("expires_at", 0))
	if expires_at <= 0:
		return App.t_key("moderation.console.duration.never")
	var seconds_left: int = maxi(0, expires_at - int(Time.get_unix_time_from_system()))
	return App.format_key("moderation.console.duration.seconds_format", {"seconds": seconds_left})

func _created_text(item: Dictionary) -> String:
	return App.format_key("moderation.console.created_format", {"created": int(item.get("created_at", 0))})

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
	if _filters != null:
		_filters.apply_image2_style()

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
