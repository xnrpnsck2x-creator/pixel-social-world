class_name PlayerAvatar
extends CharacterBody2D
signal profile_requested(profile: Dictionary)

const PlayerAvatarNameplateScript := preload("res://scripts/Entities/Player/PlayerAvatarNameplate.gd")
const PlayerAvatarConfigScript := preload("res://scripts/Entities/Player/PlayerAvatarConfig.gd")
const PlayerAvatarAttackFeedbackScript := preload("res://scripts/Entities/Player/PlayerAvatarAttackFeedback.gd")
@export var speed := 120.0
@export var input_enabled := true:
	set(value):
		input_enabled = value
		if is_node_ready():
			_sync_process_flags()
@export var remote_interpolation_speed := 12.0
const DIRECTIONS := ["down", "right", "up", "left"]
const ATTACK_SECONDS := 0.32
const NAME_REVEAL_SECONDS := 3.0
const NAME_HIT_RADIUS := 26.0
var display_name := "":
	set(value):
		display_name = value
		if is_node_ready():
			_refresh_name()
var player_id := ""
var character_variant_id := ""
var facing := "down"
var _is_sitting := false
var _attack_time_left := 0.0
var _current_animation := ""
var _sprite: AnimatedSprite2D
var _body: CanvasItem
var _target_global_position := Vector2.ZERO
var _has_remote_target := false
var _remote_initialized := false
var _nameplate
var _movement_validator := Callable()
@onready var name_label: Label = get_node_or_null("NameLabel") as Label
@onready var emote_bubble: Node = get_node_or_null("EmoteBubble")
func _ready() -> void:
	_body = get_node_or_null("Body") as CanvasItem
	_setup_sprite()
	_nameplate = PlayerAvatarNameplateScript.new()
	_nameplate.bind(self, name_label, NAME_REVEAL_SECONDS, NAME_HIT_RADIUS)
	_refresh_name()
	_nameplate.hide()
	_play_action("idle")
	_sync_process_flags()
func _process(delta: float) -> void:
	if _nameplate != null:
		_nameplate.tick(delta)
	if input_enabled or not _has_remote_target:
		_sync_process_flags()
		return
	var weight: float = clamp(delta * remote_interpolation_speed, 0.0, 1.0)
	global_position = global_position.lerp(_target_global_position, weight)
	if global_position.distance_to(_target_global_position) <= 0.5:
		global_position = _target_global_position
		_has_remote_target = false
	_sync_process_flags()
func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		_play_action("sit" if _is_sitting else "idle")
		return

	if Input.is_action_just_pressed("ui_accept"):
		start_attack()

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction.length() > 0.01:
		facing = _direction_from_vector(direction)
		if _is_sitting:
			stand_up()

	if _attack_time_left > 0.0:
		_attack_time_left -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		if _attack_time_left <= 0.0:
			_play_action("idle")
		return

	if _is_sitting:
		velocity = Vector2.ZERO
		_play_action("sit")
		move_and_slide()
		return

	velocity = _validated_velocity(direction, delta)
	if direction.length() > 0.01:
		_play_action("walk")
	else:
		_play_action("idle")
	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if _handle_name_reveal_input(event):
		return
	if not input_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_X:
		toggle_sit()
	elif key_event.keycode == KEY_Z:
		start_attack()

func start_attack() -> void:
	if _attack_time_left > 0.0:
		return
	_is_sitting = false
	_attack_time_left = ATTACK_SECONDS
	_play_action("attack")
	var config := _avatar_config()
	PlayerAvatarAttackFeedbackScript.new().play(self, _sprite, config, facing)
	var attack_emote_id := str(config.get("attack_emote_id", ""))
	if not attack_emote_id.is_empty():
		show_emote(attack_emote_id)

func toggle_sit() -> void:
	if _is_sitting:
		stand_up()
	else:
		sit_down()

func sit_down() -> void:
	if _attack_time_left > 0.0:
		return
	_is_sitting = true
	velocity = Vector2.ZERO
	_play_action("sit")

func stand_up() -> void:
	_is_sitting = false
	_play_action("idle")

func apply_remote_state(state: Dictionary) -> void:
	if state.has("display_name"):
		display_name = str(state.get("display_name", display_name))
	var next_variant := str(state.get("character_variant_id", character_variant_id))
	if not next_variant.is_empty() and next_variant != character_variant_id:
		character_variant_id = next_variant
		_setup_sprite()
	if state.has("position"):
		var raw_position: Variant = state.get("position")
		var next_position := global_position
		if typeof(raw_position) == TYPE_VECTOR2:
			next_position = raw_position
		elif typeof(raw_position) == TYPE_DICTIONARY:
			var position_data: Dictionary = raw_position as Dictionary
			next_position = Vector2(float(position_data.get("x", global_position.x)), float(position_data.get("y", global_position.y)))
		if input_enabled or not _remote_initialized:
			global_position = next_position
			_remote_initialized = true
		_target_global_position = next_position
		_has_remote_target = not input_enabled and global_position.distance_to(_target_global_position) > 0.5
		_sync_process_flags()
	if DIRECTIONS.has(str(state.get("facing", ""))):
		facing = str(state.get("facing", facing))
	_is_sitting = bool(state.get("is_sitting", _is_sitting))
	if bool(state.get("is_attacking", false)):
		start_attack()
	else:
		_play_action("sit" if _is_sitting else "idle")

