class_name HousingRoomArt
extends RefCounted

const TILE_SIZE := 48.0
const ITEM_PADDING := 4.0

var _texture_cache: Dictionary = {}
var tile_size := TILE_SIZE

func set_tile_size(size: float) -> void:
	tile_size = maxf(32.0, size)

func item_texture(item: Dictionary) -> Texture2D:
	var path := str(item.get("icon_path", ""))
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		_texture_cache[path] = resource
		return resource as Texture2D
	push_warning("Unable to load housing item texture: %s" % path)
	return null

func draw_surface(canvas: CanvasItem, item: Dictionary, rect: Rect2, fallback: Color) -> void:
	var texture := item_texture(item)
	if texture == null:
		canvas.draw_rect(rect, fallback)
		return
	canvas.draw_texture_rect(texture, rect, true, Color(1, 1, 1, 0.86))
	canvas.draw_rect(rect, Color(0.23, 0.18, 0.13, 0.2), false, 2.0)

func draw_item(canvas: CanvasItem, origin: Vector2, tile: Vector2i, item: Dictionary, fallback: Color) -> void:
	var cell_rect := _cell_rect(origin, tile, item_size(item), ITEM_PADDING)
	var texture := item_texture(item)
	if texture == null:
		canvas.draw_rect(cell_rect, fallback)
		return
	var draw_rect := _fit_rect(cell_rect, texture.get_size())
	_draw_shadow(canvas, draw_rect)
	canvas.draw_texture_rect(texture, draw_rect, false)

func draw_preview(canvas: CanvasItem, origin: Vector2, tile: Vector2i, item: Dictionary, is_valid: bool) -> void:
	if tile.x < 0:
		return
	var rect := _cell_rect(origin, tile, item_size(item), 2.0)
	var fill := Color(0.95, 0.84, 0.35, 0.24) if is_valid else Color(0.92, 0.2, 0.16, 0.24)
	var border := Color(1.0, 0.91, 0.45, 0.9) if is_valid else Color(1.0, 0.28, 0.24, 0.9)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0)
	var texture := item_texture(item)
	if texture == null:
		return
	canvas.draw_texture_rect(texture, _fit_rect(rect.grow(-4.0), texture.get_size()), false, Color(1, 1, 1, 0.62))

func draw_move_target(canvas: CanvasItem, origin: Vector2, tile: Vector2i, item: Dictionary, is_valid: bool) -> void:
	if tile.x < 0:
		return
	var rect := _cell_rect(origin, tile, item_size(item), 2.0)
	var fill := Color(0.28, 0.76, 0.58, 0.22) if is_valid else Color(0.92, 0.2, 0.16, 0.18)
	var border := Color(0.42, 0.95, 0.74, 0.9) if is_valid else Color(1.0, 0.28, 0.24, 0.82)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0)
	var texture := item_texture(item)
	if texture != null:
		canvas.draw_texture_rect(texture, _fit_rect(rect.grow(-6.0), texture.get_size()), false, Color(1, 1, 1, 0.44))
	_draw_move_marker(canvas, rect, border)

func draw_selection(canvas: CanvasItem, origin: Vector2, tile: Vector2i, item: Dictionary) -> void:
	var rect := _cell_rect(origin, tile, item_size(item), 1.0)
	canvas.draw_rect(rect, Color(1.0, 0.86, 0.28, 0.18))
	canvas.draw_rect(rect, Color(1.0, 0.86, 0.28, 0.95), false, 3.0)
	_draw_corner_handles(canvas, rect)
	_draw_move_marker(canvas, rect, Color(1.0, 0.91, 0.45, 0.95))

func item_size(item: Dictionary) -> Vector2i:
	var size_data: Dictionary = item.get("size", {})
	return Vector2i(
		maxi(1, int(size_data.get("width", 1))),
		maxi(1, int(size_data.get("height", 1)))
	)

func style_color(item_id: String) -> Color:
	if item_id == "starter_wallpaper":
		return Color(0.74, 0.61, 0.45)
	return Color(0.63, 0.55, 0.42)

func item_color(category: String) -> Color:
	match category:
		"seat":
			return Color(0.42, 0.64, 0.83)
		"table":
			return Color(0.55, 0.34, 0.18)
		"plant":
			return Color(0.26, 0.58, 0.32)
		"activity":
			return Color(0.48, 0.38, 0.64)
	return Color(0.8, 0.7, 0.55)

func _cell_rect(origin: Vector2, tile: Vector2i, size: Vector2i, padding: float) -> Rect2:
	return Rect2(
		origin + Vector2(tile) * tile_size + Vector2(padding, padding),
		Vector2(size) * tile_size - Vector2(padding * 2.0, padding * 2.0)
	)

func _fit_rect(container: Rect2, texture_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return container
	var scale := minf(container.size.x / texture_size.x, container.size.y / texture_size.y)
	var size := texture_size * scale
	return Rect2(container.position + (container.size - size) * 0.5, size)

func _draw_shadow(canvas: CanvasItem, rect: Rect2) -> void:
	var shadow := Rect2(
		rect.position + Vector2(5.0, rect.size.y - 6.0),
		Vector2(maxf(6.0, rect.size.x - 10.0), 5.0)
	)
	canvas.draw_rect(shadow, Color(0.08, 0.07, 0.05, 0.26))

func _draw_corner_handles(canvas: CanvasItem, rect: Rect2) -> void:
	var size := 8.0
	var points := [
		rect.position,
		rect.position + Vector2(rect.size.x - size, 0.0),
		rect.position + Vector2(0.0, rect.size.y - size),
		rect.end - Vector2(size, size)
	]
	for point in points:
		canvas.draw_rect(Rect2(point, Vector2(size, size)), Color(0.18, 0.12, 0.06, 0.72))
		canvas.draw_rect(Rect2(point + Vector2.ONE, Vector2(size - 2.0, size - 2.0)), Color(1.0, 0.91, 0.45, 0.94))

func _draw_move_marker(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var center := rect.position + Vector2(rect.size.x * 0.5, maxf(11.0, rect.size.y * 0.22))
	var radius := 7.0
	canvas.draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), color, 2.0)
	canvas.draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), color, 2.0)
	canvas.draw_line(center - Vector2(radius, 0.0), center - Vector2(radius - 3.0, -3.0), color, 2.0)
	canvas.draw_line(center - Vector2(radius, 0.0), center - Vector2(radius - 3.0, 3.0), color, 2.0)
	canvas.draw_line(center + Vector2(radius, 0.0), center + Vector2(radius - 3.0, -3.0), color, 2.0)
	canvas.draw_line(center + Vector2(radius, 0.0), center + Vector2(radius - 3.0, 3.0), color, 2.0)
