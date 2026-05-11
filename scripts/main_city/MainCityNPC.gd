class_name MainCityNPC
extends Area2D

signal activated(npc_id: String, action_id: String)

const EmoteBubbleScript := preload("res://scripts/UI/Emotes/OverheadEmoteBubble.gd")
const DEFAULT_HITBOX := Vector2(52, 64)
const DEFAULT_SHADOW_SIZE := Vector2(32, 10)
const DEFAULT_SHADOW_COLOR := Color(0.04, 0.035, 0.03, 0.30)
const DIRECTIONS := ["down", "right", "up", "left"]
const NAME_REVEAL_SECONDS := 1.8

var npc_id := ""
var action_id := ""
var name_key := ""
var dialogue_key := ""
var role_key := ""
var emote_id := ""
var sprite_path := ""
var sprite_scale := 0.36
var npc_visual_id := ""
var avatar_id := ""
var pose := "idle"
var facing := "down"

var _shadow: Polygon2D
var _sprite: Sprite2D
var _name_label: Label
var _emote_bubble: Node2D
var _name_reveal_left := 0.0
var _attention_left := 0.0
var _home_facing := "down"
var _sprite_scale_overridden := false

func _ready() -> void:
	add_to_group("main_city_npc")
	input_pickable = true
	_build_nodes()
	set_process(false)
	var app := _app()
	if app != null:
		app.locale_changed.connect(_on_locale_changed)
	_refresh()

func _process(delta: float) -> void:
	if _name_reveal_left > 0.0:
		_name_reveal_left = max(0.0, _name_reveal_left - delta)
		if _name_reveal_left <= 0.0:
			hide_name()
	if _attention_left > 0.0:
		_attention_left = max(0.0, _attention_left - delta)
		if _attention_left <= 0.0 and facing != _home_facing:
			facing = _home_facing
			_refresh()
	if _name_reveal_left <= 0.0 and _attention_left <= 0.0:
		set_process(false)

func setup(record: Dictionary) -> void:
	npc_id = str(record.get("id", ""))
	name = npc_id
	action_id = str(record.get("action_id", ""))
	name_key = str(record.get("name_key", ""))
	dialogue_key = str(record.get("dialogue_key", ""))
	role_key = str(record.get("role_key", ""))
	emote_id = str(record.get("emote_id", ""))
	sprite_path = str(record.get("sprite_path", ""))
	npc_visual_id = str(record.get("npc_visual_id", ""))
	_sprite_scale_overridden = record.has("sprite_scale")
	sprite_scale = float(record.get("sprite_scale", sprite_scale))
	avatar_id = str(record.get("avatar_id", ""))
	pose = str(record.get("pose", "idle"))
	facing = str(record.get("facing", "down"))
	if not DIRECTIONS.has(facing):
		facing = "down"
	_home_facing = facing
	var position_data: Dictionary = record.get("position", {}) as Dictionary
	position = Vector2(
		float(position_data.get("x", position.x)),
		float(position_data.get("y", position.y))
	)
	if is_node_ready():
		_refresh()

func activate() -> void:
	reveal_name()
	if not emote_id.is_empty() and _emote_bubble != null:
		_emote_bubble.call("play", emote_id)
	if not npc_id.is_empty():
		activated.emit(npc_id, action_id)

func reveal_name(seconds: float = NAME_REVEAL_SECONDS) -> void:
	if _name_label == null:
		return
	_name_reveal_left = max(0.1, seconds)
	_name_label.visible = true
	set_process(true)

func face_toward(target_position: Vector2, seconds: float = 1.6, reveal := true) -> void:
	var offset := target_position - global_position
	if offset.length_squared() <= 1.0:
		return
	facing = _direction_from_delta(offset)
	_attention_left = max(0.1, seconds)
	_refresh()
	if reveal: reveal_name(seconds)
	else: set_process(true)

func hide_name() -> void:
	_name_reveal_left = 0.0
	if _name_label != null:
		_name_label.visible = false
	if _attention_left <= 0.0:
		set_process(false)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		activate()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		activate()

func _build_nodes() -> void:
	if _shadow == null:
		_shadow = Polygon2D.new()
		_shadow.name = "Shadow"
		_shadow.color = DEFAULT_SHADOW_COLOR
		_shadow.polygon = _ellipse_polygon(DEFAULT_SHADOW_SIZE, 12)
		_shadow.position = Vector2(0, 21)
		add_child(_shadow)
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		move_child(_sprite, min(1, get_child_count() - 1))
	if get_node_or_null("Hitbox") == null:
		var hitbox := CollisionShape2D.new()
		hitbox.name = "Hitbox"
		var shape := RectangleShape2D.new()
		shape.size = DEFAULT_HITBOX
		hitbox.shape = shape
		hitbox.position = Vector2(0, -18)
		add_child(hitbox)
	if _name_label == null:
		_name_label = Label.new()
		_name_label.name = "NameLabel"
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.offset_left = -74
		_name_label.offset_top = -58
		_name_label.offset_right = 74
		_name_label.offset_bottom = -24
		_name_label.visible = false
		_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
		_name_label.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.03, 0.95))
		_name_label.add_theme_constant_override("outline_size", 3)
		add_child(_name_label)
	if _emote_bubble == null:
		_emote_bubble = Node2D.new()
		_emote_bubble.name = "EmoteBubble"
		_emote_bubble.position = Vector2(0, -28)
		_emote_bubble.set_script(EmoteBubbleScript)
		add_child(_emote_bubble)

