extends Node2D

const TILE_SCALE := Vector2(0.58, 0.58)
const TILE_STEP := 56.0

@export var grass_texture: Texture2D
@export var grass_alt_texture: Texture2D
@export var dirt_texture: Texture2D
@export var stone_texture: Texture2D
@export var water_texture: Texture2D
@export var flower_texture: Texture2D
@export var bush_texture: Texture2D
@export var tree_texture: Texture2D

func _ready() -> void:
	_paint_underlay()
	_paint_grass()
	_paint_paths()
	_paint_water()
	_paint_decoration()

func _paint_underlay() -> void:
	_add_underlay(Rect2(-900, -620, 1800, 1240), Color(0.16, 0.36, 0.27, 1.0), -30)
	_add_underlay(Rect2(-410, -235, 820, 470), Color(0.47, 0.43, 0.34, 1.0), -22)
	_add_underlay(Rect2(-115, -470, 230, 940), Color(0.44, 0.34, 0.22, 1.0), -21)
	_add_underlay(Rect2(-760, -82, 1520, 164), Color(0.44, 0.34, 0.22, 1.0), -21)
	_add_underlay(Rect2(-980, 288, 1960, 520), Color(0.12, 0.38, 0.48, 1.0), -20)

func _paint_grass() -> void:
	for grid_x in range(-16, 17):
		for grid_y in range(-11, 12):
			var texture := _pick_grass_texture(grid_x, grid_y)
			_add_tile(texture, Vector2(grid_x, grid_y), -24)

func _paint_paths() -> void:
	for grid_x in range(-7, 8):
		for grid_y in range(-4, 5):
			_add_tile(stone_texture, Vector2(grid_x, grid_y), -18)
	for grid_y in range(-10, -3):
		_add_tile(dirt_texture, Vector2(0, grid_y), -17)
		if grid_y > -9:
			_add_tile(dirt_texture, Vector2(-1, grid_y), -17)
			_add_tile(dirt_texture, Vector2(1, grid_y), -17)
	for grid_y in range(5, 10):
		_add_tile(dirt_texture, Vector2(0, grid_y), -17)
		if grid_y < 9:
			_add_tile(dirt_texture, Vector2(-1, grid_y), -17)
			_add_tile(dirt_texture, Vector2(1, grid_y), -17)
	for grid_x in range(-14, 15):
		if abs(grid_x) > 6:
			_add_tile(dirt_texture, Vector2(grid_x, 0), -17)

func _paint_water() -> void:
	for grid_x in range(-18, 19):
		for grid_y in range(6, 12):
			_add_tile(water_texture, Vector2(grid_x, grid_y), -16)

func _paint_decoration() -> void:
	var decor := [
		{"texture": tree_texture, "position": Vector2(-650, -420), "scale": 0.78, "z": -12},
		{"texture": tree_texture, "position": Vector2(625, -395), "scale": 0.72, "z": -12},
		{"texture": bush_texture, "position": Vector2(-455, -245), "scale": 0.58, "z": -11},
		{"texture": bush_texture, "position": Vector2(515, -240), "scale": 0.56, "z": -11},
		{"texture": flower_texture, "position": Vector2(-312, 118), "scale": 0.46, "z": -10},
		{"texture": flower_texture, "position": Vector2(248, 126), "scale": 0.46, "z": -10},
		{"texture": flower_texture, "position": Vector2(-52, -198), "scale": 0.42, "z": -10},
		{"texture": bush_texture, "position": Vector2(132, -210), "scale": 0.48, "z": -11},
	]
	for record in decor:
		_add_sprite(
			record.get("texture"),
			record.get("position", Vector2.ZERO),
			Vector2.ONE * float(record.get("scale", 1.0)),
			int(record.get("z", -10))
		)

func _pick_grass_texture(grid_x: int, grid_y: int) -> Texture2D:
	if grass_alt_texture != null and abs((grid_x * 31 + grid_y * 17) % 5) == 0:
		return grass_alt_texture
	return grass_texture

func _add_tile(texture: Texture2D, grid_position: Vector2, tile_z_index: int) -> void:
	_add_sprite(texture, grid_position * TILE_STEP, TILE_SCALE, tile_z_index)

func _add_sprite(texture: Texture2D, sprite_position: Vector2, sprite_scale: Vector2, sprite_z_index: int) -> void:
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = sprite_position
	sprite.scale = sprite_scale
	sprite.z_index = sprite_z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func _add_underlay(rect: Rect2, color: Color, underlay_z_index: int) -> void:
	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.z_index = underlay_z_index
	add_child(polygon)
