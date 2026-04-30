class_name HousingRoomResponsiveLayout
extends RefCounted

const COMPACT_HEIGHT := 480.0

func apply(
	root: Node2D,
	top_panel: Control,
	owner_label: Label,
	invite_button: Button,
	social_panel: Control,
	catalog_bar: Control,
	renderer: RefCounted,
	art: RefCounted,
	is_visit_mode: bool
) -> void:
	var viewport_size := Vector2(DisplayServer.window_get_size())
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = root.get_viewport_rect().size
	var compact := viewport_size.y <= COMPACT_HEIGHT
	_layout_top(top_panel, owner_label, invite_button, compact, is_visit_mode)
	_layout_social(social_panel, compact)
	_layout_catalog(catalog_bar, compact)
	var tile_size := 36.0 if compact else 48.0
	var right_reserved := 224.0 if compact else 0.0
	var top_safe := 54.0 if compact else 0.0
	var bottom_safe := 86.0 if compact else 0.0
	if renderer != null and renderer.has_method("set_responsive_layout"):
		renderer.call("set_responsive_layout", tile_size, right_reserved, top_safe, bottom_safe, compact)
	if art != null and art.has_method("set_tile_size"):
		art.call("set_tile_size", tile_size)

func _layout_top(
	top_panel: Control,
	owner_label: Label,
	invite_button: Button,
	compact: bool,
	is_visit_mode: bool
) -> void:
	top_panel.offset_left = 10.0 if compact else 14.0
	top_panel.offset_top = 8.0 if compact else 10.0
	top_panel.offset_right = -10.0 if compact else -14.0
	top_panel.offset_bottom = 48.0 if compact else 58.0
	if owner_label != null:
		owner_label.visible = not compact
	if invite_button != null:
		invite_button.visible = (not compact) and (not is_visit_mode)
	for child in top_panel.find_children("*", "Button", true, false):
		(child as Button).custom_minimum_size = Vector2(58, 30) if compact else Vector2.ZERO

func _layout_social(social_panel: Control, compact: bool) -> void:
	var width := 214.0 if compact else 276.0
	social_panel.offset_left = -width - 10.0 if compact else -width - 14.0
	social_panel.offset_top = 54.0 if compact else 72.0
	social_panel.offset_right = -10.0 if compact else -14.0
	social_panel.offset_bottom = 218.0 if compact else 244.0
	if social_panel.has_method("set_compact_layout"):
		social_panel.call("set_compact_layout", compact)

func _layout_catalog(catalog_bar: Control, compact: bool) -> void:
	catalog_bar.offset_left = 10.0 if compact else 14.0
	catalog_bar.offset_top = -86.0 if compact else -118.0
	catalog_bar.offset_right = -10.0 if compact else -14.0
	catalog_bar.offset_bottom = -8.0 if compact else -10.0
	if catalog_bar.has_method("set_compact_layout"):
		catalog_bar.call("set_compact_layout", compact)
