class_name LiveOpsConsolePanel
extends Control

const ReviewerConsoleScene := preload("res://scenes/ui/ReviewerConsolePanel.tscn")
const ChatReportsConsoleScene := preload("res://scenes/ui/ChatReportsConsolePanel.tscn")
const ChatModerationAuditScene := preload("res://scenes/ui/ChatModerationAuditPanel.tscn")
const AdminActionAuditScene := preload("res://scenes/ui/AdminActionAuditPanel.tscn")
const TradeHistoryAuditScene := preload("res://scenes/ui/TradeHistoryAuditPanel.tscn")
const DebugOpsScene := preload("res://scenes/ui/DebugOpsPanel.tscn")
const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var compact_layout := false
var _narrow_layout := false
var _built := false
var _token_input: LineEdit
var _status_label: Label
var _refresh_button: Button
var _reviewer_panel
var _chat_reports_panel
var _moderation_panel
var _action_audit_panel
var _trade_history_panel
var _audit_group: VBoxContainer
var _ops_panel
var _panels_row: GridContainer
var _tabs: GridContainer
var _section_buttons: Array[Button] = []
var _section_panels: Array[Node] = []
var _active_section_index := 0
var _admin_role := "owner"

func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")

func set_compact_layout(enabled: bool) -> void:
	compact_layout = enabled
	_build()
	for panel in _embedded_panels():
		if panel != null and panel.has_method("set_compact_layout"):
			panel.call("set_compact_layout", enabled)
	_panels_row.columns = 1 if enabled else 2
	_panels_row.add_theme_constant_override("h_separation", 8 if enabled else 12)
	_panels_row.add_theme_constant_override("v_separation", 8 if enabled else 12)
	if _token_input != null:
		_token_input.custom_minimum_size = Vector2(112, 32) if enabled else Vector2(160, 32)
	if _refresh_button != null:
		_refresh_button.custom_minimum_size = Vector2(64, 32) if enabled else Vector2(74, 32)
	_apply_panel_visibility()

func set_narrow_layout(enabled: bool) -> void:
	_narrow_layout = enabled
	_build()
	if _tabs != null:
		_tabs.visible = enabled
	_apply_panel_visibility()

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token
	_apply_token_to_children()

func set_reviewer_snapshot(snapshot: Dictionary) -> void:
	_build()
	_reviewer_panel.call("set_dashboard_snapshot", snapshot)

func set_chat_reports_snapshot(snapshot: Dictionary) -> void:
	_build()
	_chat_reports_panel.call("set_reports_snapshot", snapshot)

func set_admin_session_snapshot(snapshot: Dictionary) -> void:
	_build()
	_admin_role = str(snapshot.get("role", "owner"))
	_status_label.text = App.format_key("liveops.console.role_format", {"role": _admin_role})

func set_moderation_snapshot(snapshot: Dictionary) -> void:
	_build()
	_moderation_panel.call("set_moderation_snapshot", snapshot)

func set_admin_action_audit_snapshot(snapshot: Dictionary) -> void:
	_build()
	_action_audit_panel.call("set_action_audit_snapshot", snapshot)

func set_trade_history_audit_snapshot(snapshot: Dictionary) -> void:
	_build()
	_trade_history_panel.call("set_trade_history_snapshot", snapshot)

func set_ops_snapshot(snapshot: Dictionary) -> void:
	_build()
	_ops_panel.call("set_ops_snapshot", snapshot)

func set_room_snapshot(snapshot: Dictionary) -> void:
	_build()
	_ops_panel.call("set_room_snapshot", snapshot)

