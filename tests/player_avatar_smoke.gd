extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "avatar-smoke-player",
		"display_name": "Avatar Smoke",
		"coin_balance": 25,
		"coin_ledger": [],
		"gender_id": "female",
		"class_id": "magic",
		"avatar_id": "female_magic_v1",
		"character_variant_id": "female_magic_v0"
	})
	save_system.call("_apply_defaults")
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var player := instance.get_node("PlayerRoot/LocalPlayer")
	var sprite := player.get_node_or_null("AvatarSprite")
	if sprite == null:
		failures.append("AvatarSprite was not created.")
	elif abs(float((sprite as Node2D).scale.x) - 0.22) > 0.01:
		failures.append("AvatarSprite scale did not use the formal Image 2 character sheet tuning.")
	elif str(player.get("character_variant_id")) != "female_magic_v0":
		failures.append("AvatarSprite did not use the saved female magic character variant.")
	else:
		var idle_texture := (sprite as AnimatedSprite2D).sprite_frames.get_frame_texture("idle_down", 0)
		if idle_texture == null or not idle_texture.resource_path.contains("player_female_magic_actions_v1"):
			failures.append("Character variant did not load its formal Image 2 action sheet.")
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null or camera.zoom.x > 1.05:
		failures.append("Main city camera remained too close for the Image 2 whole-map motherboard.")
	elif camera.zoom.x < 0.84:
		failures.append("Main city camera pulled too far out for avatar and emote readability.")
	var map_runtime = instance.get("_map_runtime")
	if camera != null and map_runtime != null:
		map_runtime.call("load_map", "social_housing_district_v1")
		await process_frame
		if camera.limit_bottom != 627 or camera.limit_top != -627:
			failures.append("Square Image 2 maps did not bind camera limits to prevent edge exposure.")
	if str(player.call("_direction_from_vector", Vector2(1, 1))) != "right":
		failures.append("Diagonal down-right movement did not prefer the side-facing walk.")
	player.set("facing", "right")
	player.call("_play_action", "walk")
	if sprite != null and not bool((sprite as AnimatedSprite2D).flip_h):
		failures.append("Right-facing animation did not mirror the left-facing Image 2 side frame.")
	player.set("facing", "left")
	player.call("_play_action", "walk")
	if sprite != null and bool((sprite as AnimatedSprite2D).flip_h):
		failures.append("Left-facing animation flipped the Image 2 side frame backwards.")
	var name_label := player.get_node("NameLabel") as Label
	player.set("display_name", "Avatar Smoke")
	await process_frame
	if name_label.visible:
		failures.append("Player name should be hidden by default.")
	player.call("reveal_name", 1.0)
	if not name_label.visible or name_label.text != "Avatar Smoke":
		failures.append("Player name did not reveal on demand.")
	player.call("hide_name")
	if name_label.visible:
		failures.append("Player name did not hide after reveal.")
	player.call("show_emote", "emote.laugh")
	await create_timer(0.22).timeout
	var bubble := player.get_node("EmoteBubble") as Node2D
	var emote_sprite := bubble.get_child(0) as Sprite2D
	var emote_height := float(emote_sprite.texture.get_height()) * emote_sprite.scale.y
	var frame_texture := (sprite as AnimatedSprite2D).sprite_frames.get_frame_texture((sprite as AnimatedSprite2D).animation, 0)
	var avatar_top := (sprite as Node2D).position.y - float(frame_texture.get_height()) * (sprite as Node2D).scale.y * 0.5
	var emote_bottom := bubble.position.y + emote_sprite.position.y + emote_height * 0.5
	if emote_height > 22.0:
		failures.append("Overhead emote remained too large for the avatar headroom.")
	if emote_bottom > avatar_top - 1.0 or avatar_top - emote_bottom > 12.0:
		failures.append("Overhead emote did not sit in the tight space above the avatar head.")

	player.call("sit_down")
	var sit_state: Dictionary = player.call("get_avatar_state")
	if not bool(sit_state.get("is_sitting", false)):
		failures.append("sit_down did not enter sitting state.")
	if not str(sit_state.get("animation", "")).begins_with("sit_"):
		failures.append("sit_down did not play a sit animation.")

	player.call("start_attack")
	var attack_state: Dictionary = player.call("get_avatar_state")
	if not bool(attack_state.get("is_attacking", false)):
		failures.append("start_attack did not enter attack state.")
	if not str(attack_state.get("animation", "")).begins_with("attack_"):
		failures.append("start_attack did not play an attack animation.")
	var feedback_trace: Node = player.get_node_or_null("AttackFeedbackTrace")
	if feedback_trace == null and player.get_parent() != null:
		feedback_trace = player.get_parent().get_node_or_null("AttackFeedbackTrace")
	if feedback_trace == null:
		failures.append("start_attack did not spawn the configured class attack feedback trace.")
	if emote_sprite.texture == null or not emote_sprite.texture.resource_path.contains("overhead_emotes_v1_007"):
		failures.append("Magic character attack did not play the configured role emote.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("player avatar smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
