class_name HousingLayoutRules
extends RefCounted

static func can_place(
	catalog: Dictionary,
	placed_items: Array[Dictionary],
	grid_size: Vector2i,
	item_id: String,
	tile: Vector2i,
	rotation: int = 0,
	excluded_index: int = -1
) -> bool:
	if not catalog.has(item_id):
		return false
	var item: Dictionary = catalog[item_id]
	if str(item.get("item_type", "")) == "surface":
		return true
	if not tile_inside_bounds(tile, item_size_for_rotation(item, rotation), grid_size):
		return false
	return not is_tile_occupied(catalog, placed_items, item_id, tile, rotation, excluded_index)

static func item_at_tile(
	catalog: Dictionary,
	placed_items: Array[Dictionary],
	tile: Vector2i
) -> Dictionary:
	var index := placed_index_at_tile(catalog, placed_items, tile)
	if index < 0:
		return {}
	return placed_items[index].duplicate(true)

static func placement_error_key(
	catalog: Dictionary,
	grid_size: Vector2i,
	item_id: String,
	tile: Vector2i,
	rotation: int = 0
) -> String:
	var item: Dictionary = catalog.get(item_id, {})
	if not tile_inside_bounds(tile, item_size_for_rotation(item, rotation), grid_size):
		return "housing.error.invalid_placement"
	return "housing.error.occupied_tile"

static func placed_index(placed_items: Array[Dictionary], item: Dictionary) -> int:
	var tile: Dictionary = item.get("tile", {})
	for index in range(placed_items.size()):
		var placed: Dictionary = placed_items[index]
		var placed_tile: Dictionary = placed.get("tile", {})
		if str(placed.get("item_id", "")) == str(item.get("item_id", "")) and \
			int(placed_tile.get("x", 0)) == int(tile.get("x", 0)) and \
			int(placed_tile.get("y", 0)) == int(tile.get("y", 0)) and \
			normalize_rotation(int(placed.get("rotation", 0))) == normalize_rotation(int(item.get("rotation", 0))):
			return index
	return -1

static func placed_index_at_tile(
	catalog: Dictionary,
	placed_items: Array[Dictionary],
	tile: Vector2i
) -> int:
	for index in range(placed_items.size() - 1, -1, -1):
		var placed: Dictionary = placed_items[index]
		var item: Dictionary = catalog.get(str(placed.get("item_id", "")), {})
		var tile_data: Dictionary = placed.get("tile", {})
		var placed_tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var rect := Rect2i(placed_tile, item_size_for_rotation(item, int(placed.get("rotation", 0))))
		if rect.has_point(tile):
			return index
	return -1

static func item_size(item: Dictionary) -> Vector2i:
	var size_data: Dictionary = item.get("size", {})
	return Vector2i(
		maxi(1, int(size_data.get("width", 1))),
		maxi(1, int(size_data.get("height", 1)))
	)

static func item_size_for_rotation(item: Dictionary, rotation: int) -> Vector2i:
	var size := item_size(item)
	var normalized := normalize_rotation(rotation)
	if bool(item.get("rotatable", false)) and (normalized == 90 or normalized == 270):
		return Vector2i(size.y, size.x)
	return size

static func normalize_rotation(rotation: int) -> int:
	return posmod(rotation, 360)

static func tile_inside_bounds(tile: Vector2i, size: Vector2i, grid_size: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0:
		return false
	return tile.x + size.x <= grid_size.x and tile.y + size.y <= grid_size.y

static func is_tile_occupied(
	catalog: Dictionary,
	placed_items: Array[Dictionary],
	item_id: String,
	tile: Vector2i,
	rotation: int,
	excluded_index: int
) -> bool:
	var item: Dictionary = catalog[item_id]
	var target := Rect2i(tile, item_size_for_rotation(item, rotation))
	for index in range(placed_items.size()):
		if index == excluded_index:
			continue
		var placed: Dictionary = placed_items[index]
		var placed_id := str(placed.get("item_id", ""))
		var placed_item: Dictionary = catalog.get(placed_id, {})
		if placed_item.is_empty() or str(placed_item.get("item_type", "")) == "surface":
			continue
		var tile_data: Dictionary = placed.get("tile", {})
		var placed_tile := Vector2i(int(tile_data.get("x", 0)), int(tile_data.get("y", 0)))
		var placed_rotation := int(placed.get("rotation", 0))
		var placed_rect := Rect2i(placed_tile, item_size_for_rotation(placed_item, placed_rotation))
		if target.intersects(placed_rect):
			return true
	return false