func refresh_all() -> void:
	_build()
	_apply_token_to_children()
	var admin_token := _token_input.text.strip_edges()
	if admin_token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_status_label.text = App.t_key("liveops.console.loading")
	_refresh_button.disabled = true
	var session: Dictionary = await _online_client().call("fetch_admin_session", admin_token)
	if bool(session.get("ok", false)):
		set_admin_session_snapshot(session.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(session.get("error", "request_failed"))
		})
		_refresh_button.disabled = false
		return
	_apply_token_to_children()
	await _reviewer_panel.call("refresh_dashboard")
	_apply_token_to_children()
	await _chat_reports_panel.call("refresh_reports")
	_apply_token_to_children()
	await _moderation_panel.call("refresh_moderation")
	_apply_token_to_children()
	await _action_audit_panel.call("refresh_action_audit")
	_apply_token_to_children()
	await _trade_history_panel.call("refresh_trade_history")
	_apply_token_to_children()
	await _ops_panel.call("refresh_ops")
	_refresh_button.disabled = false
	_status_label.text = App.format_key("liveops.console.ready_role_format", {"role": _admin_role})

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 320)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rows)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	rows.add_child(header)
	_add_icon(header)
	_add_header_labels(header)
	var admin_row := HBoxContainer.new()
	admin_row.add_theme_constant_override("separation", 6)
	rows.add_child(admin_row)
	_add_token_input(admin_row)
	_add_refresh_button(admin_row)
	_add_tabs(rows)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	_panels_row = GridContainer.new()
	_panels_row.columns = 3
	_panels_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panels_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panels_row.add_theme_constant_override("h_separation", 12)
	_panels_row.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_panels_row)

	_reviewer_panel = ReviewerConsoleScene.instantiate()
	_chat_reports_panel = ChatReportsConsoleScene.instantiate()
	_moderation_panel = ChatModerationAuditScene.instantiate()
	_action_audit_panel = AdminActionAuditScene.instantiate()
	_trade_history_panel = TradeHistoryAuditScene.instantiate()
	_ops_panel = DebugOpsScene.instantiate()
	_audit_group = VBoxContainer.new()
	_audit_group.add_theme_constant_override("separation", 8)
	_audit_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audit_group.add_child(_moderation_panel)
	_audit_group.add_child(_action_audit_panel)
	_audit_group.add_child(_trade_history_panel)
	_section_panels = [_reviewer_panel, _chat_reports_panel, _audit_group, _ops_panel]
	for panel in _embedded_panels():
		var control := panel as Control
		if control != null:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if panel.has_method("set_embedded_admin_mode"):
			panel.call("set_embedded_admin_mode", true)
	for panel in _section_panels:
		_panels_row.add_child(panel)

func _add_icon(header: HBoxContainer) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.check")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

func _add_header_labels(header: HBoxContainer) -> void:
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("liveops.console.title")
	labels.add_child(title)
	_status_label = Label.new()
	_status_label.text = App.t_key("liveops.console.ready")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(_status_label)

func _add_token_input(header: HBoxContainer) -> void:
	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.custom_minimum_size = Vector2(160, 32)
	_token_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_input.text_changed.connect(func(_text: String) -> void: _apply_token_to_children())
	WorldHUDAssetsScript.configure_line_edit_frame(_token_input)
	header.add_child(_token_input)

func _add_refresh_button(header: HBoxContainer) -> void:
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(74, 32)
	_refresh_button.pressed.connect(refresh_all)
	WorldHUDAssetsScript.configure_button_frame(_refresh_button)
	header.add_child(_refresh_button)

func _add_tabs(rows: VBoxContainer) -> void:
	_tabs = GridContainer.new()
	_tabs.columns = 2
	_tabs.visible = false
	_tabs.add_theme_constant_override("h_separation", 4)
	_tabs.add_theme_constant_override("v_separation", 4)
	rows.add_child(_tabs)
	var labels := [
		"liveops.console.tab.review",
		"liveops.console.tab.reports",
		"liveops.console.tab.audit",
		"liveops.console.tab.ops"
	]
	for i in range(labels.size()):
		var button := Button.new()
		button.text = App.t_key(labels[i])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_active_section.bind(i))
		WorldHUDAssetsScript.configure_button_frame(button)
		_tabs.add_child(button)
		_section_buttons.append(button)

func _set_active_section(index: int) -> void:
	_active_section_index = clampi(index, 0, max(0, _section_panels.size() - 1))
	_apply_panel_visibility()

func _apply_panel_visibility() -> void:
	for i in range(_section_panels.size()):
		var panel := _section_panels[i] as Control
		if panel != null:
			panel.visible = not _narrow_layout or i == _active_section_index
	for i in range(_section_buttons.size()):
		_section_buttons[i].button_pressed = i == _active_section_index

func _apply_token_to_children() -> void:
	for panel in _embedded_panels():
		if panel != null and panel.has_method("set_admin_token"):
			panel.call("set_admin_token", _token_input.text)

func _embedded_panels() -> Array:
	return [_reviewer_panel, _chat_reports_panel, _moderation_panel, _action_audit_panel, _trade_history_panel, _ops_panel]

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")

func _update_responsive_layout() -> void:
	var width := _responsive_width()
	set_compact_layout(width < 1120)
	set_narrow_layout(width < 520)

func _responsive_width() -> float:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		var value: Variant = bridge.call(
			"eval",
			"Math.max(0, Math.floor(window.innerWidth || document.documentElement.clientWidth || 0))",
			true
		)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			var browser_width := float(value)
			if browser_width > 0.0:
				return browser_width
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x > 0.0:
		return window_size.x
	return get_viewport_rect().size.x
