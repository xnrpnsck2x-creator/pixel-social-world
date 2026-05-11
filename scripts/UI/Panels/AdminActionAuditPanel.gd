class_name AdminActionAuditPanel
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

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token

func set_embedded_admin_mode(enabled: bool) -> void:
	_embedded_admin_mode = enabled
	_build()
	if _token_input != null:
		_token_input.visible = not enabled

func set_action_audit_snapshot(snapshot: Dictionary) -> void:
	_build()
	_snapshot = snapshot.duplicate(true)
	_render_rows()

func refresh_action_audit() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("admin_action_audit.console.loading")
	var response: Dictionary = await _online_client().call("fetch_admin_action_audit_admin", token)
	if bool(response.get("ok", false)):
		set_action_audit_snapshot(response.get("data", {}) as Dictionary)
	else:
		_status_label.text = App.format_key("reviewer.console.failed_format", {
			"error": str(response.get("error", "request_failed"))
		})
		_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 200)
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
	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.visible = not _embedded_admin_mode
	layout.add_child(_token_input)
	_status_label = Label.new()
	_status_label.text = App.t_key("admin_action_audit.console.empty")
	_status_label.modulate = PanelTextThemeScript.MUTED
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)
	_add_scroll_rows(layout)

func _add_header(layout: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	_add_icon(header, "icon.check", Vector2(34, 34))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("admin_action_audit.console.title")
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.t_key("admin_action_audit.console.detail")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelTextThemeScript.apply_pair([title], [detail])
	labels.add_child(detail)
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_action_audit)
	header.add_child(_refresh_button)

func _add_scroll_rows(layout: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 128)
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
	_status_label.text = App.format_key("admin_action_audit.console.summary_format", {
		"count": int(_snapshot.get("count", items.size())),
		"matched": int(_snapshot.get("matched", items.size()))
	})
	if items.is_empty():
		_add_empty_row()
		_refresh_button.disabled = false
		return
	for item in items.slice(0, MAX_ROWS):
		if typeof(item) == TYPE_DICTIONARY:
			_add_action_row(item as Dictionary)
	_refresh_button.disabled = false

func _add_action_row(item: Dictionary) -> void:
	var row := PanelListFrameScript.new().add_hbox(_rows, compact_layout)
	_add_icon(row, "icon.mail", Vector2(26, 26))
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	_add_label(labels, App.format_key("admin_action_audit.console.row_title_format", {
		"action": str(item.get("action", "-")),
		"status": str(item.get("status", "-"))
	}), false)
	_add_label(labels, App.format_key("admin_action_audit.console.row_detail_format", {
		"role": str(item.get("role", "-")),
		"target": _target_label(item),
		"request": str(item.get("request_id", "-"))
	}), true)
	var note := str(item.get("note", ""))
	if not note.is_empty():
		_add_label(labels, App.format_key("admin_action_audit.console.row_note_format", {"note": note}), true)

func _add_empty_row() -> void:
	_add_label(PanelListFrameScript.new().add_hbox(_rows, compact_layout), App.t_key("admin_action_audit.console.empty"), true)

func _target_label(item: Dictionary) -> String:
	var target := str(item.get("target_id", ""))
	if target.is_empty():
		target = "-"
	return "%s:%s" % [str(item.get("target_type", "unknown")), target]

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

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	if _refresh_button != null:
		WorldHUDAssetsScript.configure_button_frame(_refresh_button)
	if _token_input != null:
		WorldHUDAssetsScript.configure_line_edit_frame(_token_input)

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
