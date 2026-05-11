class_name PlayerAvatarAttackFeedback
extends RefCounted

const TRACE_NAME := "AttackFeedbackTrace"
const VALID_STYLES := ["lunge", "aim", "cast"]

func play(owner: Node2D, sprite: AnimatedSprite2D, config: Dictionary, facing: String) -> void:
	if owner == null or sprite == null:
		return
	var feedback: Variant = config.get("attack_feedback", {})
	if typeof(feedback) != TYPE_DICTIONARY:
		return
	var data := feedback as Dictionary
	var style := str(data.get("style", ""))
	if not VALID_STYLES.has(style):
		return
	var direction := _direction(facing)
	var distance := float(data.get("distance", 4.0))
	var accent := _accent(data)
	match style:
		"lunge":
			_play_motion(owner, sprite, direction * distance, 1.07, accent)
			_spawn_trace(owner, _lunge_points(direction), accent)
		"aim":
			_play_motion(owner, sprite, -direction * min(distance, 4.0), 1.02, accent)
			_spawn_trace(owner, [direction * 5.0 + Vector2(0, -10), direction * 24.0 + Vector2(0, -10)], accent)
		"cast":
			_play_motion(owner, sprite, Vector2(0, -distance), 1.05, accent)
			_spawn_trace(owner, [Vector2(0, -20), Vector2(8, -14), Vector2(0, -8), Vector2(-8, -14), Vector2(0, -20)], accent)

func _play_motion(owner: Node2D, sprite: AnimatedSprite2D, offset: Vector2, scale_factor: float, accent: Color) -> void:
	var start_position := sprite.position
	var start_scale := sprite.scale
	var start_modulate := sprite.modulate
	var tween := owner.create_tween()
	tween.tween_property(sprite, "position", start_position + offset, 0.08)
	tween.parallel().tween_property(sprite, "scale", start_scale * scale_factor, 0.08)
	tween.parallel().tween_property(sprite, "modulate", start_modulate.lerp(accent, 0.24), 0.08)
	tween.tween_property(sprite, "position", start_position, 0.12)
	tween.parallel().tween_property(sprite, "scale", start_scale, 0.12)
	tween.parallel().tween_property(sprite, "modulate", start_modulate, 0.12)

func _spawn_trace(owner: Node2D, points: Array, accent: Color) -> void:
	var trace := Line2D.new()
	trace.name = TRACE_NAME
	trace.width = 3.0
	trace.default_color = accent
	trace.points = PackedVector2Array(points)
	trace.z_as_relative = false
	trace.z_index = 150
	var container := owner.get_parent()
	if container is Node2D:
		(container as Node2D).add_child(trace)
		trace.global_position = owner.global_position
	else:
		owner.add_child(trace)
	var tween := owner.create_tween()
	tween.tween_interval(0.14)
	tween.tween_property(trace, "modulate:a", 0.0, 0.22)
	tween.tween_callback(trace.queue_free)

func _lunge_points(direction: Vector2) -> Array:
	if direction == Vector2.LEFT:
		return [Vector2(-7, -8), Vector2(-20, 3)]
	if direction == Vector2.RIGHT:
		return [Vector2(7, -8), Vector2(20, 3)]
	if direction == Vector2.UP:
		return [Vector2(-8, -16), Vector2(8, -26)]
	return [Vector2(-9, -5), Vector2(9, 6)]

func _direction(facing: String) -> Vector2:
	match facing:
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN

func _accent(data: Dictionary) -> Color:
	var raw: Variant = data.get("accent", [1.0, 1.0, 1.0, 0.9])
	if typeof(raw) != TYPE_ARRAY:
		return Color.WHITE
	var parts := raw as Array
	if parts.size() < 3:
		return Color.WHITE
	return Color(
		float(parts[0]),
		float(parts[1]),
		float(parts[2]),
		float(parts[3]) if parts.size() > 3 else 0.9
	)