func _refresh() -> void:
	var role_config := _npc_profession_config()
	if not _sprite_scale_overridden and role_config.has("sprite_scale"):
		sprite_scale = float(role_config.get("sprite_scale", sprite_scale))
	if _sprite != null:
		_sprite.texture = _resolve_texture(role_config)
		_sprite.scale = Vector2(sprite_scale, sprite_scale)
		_sprite.position = Vector2(0, 5)
		_sprite.flip_h = false
	if _shadow != null:
		_shadow.visible = _sprite != null and _sprite.texture != null
	if _name_label != null:
		_name_label.text = _localized_nameplate()

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _load_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	if not path.is_empty():
		push_warning("NPC texture failed to load: %s" % path)
	return null

func _resolve_texture(role_config: Dictionary = {}) -> Texture2D:
	var npc_texture := _npc_profession_texture(role_config)
	if npc_texture != null:
		return npc_texture
	var avatar_texture := _avatar_texture()
	if avatar_texture != null:
		return avatar_texture
	return _load_texture(sprite_path)

func _npc_profession_texture(config: Dictionary = {}) -> Texture2D:
	if config.is_empty():
		config = _npc_profession_config()
	if config.is_empty():
		return null
	var frame_path := str(config.get("frame_path", ""))
	var directional_path := _directional_npc_frame_path(frame_path)
	if directional_path != frame_path:
		if ResourceLoader.exists(directional_path):
			var directional_texture := _load_texture(directional_path)
			if directional_texture != null:
				return directional_texture
		if facing != "down":
			return null
	return _load_texture(frame_path)

func _directional_npc_frame_path(frame_path: String) -> String:
	if frame_path.is_empty():
		return frame_path
	var suffix := "_idle_down.png"
	if not frame_path.ends_with(suffix):
		return frame_path
	return frame_path.substr(0, frame_path.length() - suffix.length()) + "_%s_%s.png" % [pose, facing]

func _npc_profession_config() -> Dictionary:
	if npc_visual_id.is_empty():
		return {}
	var data := _load_config("npc_professions")
	for role in data.get("roles", []):
		if typeof(role) == TYPE_DICTIONARY and str((role as Dictionary).get("id", "")) == npc_visual_id:
			return (role as Dictionary).duplicate(true)
	return {}

func _avatar_texture() -> Texture2D:
	if avatar_id.is_empty():
		return null
	var config := _avatar_config()
	if config.is_empty():
		return null
	var animations: Dictionary = config.get("animations", {}) as Dictionary
	var animation_name := "%s_%s" % [pose, facing]
	if not animations.has(animation_name):
		animation_name = "%s_down" % pose
	if not animations.has(animation_name):
		return null
	var animation: Dictionary = animations.get(animation_name, {}) as Dictionary
	for frame_path in animation.get("frames", []):
		var texture := _load_texture(str(frame_path))
		if texture != null:
			return texture
	return null

func _avatar_config() -> Dictionary:
	var data := _load_config("player_animations")
	for avatar in data.get("avatars", []):
		if typeof(avatar) == TYPE_DICTIONARY and str((avatar as Dictionary).get("id", "")) == avatar_id:
			return (avatar as Dictionary).duplicate(true)
	return {}

func _localized_name() -> String:
	var app := _app()
	if app != null and not name_key.is_empty() and app.has_method("t_key"):
		return str(app.call("t_key", name_key))
	return npc_id

func _localized_nameplate() -> String:
	var role := _localized_role()
	if role.is_empty():
		return _localized_name()
	return "%s\n%s" % [_localized_name(), role]

func _localized_role() -> String:
	var app := _app()
	if app != null and not role_key.is_empty() and app.has_method("t_key"):
		return str(app.call("t_key", role_key))
	return ""

func _load_config(config_id: String) -> Dictionary:
	if not is_inside_tree():
		return {}
	var loader := get_tree().root.get_node_or_null("ConfigLoader")
	if loader != null and loader.has_method("load_config"):
		return loader.call("load_config", config_id) as Dictionary
	return {}

func _app() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("App")

func _direction_from_delta(offset: Vector2) -> String:
	if abs(offset.x) > abs(offset.y):
		return "right" if offset.x > 0.0 else "left"
	return "down" if offset.y > 0.0 else "up"

func _ellipse_polygon(size: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	return points
