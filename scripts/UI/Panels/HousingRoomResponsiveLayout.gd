class_name HousingRoomResponsiveLayout
extends RefCounted

const COMPACT_HEIGHT := 560.0
const COMPACT_SOCIAL_WIDTH := 236.0
const COMPACT_SOCIAL_RIGHT_INSET := 26.0

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
	var viewport_size := root.get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(DisplayServer.window_get_size())
	var compact := viewport_size.y <= COMPACT_HEIGHT
	_layout_top(top_panel, owner_label, invite_button, compact, is_visit_mode, viewport_size)
	_layout_social(social_panel, compact)
	_layout_catalog(catalog_bar, compact, viewport_size)
	var tile_size := 36.0 if compact else 48.0
	var right_reserved := COMPACT_SOCIAL_WIDTH + COMPACT_SOCIAL_RIGHT_INSET + 12.0 if compact else 0.0
	var top_safe := 50.0 if compact else 0.0
	var bottom_safe := 96.0 if compact else 0.0
	if renderer != null and renderer.has_method("set_responsive_layout"):
		renderer.call("set_responsive_layout", tile_size, right_reserved, top_safe, bottom_safe, compact)
	if art != null and art.has_method("set_tile_size"):
		art.call("set_tile_size", tile_size)

func _layout_top(
	top_panel: Control,
	owner_label: Label,
	invite_button: Button,
	compact: bool,
	is_visit_mode: bool,
	viewport_size: Vector2
) -> void:
	var max_width := 760.0 if compact else 920.0
	var panel_width := minf(viewport_size.x - 20.0, max_width)
	top_panel.anchor_left = 0.0
	top_panel.anchor_right = 0.0
	top_panel.offset_left = 10.0 if compact else 14.0
	top_panel.offset_top = 8.0 if compact else 10.0
	top_panel.offset_right = top_panel.offset_left + panel_width
	top_panel.offset_bottom = 44.0 if compact else 52.0
	if owner_label != null:
		owner_label.visible = not compact
	if invite_button != null:
		invite_button.visible = (not compact) and (not is_visit_mode)
	for child in top_panel.find_children("*", "Button", true, false):
		(child as Button).custom_minimum_size = Vector2(96, 28) if compact else Vector2.ZERO

func _layout_social(social_panel: Control, compact: bool) -> void:
	var width := COMPACT_SOCIAL_WIDTH if compact else 276.0
	var right_inset := COMPACT_SOCIAL_RIGHT_INSET if compact else 14.0
	social_panel.anchor_left = 1.0
	social_panel.anchor_right = 1.0
	social_panel.anchor_top = 0.0
	social_panel.anchor_bottom = 0.0
	social_panel.offset_left = -width - right_inset
	social_panel.offset_top = 54.0 if compact else 72.0
	social_panel.offset_right = -right_inset
	social_panel.offset_bottom = 198.0 if compact else 244.0
	if social_panel.has_method("set_compact_layout"):
		social_panel.call("set_compact_layout", compact)

func _layout_catalog(catalog_bar: Control, compact: bool, viewport_size: Vector2) -> void:
	var max_width := 620.0 if compact else 980.0
	var panel_width := minf(viewport_size.x - 20.0, max_width)
	catalog_bar.anchor_left = 0.0
	catalog_bar.anchor_right = 0.0
	catalog_bar.offset_left = 10.0 if compact else 14.0
	catalog_bar.offset_top = -116.0 if compact else -104.0
	catalog_bar.offset_right = catalog_bar.offset_left + panel_width
	catalog_bar.offset_bottom = -28.0 if compact else -10.0
	if catalog_bar.has_method("set_compact_layout"):
		catalog_bar.call("set_compact_layout", compact)
