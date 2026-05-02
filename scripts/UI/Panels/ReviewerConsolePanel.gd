class_name ReviewerConsolePanel
extends PanelContainer

signal review_action_completed(game_id: String, action: String, status: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const ReviewerConsoleAuditScript := preload("res://scripts/UI/Panels/ReviewerConsoleAudit.gd")
const MAX_ROWS := 6

var compact_layout := false
var _embedded_admin_mode := false
var _built := false
var _token_input: LineEdit
var _note_input: LineEdit
var _status_label: Label
var _items_rows: VBoxContainer
var _refresh_button: Button
var _pending_confirm_key := ""

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

func set_embedded_admin_mode(enabled: bool) -> void:
	_embedded_admin_mode = enabled
	_build()
	if _token_input != null:
		_token_input.visible = not enabled

func set_dashboard_snapshot(snapshot: Dictionary) -> void:
	_build()
	_render_items(snapshot.get("items", []) as Array)
	_status_label.text = App.format_key("reviewer.console.summary_format", {
		"count": (snapshot.get("items", []) as Array).size()
	})

func set_audit_snapshot(snapshot: Dictionary) -> void:
	_build()
	_status_label.text = ReviewerConsoleAuditScript.summary(snapshot)

func refresh_dashboard() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("reviewer.console.loading")
	var response: Dictionary = await _online_client().call("fetch_reviewer_dashboard", token)
	if bool(response.get("ok", false)):
		set_dashboard_snapshot(response.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
	_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 230)
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
	_add_icon(header, "icon.check", Vector2(36, 36))
	_add_header_labels(header)
	_add_refresh_button(header)

	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.visible = not _embedded_admin_mode
	rows.add_child(_token_input)
	_note_input = LineEdit.new()
	_note_input.placeholder_text = App.t_key("reviewer.console.note_placeholder")
	rows.add_child(_note_input)

	_status_label = Label.new()
	_status_label.text = App.t_key("reviewer.console.empty")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 112)
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
	title.text = App.t_key("reviewer.console.title")
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.t_key("reviewer.console.detail")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)

func _add_refresh_button(header: HBoxContainer) -> void:
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_dashboard)
	header.add_child(_refresh_button)

func _render_items(items: Array) -> void:
	for child in _items_rows.get_children():
		child.queue_free()
	if items.is_empty():
		_add_empty_row()
		return
	for item in items.slice(0, MAX_ROWS):
		if typeof(item) == TYPE_DICTIONARY:
			_add_dashboard_row(item as Dictionary)

func _add_dashboard_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_rows.add_child(row)
	_add_icon(row, "icon.quest", Vector2(30, 30))
	_add_dashboard_labels(row, item)
	_add_action_buttons(row, item)

func _add_dashboard_labels(row: HBoxContainer, item: Dictionary) -> void:
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title := Label.new()
	title.text = App.format_key("reviewer.console.row_title_format", {
		"game": _localized_name(item),
		"version": str(item.get("version", "0.1.0")),
		"status": str(item.get("status", "unknown"))
	})
	labels.add_child(title)
	var detail := Label.new()
	detail.text = _row_detail(item)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)

func _add_action_buttons(row: HBoxContainer, item: Dictionary) -> void:
	var actions := _actions_for_status(str(item.get("status", "")))
	for action in actions:
		var button := Button.new()
		button.text = App.t_key("reviewer.console.action.%s" % action)
		button.custom_minimum_size = Vector2(64, 30) if compact_layout else Vector2(74, 32)
		WorldHUDAssetsScript.configure_button_frame(button)
		button.pressed.connect(_run_action.bind(str(item.get("game_id", "")), action))
		row.add_child(button)
	var export := Button.new()
	export.text = App.t_key("ui.action.export_csv")
	export.custom_minimum_size = Vector2(76, 30) if compact_layout else Vector2(92, 32)
	WorldHUDAssetsScript.configure_button_frame(export)
	export.pressed.connect(_export_audit.bind(str(item.get("game_id", ""))))
	row.add_child(export)

func _run_action(game_id: String, action: String) -> void:
	if game_id.is_empty():
		return
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	var note := _note_input.text.strip_edges()
	if _action_requires_confirm(action) and note.is_empty():
		_status_label.text = App.t_key("reviewer.console.note_required")
		return
	var confirm := false
	if _action_requires_confirm(action):
		var confirm_key := "%s:%s" % [game_id, action]
		if _pending_confirm_key != confirm_key:
			_pending_confirm_key = confirm_key
			_status_label.text = App.format_key("reviewer.console.confirm_required_format", {"action": action})
			return
		confirm = true
	_status_label.text = App.format_key("reviewer.console.action_running_format", {"action": action})
	var response: Dictionary = await _online_client().call("review_minigame_admin", game_id, action, token, confirm, note)
	if bool(response.get("ok", false)):
		_pending_confirm_key = ""
		var data: Dictionary = response.get("data", {}) as Dictionary
		review_action_completed.emit(game_id, action, str(data.get("status", "")))
		await refresh_dashboard()
		await _refresh_audit_summary(game_id, token)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})

func _action_requires_confirm(action: String) -> bool:
	return action == "rollback" or action == "unpublish"

func _refresh_audit_summary(game_id: String, token: String) -> void:
	var response: Dictionary = await _online_client().call("fetch_reviewer_audit", game_id, token)
	if bool(response.get("ok", false)):
		set_audit_snapshot(response.get("data", {}) as Dictionary)

func _export_audit(game_id: String) -> void:
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_status_label.text = App.t_key("reviewer.console.exporting")
	var response: Dictionary = await _online_client().call("export_reviewer_audit_admin", game_id, token, {})
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		_status_label.text = App.format_key("reviewer.console.export_ready_format", {"bytes": int(data.get("bytes", 0))})
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {"error": str(response.get("error", "request_failed"))})

func _actions_for_status(status: String) -> Array[String]:
	match status:
		"needs_review":
			return ["approve", "reject"]
		"approved":
			return ["publish", "reject"]
		"published":
			return ["rollback", "unpublish"]
		"rejected":
			return ["needs_review"]
		_:
			return []

func _row_detail(item: Dictionary) -> String:
	var scan: Dictionary = item.get("scan", {}) as Dictionary
	var ai: Dictionary = item.get("ai", {}) as Dictionary
	var job: Dictionary = item.get("job", {}) as Dictionary
	var install: Dictionary = item.get("install", {}) as Dictionary
	return App.format_key("reviewer.console.row_detail_format", {
		"mode": str(item.get("mode_id", "unknown")),
		"scan": str(scan.get("status", "pending")),
		"issues": int(scan.get("issue_count", 0)),
		"ai": str(ai.get("status", "pending")),
		"job": str(job.get("status", "pending")),
		"install": str(install.get("status", "not_installed"))
	})

func _localized_name(item: Dictionary) -> String:
	var name: Dictionary = item.get("name", {}) as Dictionary
	return str(name.get(App.current_locale, name.get("en", item.get("game_id", ""))))

func _add_empty_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_items_rows.add_child(row)
	_add_icon(row, "icon.check", Vector2(30, 30))
	var label := Label.new()
	label.text = App.t_key("reviewer.console.empty")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)

func _add_icon(parent: Control, icon_id: String, size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = size
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	for input in [_token_input, _note_input]:
		if input != null:
			WorldHUDAssetsScript.configure_line_edit_frame(input)
	if _refresh_button != null:
		WorldHUDAssetsScript.configure_button_frame(_refresh_button)

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
