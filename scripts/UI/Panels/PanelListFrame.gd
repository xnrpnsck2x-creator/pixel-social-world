class_name PanelListFrame
extends RefCounted

const CARD_FILL := Color(0.84, 0.64, 0.32, 0.13)
const CARD_BORDER := Color(0.35, 0.20, 0.09, 0.24)

func add_hbox(parent: Control, compact: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6 if compact else 8)
	return _add_card(parent, row, 3 if compact else 5) as HBoxContainer

func add_vbox(parent: Control, compact: bool) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1 if compact else 3)
	return _add_card(parent, row, 3 if compact else 5) as VBoxContainer

func add_section(parent: Control, compact: bool, minimum_size: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if compact else 6)
	var card := _add_card(parent, box, 7 if compact else 9) as VBoxContainer
	(card.get_parent().get_parent() as PanelContainer).custom_minimum_size = minimum_size
	return card

func _add_card(parent: Control, content: Control, inset: int) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style())
	parent.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", inset)
	margin.add_theme_constant_override("margin_top", inset)
	margin.add_theme_constant_override("margin_right", inset)
	margin.add_theme_constant_override("margin_bottom", inset)
	card.add_child(margin)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	return content

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_FILL
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
