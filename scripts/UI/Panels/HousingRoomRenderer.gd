class_name HousingRoomRenderer
extends RefCounted

const GRID_SIZE := Vector2i(8, 5)
const TILE_SIZE := 48

var housing_service: Node
var art: RefCounted
var tile_size := float(TILE_SIZE)
var right_reserved := 0.0
var top_safe := 0.0
var bottom_safe := 0.0
var use_safe_layout := false

func configure(new_service: Node, new_art: RefCounted) -> void:
	housing_service = new_service
	art = new_art

func set_responsive_layout(
	new_tile_size: float,
	new_right_reserved: float,
	new_top_safe: float,
	new_bottom_safe: float,
	enabled: bool
) -> void:
	tile_size = maxf(32.0, new_tile_size)
	right_reserved = maxf(0.0, new_right_reserved)
	top_safe = maxf(0.0, new_top_safe)
	bottom_safe = maxf(0.0, new_bottom_safe)
	use_safe_layout = enabled

func draw(
	canvas: Node2D,
	selected_item_id: String,
	selected_placed_item: Dictionary,
	hovered_tile: Vector2i,
	is_visit_mode: bool
) -> void:
	if housing_service == null or art == null:
		return
	_draw_room(canvas)
	_draw_grid(canvas)
	_draw_items(canvas)
	_draw_move_target(canvas, selected_placed_item, hovered_tile, is_visit_mode)
	_draw_selection(canvas, selected_placed_item)
	_draw_placement_preview(canvas, selected_item_id, hovered_tile, is_visit_mode)

func tile_from_position(canvas: Node2D, position: Vector2) -> Vector2i:
	var local := canvas.to_local(position) - grid_origin(_viewport_size(canvas))
	var tile := Vector2i(floori(local.x / tile_size), floori(local.y / tile_size))
	if tile.x < 0 or tile.y < 0 or tile.x >= GRID_SIZE.x or tile.y >= GRID_SIZE.y:
		return Vector2i(-1, -1)
	return tile

func grid_origin(viewport_size: Vector2) -> Vector2:
	var room_size := Vector2(GRID_SIZE) * tile_size
	if use_safe_layout:
		var available_width := maxf(room_size.x, viewport_size.x - right_reserved)
		var wall_height := tile_size * 1.5
		var available_height := maxf(room_size.y, viewport_size.y - top_safe - bottom_safe - wall_height)
		return Vector2(
			floor((available_width - room_size.x) * 0.5),
			top_safe + wall_height + floor((available_height - room_size.y) * 0.5)
		)
	return Vector2(
		floor((viewport_size.x - room_size.x) * 0.5),
		floor((viewport_size.y - room_size.y) * 0.5) + 10.0
	)

func _draw_room(canvas: Node2D) -> void:
	var styles: Dictionary = housing_service.get_styles()
	var origin := grid_origin(_viewport_size(canvas))
	var room_size := Vector2(GRID_SIZE) * tile_size
	var wall_rect := Rect2(
		origin - Vector2(0.0, tile_size * 1.5),
		Vector2(room_size.x, tile_size * 1.5)
	)
	var floor_rect := Rect2(origin, room_size)
	art.draw_surface(
		canvas,
		housing_service.get_item(str(styles.get("wall", "starter_wallpaper"))),
		wall_rect,
		art.style_color(str(styles.get("wall", "starter_wallpaper")))
	)
	art.draw_surface(
		canvas,
		housing_service.get_item(str(styles.get("floor", "wooden_floor"))),
		floor_rect,
		art.style_color(str(styles.get("floor", "wooden_floor")))
	)

func _draw_grid(canvas: Node2D) -> void:
	var origin := grid_origin(_viewport_size(canvas))
	var room_size := Vector2(GRID_SIZE) * tile_size
	for x in range(GRID_SIZE.x + 1):
		var from := origin + Vector2(x * tile_size, 0)
		canvas.draw_line(from, from + Vector2(0, room_size.y), Color(0.2, 0.18, 0.15, 0.35))
	for y in range(GRID_SIZE.y + 1):
		var from := origin + Vector2(0, y * tile_size)
		canvas.draw_line(from, from + Vector2(room_size.x, 0), Color(0.2, 0.18, 0.15, 0.35))

func _draw_items(canvas: Node2D) -> void:
	var origin := grid_origin(_viewport_size(canvas))
	for placed in housing_service.get_placed_items():
		var item: Dictionary = housing_service.get_item(str(placed.get("item_id", "")))
		var tile_data: Dictionary = placed.get("tile", {})
		var tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		art.draw_item(canvas, origin, tile, item, art.item_color(str(item.get("category", ""))))

func _draw_selection(canvas: Node2D, selected_placed_item: Dictionary) -> void:
	if selected_placed_item.is_empty():
		return
	var item: Dictionary = housing_service.get_item(str(selected_placed_item.get("item_id", "")))
	if item.is_empty():
		return
	var tile_data: Dictionary = selected_placed_item.get("tile", {})
	var tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
	art.draw_selection(canvas, grid_origin(_viewport_size(canvas)), tile, item)

func _draw_move_target(
	canvas: Node2D,
	selected_placed_item: Dictionary,
	hovered_tile: Vector2i,
	is_visit_mode: bool
) -> void:
	if is_visit_mode or selected_placed_item.is_empty() or hovered_tile.x < 0:
		return
	var item_id := str(selected_placed_item.get("item_id", ""))
	var item: Dictionary = housing_service.get_item(item_id)
	if item.is_empty():
		return
	var rotation := int(selected_placed_item.get("rotation", 0))
	art.draw_move_target(
		canvas,
		grid_origin(_viewport_size(canvas)),
		hovered_tile,
		item,
		housing_service.can_move_item_to(selected_placed_item, hovered_tile, rotation)
	)

func _draw_placement_preview(
	canvas: Node2D,
	selected_item_id: String,
	hovered_tile: Vector2i,
	is_visit_mode: bool
) -> void:
	if is_visit_mode or selected_item_id.is_empty() or hovered_tile.x < 0:
		return
	var item: Dictionary = housing_service.get_item(selected_item_id)
	art.draw_preview(
		canvas,
		grid_origin(_viewport_size(canvas)),
		hovered_tile,
		item,
		housing_service.can_place_item(selected_item_id, hovered_tile)
	)

func _viewport_size(canvas: Node2D) -> Vector2:
	var viewport_size := canvas.get_viewport_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		return viewport_size
	return Vector2(DisplayServer.window_get_size())
