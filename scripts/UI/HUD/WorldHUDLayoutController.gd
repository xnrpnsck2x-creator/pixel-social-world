class_name WorldHUDLayoutController
extends RefCounted

signal compact_changed(compact: bool)

const PLAYER_NAME_MAX_CHARS := 16
const PLAYER_NAME_COMPACT_MAX_CHARS := 9

var title_label: Label
var player_label: Label
var coin_label: Label
var presence_label: Label
var online_room_panel: Control
var utility_panel: Control
var social_messages_panel: Control
var player_profile_card: Control
var _compact := false

func bind_ui(
	new_title_label: Label,
	new_player_label: Label,
	new_coin_label: Label,
	new_presence_label: Label,
	new_online_room_panel: Control,
	new_utility_panel: Control,
	new_social_messages_panel: Control,
	new_player_profile_card: Control
) -> void:
	title_label = new_title_label
	player_label = new_player_label
	coin_label = new_coin_label
	presence_label = new_presence_label
	online_room_panel = new_online_room_panel
	utility_panel = new_utility_panel
	social_messages_panel = new_social_messages_panel
	player_profile_card = new_player_profile_card
	for label in [title_label, player_label, coin_label, presence_label]:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func layout_overlay_panels(viewport_size: Vector2) -> void:
	var compact := viewport_size.y <= 480.0
	var right_margin := 12.0 if compact else 16.0
	var top_offset := 52.0 if compact else 68.0
	var room_bottom_safe := 104.0 if compact else 16.0
	var utility_bottom_safe := 104.0 if compact else 208.0
	var panel_width := 260.0 if compact else 344.0
	if viewport_size.x < 720.0:
		panel_width = min(panel_width, max(228.0, viewport_size.x - 24.0))
	_layout_side_panel(online_room_panel, panel_width, right_margin, top_offset, room_bottom_safe)
	_layout_side_panel(utility_panel, panel_width, right_margin, top_offset, utility_bottom_safe)
	_layout_side_panel(social_messages_panel, panel_width, right_margin, top_offset, utility_bottom_safe)
	_layout_profile_card(player_profile_card, panel_width, right_margin, top_offset, compact)
	_apply_compact_layout(online_room_panel, compact)
	_apply_compact_layout(utility_panel, compact)
	_apply_compact_layout(social_messages_panel, compact)
	_apply_compact_layout(player_profile_card, compact)
	_apply_top_bar_layout(compact)
	if _compact != compact:
		_compact = compact
		compact_changed.emit(_compact)

func trim_player_name(display_name: String) -> String:
	var max_chars := PLAYER_NAME_COMPACT_MAX_CHARS if _compact else PLAYER_NAME_MAX_CHARS
	if display_name.length() <= max_chars:
		return display_name
	if max_chars <= 3:
		return display_name.substr(0, max_chars)
	return display_name.substr(0, max_chars - 3) + "..."

func _apply_top_bar_layout(compact: bool) -> void:
	player_label.custom_minimum_size = Vector2(112.0 if compact else 176.0, 0)
	player_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	coin_label.custom_minimum_size = Vector2(80.0 if compact else 104.0, 0)
	presence_label.custom_minimum_size = Vector2(118.0 if compact else 190.0, 0)

func _apply_compact_layout(panel: Control, compact: bool) -> void:
	if panel != null and panel.has_method("set_compact_layout"):
		panel.call("set_compact_layout", compact)

func _layout_side_panel(
	panel: Control,
	panel_width: float,
	right_margin: float,
	top_offset: float,
	bottom_safe: float
) -> void:
	if panel == null:
		return
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -panel_width - right_margin
	panel.offset_right = -right_margin
	panel.offset_top = top_offset
	panel.offset_bottom = -bottom_safe

func _layout_profile_card(
	panel: Control,
	panel_width: float,
	right_margin: float,
	top_offset: float,
	compact: bool
) -> void:
	if panel == null:
		return
	var height := 174.0 if compact else 210.0
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -panel_width - right_margin
	panel.offset_right = -right_margin
	panel.offset_top = top_offset
	panel.offset_bottom = top_offset + height
