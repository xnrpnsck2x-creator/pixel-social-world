class_name OverheadEmoteBubble
extends Node2D

const EmoteCatalogScript := preload("res://scripts/Systems/Emotes/EmoteCatalog.gd")

@export var pixel_scale := 0.42
@export var rise_distance := 18.0
@export var hold_seconds := 1.15

var _sprite: Sprite2D
var _tween: Tween

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	visible = false

func play(emote_id: String) -> void:
	if _sprite == null:
		return

	var texture: Texture2D = EmoteCatalogScript.load_texture(emote_id)
	if texture == null:
		return

	_sprite.texture = texture
	visible = true
	_reset_sprite()

	if _tween != null:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_sprite, "modulate:a", 1.0, 0.1)
	_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE * pixel_scale, 0.16).from(Vector2.ONE * 0.24)
	_tween.parallel().tween_property(_sprite, "position", Vector2(0, -rise_distance), 0.16)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_sprite, "modulate:a", 0.0, 0.22)
	_tween.parallel().tween_property(_sprite, "position", Vector2(0, -rise_distance - 8.0), 0.22)
	_tween.tween_callback(_hide)

func _reset_sprite() -> void:
	_sprite.position = Vector2.ZERO
	_sprite.scale = Vector2.ONE * 0.24
	_sprite.modulate = Color(1, 1, 1, 0)

func _hide() -> void:
	visible = false
