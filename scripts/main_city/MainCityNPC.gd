class_name MainCityNPC
extends Area2D

signal activated(npc_id: String, action_id: String)

const EmoteBubbleScript := preload("res://scripts/UI/Emotes/OverheadEmoteBubble.gd")
const DEFAULT_HITBOX := Vector2(52, 64)

var npc_id := ""
var action_id := ""
var name_key := ""
var dialogue_key := ""
var emote_id := ""
var sprite_path := ""
var sprite_scale := 0.36

var _sprite: Sprite2D
var _name_label: Label
var _emote_bubble: Node2D

func _ready() -> void:
	add_to_group("main_city_npc")
	input_pickable = true
	_build_nodes()
	if has_node("/root/App"):
		App.locale_changed.connect(_on_locale_changed)
	_refresh()

func setup(record: Dictionary) -> void:
	npc_id = str(record.get("id", ""))
	name = npc_id
	action_id = str(record.get("action_id", ""))
	name_key = str(record.get("name_key", ""))
	dialogue_key = str(record.get("dialogue_key", ""))
	emote_id = str(record.get("emote_id", ""))
	sprite_path = str(record.get("sprite_path", ""))
	sprite_scale = float(record.get("sprite_scale", sprite_scale))
	var position_data: Dictionary = record.get("position", {}) as Dictionary
	position = Vector2(
		float(position_data.get("x", position.x)),
		float(position_data.get("y", position.y))
	)
	if is_node_ready():
		_refresh()

func activate() -> void:
	if not emote_id.is_empty() and _emote_bubble != null:
		_emote_bubble.call("play", emote_id)
	if not npc_id.is_empty():
		activated.emit(npc_id, action_id)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		activate()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		activate()

func _build_nodes() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
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
		_name_label.offset_top = -48
		_name_label.offset_right = 74
		_name_label.offset_bottom = -28
		_name_label.visible = false
		add_child(_name_label)
	if _emote_bubble == null:
		_emote_bubble = Node2D.new()
		_emote_bubble.name = "EmoteBubble"
		_emote_bubble.position = Vector2(0, -58)
		_emote_bubble.set_script(EmoteBubbleScript)
		add_child(_emote_bubble)

func _refresh() -> void:
	if _sprite != null:
		_sprite.texture = _load_texture(sprite_path)
		_sprite.scale = Vector2(sprite_scale, sprite_scale)
	if _name_label != null:
		_name_label.text = App.t_key(name_key) if not name_key.is_empty() else npc_id

func _on_locale_changed(_locale: String) -> void:
	_refresh()

func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	if not path.is_empty():
		push_warning("NPC texture failed to load: %s" % path)
	return null
