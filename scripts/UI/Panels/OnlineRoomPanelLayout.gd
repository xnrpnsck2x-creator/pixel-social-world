class_name OnlineRoomPanelLayout
extends RefCounted

const REGULAR_SESSION_ROW_LIMIT := 3
const COMPACT_SESSION_ROW_LIMIT := 2

var panel: Control
var title_labels: Array[Label] = []
var chat_preview_label: Label
var game_catalog_label: Label
var panel_invite_button: Button
var room_chat_row: Control
var quick_emote_row: BoxContainer
var quick_emote_buttons: Array[Button] = []
var members_label: Label
var room_chat_input: LineEdit
var sessions_label: Label
var compact_buttons: Array[Button] = []
var _compact := false
var _initialized := false

func bind(
	new_panel: Control,
	new_title_labels: Array[Label],
	new_chat_preview_label: Label,
	new_game_catalog_label: Label,
	new_panel_invite_button: Button,
	new_room_chat_row: Control,
	new_quick_emote_row: BoxContainer,
	new_quick_emote_buttons: Array[Button],
	new_members_label: Label,
	new_room_chat_input: LineEdit,
	new_sessions_label: Label,
	new_compact_buttons: Array[Button]
) -> void:
	panel = new_panel
	title_labels = new_title_labels
	chat_preview_label = new_chat_preview_label
	game_catalog_label = new_game_catalog_label
	panel_invite_button = new_panel_invite_button
	room_chat_row = new_room_chat_row
	quick_emote_row = new_quick_emote_row
	quick_emote_buttons = new_quick_emote_buttons
	members_label = new_members_label
	room_chat_input = new_room_chat_input
	sessions_label = new_sessions_label
	compact_buttons = new_compact_buttons

func set_compact(enabled: bool) -> bool:
	if _initialized and _compact == enabled:
		return false
	_compact = enabled
	_initialized = true
	_apply()
	return true

func is_compact() -> bool:
	return _compact

func session_row_limit() -> int:
	return COMPACT_SESSION_ROW_LIMIT if _compact else REGULAR_SESSION_ROW_LIMIT

func apply_text() -> void:
	if not _compact:
		return
	for button in compact_buttons:
		if button == null:
			continue
		if button.name == "RefreshButton":
			button.text = App.t_key("ui.action.refresh")
		elif button.name == "CloseButton":
			button.text = App.t_key("ui.action.close")

func apply_session_text_limits() -> void:
	if sessions_label != null:
		sessions_label.max_lines_visible = session_row_limit()

func _apply() -> void:
	if panel != null:
		panel.custom_minimum_size = Vector2(252, 218) if _compact else Vector2(328, 388)
	for title in title_labels:
		title.visible = false
	if chat_preview_label != null:
		chat_preview_label.visible = not _compact
		chat_preview_label.custom_minimum_size = Vector2(0, 0) if _compact else Vector2(0, 32)
	if game_catalog_label != null:
		game_catalog_label.visible = not _compact
		game_catalog_label.custom_minimum_size = Vector2(0, 18) if _compact else Vector2(0, 22)
	if panel_invite_button != null:
		panel_invite_button.custom_minimum_size = Vector2(0, 28) if _compact else Vector2(0, 30)
	if room_chat_row != null:
		room_chat_row.visible = true
	if quick_emote_row != null:
		quick_emote_row.alignment = BoxContainer.ALIGNMENT_END if _compact else BoxContainer.ALIGNMENT_BEGIN
		quick_emote_row.add_theme_constant_override("separation", 6 if _compact else 8)
	for button in quick_emote_buttons:
		if button != null:
			button.custom_minimum_size = Vector2(32, 32) if _compact else Vector2(36, 36)
	if members_label != null:
		members_label.custom_minimum_size = Vector2(0, 0) if _compact else Vector2(0, 34)
	if room_chat_input != null:
		room_chat_input.custom_minimum_size = Vector2(0, 24) if _compact else Vector2(0, 34)
	if sessions_label != null:
		sessions_label.custom_minimum_size = Vector2(0, 24) if _compact else Vector2(0, 34)
	apply_session_text_limits()
	for button in compact_buttons:
		if button != null:
			button.custom_minimum_size = Vector2(0, 26) if _compact else Vector2(0, 32)
	apply_text()
