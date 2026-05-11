extends SceneTree

const PlayerAvatarScript := preload("res://scripts/Entities/Player/PlayerAvatar.gd")
const ConfigLoaderScript := preload("res://scripts/Core/ConfigLoader.gd")

const REQUIRED_ANIMATIONS := [
	"idle_down", "idle_right", "idle_up", "idle_left",
	"walk_down", "walk_right", "walk_up", "walk_left",
	"attack_down", "attack_right", "attack_up", "attack_left",
	"sit_down", "sit_right", "sit_up", "sit_left",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var loader := ConfigLoaderScript.new()
	var data: Dictionary = loader.load_config("player_animations")
	loader.free()
	for variant in data.get("character_variants", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		await _assert_variant(variant as Dictionary, failures)

	if failures.is_empty():
		print("player avatar variants smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_variant(variant: Dictionary, failures: Array[String]) -> void:
	var player := PlayerAvatarScript.new()
	player.character_variant_id = str(variant.get("id", ""))
	root.add_child(player)
	await process_frame
	var sprite := player.get_node_or_null("AvatarSprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		failures.append("%s did not create AvatarSprite frames." % variant.get("id", ""))
		player.queue_free()
		await process_frame
		return
	for animation in REQUIRED_ANIMATIONS:
		if not sprite.sprite_frames.has_animation(animation):
			failures.append("%s missing animation %s." % [variant.get("id", ""), animation])
	var expected_path := "player_%s_%s_actions_v1" % [variant.get("gender_id", ""), variant.get("class_id", "")]
	var idle_texture := sprite.sprite_frames.get_frame_texture("idle_down", 0)
	if idle_texture == null or not idle_texture.resource_path.contains(expected_path):
		failures.append("%s did not load %s." % [variant.get("id", ""), expected_path])
	var config: Dictionary = player.call("_avatar_config")
	var feedback: Dictionary = config.get("attack_feedback", {})
	if not ["lunge", "aim", "cast"].has(str(feedback.get("style", ""))):
		failures.append("%s did not inherit class attack feedback." % variant.get("id", ""))
	player.facing = "right"
	player.call("_play_action", "walk")
	if not sprite.flip_h:
		failures.append("%s right-facing side frame was not mirrored." % variant.get("id", ""))
	player.facing = "left"
	player.call("_play_action", "walk")
	if sprite.flip_h:
		failures.append("%s left-facing side frame was mirrored backwards." % variant.get("id", ""))
	player.queue_free()
	await process_frame
