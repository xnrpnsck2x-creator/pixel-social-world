class_name WorldHUDBarDensityController
extends RefCounted

const TOP_HEIGHT := 46.0
const TOP_HEIGHT_COMPACT := 44.0
const BOTTOM_HEIGHT := 58.0
const BOTTOM_HEIGHT_COMPACT := 54.0
const BOTTOM_HEIGHT_EXPANDED := 104.0
const BOTTOM_HEIGHT_EXPANDED_COMPACT := 96.0

var top_bar: PanelContainer
var bottom_bar: PanelContainer
var status_label: Label
var chat_log: Label
var invite_button: Button
var channel_picker: OptionButton
var layout_controller

func bind(
	new_top_bar: PanelContainer,
	new_bottom_bar: PanelContainer,
	new_status_label: Label,
	new_chat_log: Label,
	new_invite_button: Button,
	new_channel_picker: OptionButton,
	new_layout_controller
) -> void:
	top_bar = new_top_bar
	bottom_bar = new_bottom_bar
	status_label = new_status_label
	chat_log = new_chat_log
	invite_button = new_invite_button
	channel_picker = new_channel_picker
	layout_controller = new_layout_controller
	refresh()

func refresh() -> void:
	if top_bar == null or bottom_bar == null:
		return
	var compact: bool = layout_controller != null and bool(layout_controller.is_compact())
	var top_height := TOP_HEIGHT_COMPACT if compact else TOP_HEIGHT
	var bottom_height := _bottom_height(compact)
	top_bar.offset_bottom = top_height
	bottom_bar.offset_top = -bottom_height
	_apply_top_margins(compact)
	_apply_bottom_margins(compact)
	if channel_picker != null:
		channel_picker.custom_minimum_size = Vector2(88.0, 40.0)

func _bottom_height(compact: bool) -> float:
	var expanded := _is_visible(status_label) or _is_visible(chat_log) or _is_visible(invite_button)
	if compact and expanded:
		return BOTTOM_HEIGHT_EXPANDED_COMPACT
	if expanded:
		return BOTTOM_HEIGHT_EXPANDED
	return BOTTOM_HEIGHT_COMPACT if compact else BOTTOM_HEIGHT

func _apply_top_margins(compact: bool) -> void:
	var top_margin := top_bar.get_node_or_null("TopMargin") as MarginContainer
	var top_row := top_bar.get_node_or_null("TopMargin/TopRow") as HBoxContainer
	if top_margin != null:
		var side_margin := 36 if compact else 40
		var vertical_margin := 2 if compact else 3
		top_margin.add_theme_constant_override("margin_left", side_margin)
		top_margin.add_theme_constant_override("margin_top", vertical_margin)
		top_margin.add_theme_constant_override("margin_right", side_margin)
		top_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	if top_row != null:
		top_row.add_theme_constant_override("separation", 8 if compact else 9)

func _apply_bottom_margins(compact: bool) -> void:
	var bottom_margin := bottom_bar.get_node_or_null("BottomMargin") as MarginContainer
	var bottom_rows := bottom_bar.get_node_or_null("BottomMargin/BottomRows") as VBoxContainer
	if bottom_margin != null:
		var side_margin := 36 if compact else 40
		var vertical_margin := 5 if compact else 6
		bottom_margin.add_theme_constant_override("margin_left", side_margin)
		bottom_margin.add_theme_constant_override("margin_top", vertical_margin)
		bottom_margin.add_theme_constant_override("margin_right", side_margin)
		bottom_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	if bottom_rows != null:
		bottom_rows.add_theme_constant_override("separation", 3)

func _is_visible(control: Control) -> bool:
	return control != null and control.visible