func get_avatar_state() -> Dictionary:
	return {
		"facing": facing,
		"character_variant_id": character_variant_id,
		"is_sitting": _is_sitting,
		"is_attacking": _attack_time_left > 0.0,
		"animation": _current_animation,
		"position": {"x": global_position.x, "y": global_position.y},
		"velocity": {"x": velocity.x, "y": velocity.y}
	}

func _refresh_name() -> void:
	if _nameplate != null:
		_nameplate.refresh(display_name)

func reveal_name(seconds: float = NAME_REVEAL_SECONDS) -> void:
	if _nameplate != null:
		_nameplate.reveal(display_name, seconds)
	_sync_process_flags()

func hide_name() -> void:
	if _nameplate != null:
		_nameplate.hide()
	_sync_process_flags()

func show_emote(emote_id: String) -> void:
	if emote_bubble != null and emote_bubble.has_method("play"):
		emote_bubble.play(emote_id)

func set_movement_validator(validator: Callable) -> void:
	_movement_validator = validator

func can_enter_world_position(position: Vector2) -> bool:
	return not _movement_validator.is_valid() or bool(_movement_validator.call(position))

func _handle_name_reveal_input(event: InputEvent) -> bool:
	if _nameplate == null:
		return false
	var result: Dictionary = _nameplate.handle_input(event, input_enabled, player_id, display_name)
	if typeof(result.get("profile")) == TYPE_DICTIONARY:
		var profile := (result.get("profile") as Dictionary).duplicate(true)
		var config := _avatar_config()
		profile["character_variant_id"] = character_variant_id
		profile["avatar_id"] = str(config.get("avatar_id", ""))
		profile["gender_id"] = str(config.get("gender_id", ""))
		profile["class_id"] = str(config.get("class_id", ""))
		profile["character_name_key"] = str(config.get("name_key", ""))
		profile_requested.emit(profile)
	return bool(result.get("handled", false))

func _setup_sprite() -> void:
	var config := _avatar_config()
	if config.is_empty():
		return
	character_variant_id = str(config.get("character_variant_id", character_variant_id))
	_sprite = get_node_or_null("AvatarSprite") as AnimatedSprite2D
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "AvatarSprite"
		add_child(_sprite)
		move_child(_sprite, 0)

	var frames := SpriteFrames.new()
	for animation_name in (config.get("animations", {}) as Dictionary).keys():
		var animation: Dictionary = config["animations"][animation_name] as Dictionary
		frames.add_animation(str(animation_name))
		frames.set_animation_speed(str(animation_name), float(animation.get("fps", 1.0)))
		frames.set_animation_loop(str(animation_name), bool(animation.get("loop", true)))
		for frame_path in animation.get("frames", []):
			var texture := _load_texture(str(frame_path))
			if texture != null:
				frames.add_frame(str(animation_name), texture)

	_sprite.sprite_frames = frames
	var sprite_scale := float(config.get("sprite_scale", 0.36))
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.modulate = PlayerAvatarConfigScript.sprite_modulate(config)
	_sprite.position = Vector2(0, 5)
	_current_animation = ""
	if _body != null:
		_body.visible = false
	if name_label != null:
		name_label.offset_top = -46
		name_label.offset_bottom = -28
	if emote_bubble != null:
		(emote_bubble as Node2D).position = Vector2(0, -24)

func _play_action(action: String) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var animation := "%s_%s" % [action, facing]
	if not _sprite.sprite_frames.has_animation(animation):
		animation = "%s_down" % action
	_sprite.flip_h = facing == "right"
	if _current_animation == animation:
		return
	_current_animation = animation
	_sprite.play(animation)

func _sync_process_flags() -> void:
	set_physics_process(input_enabled)
	set_process((_nameplate != null and bool(_nameplate.call("is_active"))) or (not input_enabled and _has_remote_target))

func _validated_velocity(direction: Vector2, delta: float) -> Vector2:
	var base_velocity := direction * speed
	if not _movement_validator.is_valid() or direction.length() <= 0.01 or can_enter_world_position(global_position + base_velocity * delta):
		return base_velocity
	for candidate in [Vector2(base_velocity.x, 0.0), Vector2(0.0, base_velocity.y)]:
		if candidate.length() > 0.01 and can_enter_world_position(global_position + candidate * delta):
			return candidate
	return Vector2.ZERO

func _direction_from_vector(direction: Vector2) -> String:
	if abs(direction.x) >= abs(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"

func _avatar_config() -> Dictionary:
	return PlayerAvatarConfigScript.new().avatar_config(character_variant_id)

func _load_texture(path: String) -> Texture2D:
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	if resource == null:
		push_warning("Unable to load avatar frame: %s" % path)
	else:
		push_warning("Avatar frame is not a texture: %s" % path)
	return null
