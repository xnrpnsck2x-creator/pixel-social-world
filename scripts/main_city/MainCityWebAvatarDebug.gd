class_name MainCityWebAvatarDebug
extends RefCounted

const DIRECTIONS := ["down", "right", "up", "left"]
const WALK_ACTIONS := {
	"down": "ui_down",
	"right": "ui_right",
	"up": "ui_up",
	"left": "ui_left"
}
const REMOTE_SAMPLES := [
	{
		"player_id": "h5-remote-magic",
		"display_name": "Magic Guest",
		"character_variant_id": "female_magic_v0",
		"facing": "left",
		"offset": Vector2(-48, -18),
		"emote": "emote.heart"
	},
	{
		"player_id": "h5-remote-ranged",
		"display_name": "Ranged Guest",
		"character_variant_id": "male_ranged_v0",
		"facing": "right",
		"offset": Vector2(48, -18),
		"emote": "emote.laugh"
	}
]

func apply(screen: Node) -> void:
	var variant_id := _query_value("psw_character_variant")
	if not variant_id.is_empty():
		_schedule_avatar_variant(screen, variant_id)
	if _query_value("psw_remote_avatar") == "sample":
		_schedule_remote_avatars(screen)

func _schedule_avatar_variant(screen: Node, variant_id: String) -> void:
	var timer := screen.get_tree().create_timer(0.65)
	timer.timeout.connect(func() -> void:
		_show_avatar_variant(screen, variant_id)
	)

func _show_avatar_variant(screen: Node, variant_id: String) -> void:
	var player := screen.get_node_or_null("PlayerRoot/LocalPlayer")
	if player == null:
		_mark_debug_avatar({"variant": variant_id, "ok": false, "reason": "missing_player"})
		return
	var variant := _character_variant_config(variant_id)
	if variant.is_empty():
		_mark_debug_avatar({"variant": variant_id, "ok": false, "reason": "unknown_variant"})
		return
	for key in ["gender_id", "class_id", "avatar_id", "id"]:
		var save_key: String = "character_variant_id" if key == "id" else key
		SaveSystem.set_profile_value(save_key, variant.get(key, ""))
	var facing := _valid_facing(_query_value("psw_avatar_facing"))
	player.call("apply_remote_state", {"character_variant_id": variant_id, "facing": facing})
	if player.has_method("set_movement_validator"):
		player.call("set_movement_validator", Callable())
	var action := _query_value("psw_avatar_action")
	if action == "walk":
		_start_walk_debug(screen, player, variant, facing)
		return
	if action == "attack" and player.has_method("start_attack"):
		player.call("start_attack")
		player.set("_attack_time_left", 1.2)
	elif action == "sit" and player.has_method("sit_down"):
		player.call("sit_down")
	elif action == "emote":
		player.call("show_emote", _query_value("psw_avatar_emote"))
		player.call("_play_action", "idle")
	else:
		action = "idle"
		player.call("_play_action", "idle")
	_mark_debug_map_view(screen)
	_mark_debug_avatar(_avatar_debug_payload(player, variant, action, Vector2.ZERO))

func _start_walk_debug(screen: Node, player: Node, variant: Dictionary, facing: String) -> void:
	_release_walk_inputs()
	var start_position := (player as Node2D).global_position
	player.set("facing", facing)
	Input.action_press(str(WALK_ACTIONS.get(facing, "ui_down")), 1.0)
	var timer := screen.get_tree().create_timer(0.42)
	timer.timeout.connect(func() -> void:
		var delta := (player as Node2D).global_position - start_position
		_mark_debug_map_view(screen)
		_mark_debug_avatar(_avatar_debug_payload(player, variant, "walk", delta))
		var release_timer := screen.get_tree().create_timer(0.75)
		release_timer.timeout.connect(func() -> void:
			_release_walk_inputs()
		)
	)

func _schedule_remote_avatars(screen: Node) -> void:
	var timer := screen.get_tree().create_timer(0.85)
	timer.timeout.connect(func() -> void:
		_show_remote_avatars(screen)
	)

func _show_remote_avatars(screen: Node) -> void:
	var sync = screen.get("_remote_player_sync")
	var remote_root := screen.get_node_or_null("PlayerRoot/RemotePlayers") as Node2D
	var local_player := screen.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	if sync == null or remote_root == null or local_player == null:
		_mark_debug_remote({"ok": false, "reason": "missing_remote_sync"})
		return
	var members: Array = [{"player_id": SaveSystem.get_player_id(), "display_name": SaveSystem.get_display_name()}]
	for sample in REMOTE_SAMPLES:
		members.append({
			"player_id": sample["player_id"],
			"display_name": sample["display_name"],
			"character_variant_id": sample["character_variant_id"]
		})
	sync.call("sync_members", members, SaveSystem.get_player_id())
	var timer := screen.get_tree().create_timer(0.22)
	timer.timeout.connect(func() -> void:
		_position_remote_samples(sync, remote_root, local_player)
		_mark_debug_map_view(screen)
		_mark_debug_remote(_remote_debug_payload(remote_root))
	)

func _position_remote_samples(sync, remote_root: Node2D, local_player: Node2D) -> void:
	var index := 0
	for child in remote_root.get_children():
		if index >= REMOTE_SAMPLES.size():
			break
		var sample: Dictionary = REMOTE_SAMPLES[index]
		var position := local_player.global_position + (sample["offset"] as Vector2)
		child.call("apply_remote_state", {
			"position": position,
			"facing": sample["facing"],
			"character_variant_id": sample["character_variant_id"]
		})
		sync.call("show_emote", str(sample["player_id"]), str(sample["emote"]))
		index += 1

func _character_variant_config(variant_id: String) -> Dictionary:
	for variant in ConfigLoader.load_config("player_animations").get("character_variants", []):
		if typeof(variant) == TYPE_DICTIONARY and str((variant as Dictionary).get("id", "")) == variant_id:
			return (variant as Dictionary).duplicate(true)
	return {}

func _avatar_debug_payload(player: Node, variant: Dictionary, action: String, movement_delta: Vector2) -> Dictionary:
	var sprite := player.get_node_or_null("AvatarSprite") as AnimatedSprite2D
	var texture_path := _sprite_texture_path(sprite)
	var trace := player.get_parent().get_node_or_null("AttackFeedbackTrace") if player.get_parent() != null else null
	var emote := _emote_payload(player)
	return {
		"ok": true,
		"variant": str(variant.get("id", "")),
		"avatar": str(variant.get("avatar_id", "")),
		"gender": str(variant.get("gender_id", "")),
		"class": str(variant.get("class_id", "")),
		"action": action,
		"facing": str(player.get("facing")),
		"animation": "" if sprite == null else str(sprite.animation),
		"texture": texture_path,
		"flip_h": false if sprite == null else bool(sprite.flip_h),
		"attack_feedback": trace != null,
		"emote_visible": bool(emote.get("visible", false)),
		"emote_texture": str(emote.get("texture", "")),
		"movement_delta": {"x": movement_delta.x, "y": movement_delta.y},
		"moved_pixels": movement_delta.length()
	}

func _remote_debug_payload(remote_root: Node2D) -> Dictionary:
	var entries: Array = []
	var emote_count := 0
	var names_visible := 0
	for child in remote_root.get_children():
		var sprite := child.get_node_or_null("AvatarSprite") as AnimatedSprite2D
		var label := child.get_node_or_null("NameLabel") as Label
		var emote := _emote_payload(child)
		emote_count += 1 if bool(emote.get("visible", false)) else 0
		names_visible += 1 if label != null and label.visible else 0
		entries.append({
			"variant": str(child.get("character_variant_id")),
			"animation": "" if sprite == null else str(sprite.animation),
			"texture": _sprite_texture_path(sprite),
			"emote_visible": bool(emote.get("visible", false)),
			"emote_texture": str(emote.get("texture", "")),
			"name_visible": label != null and label.visible
		})
	return {
		"ok": true,
		"count": remote_root.get_child_count(),
		"emote_visible_count": emote_count,
		"names_visible_count": names_visible,
		"entries": entries
	}

func _emote_payload(player: Node) -> Dictionary:
	var bubble := player.get_node_or_null("EmoteBubble") as Node2D
	var sprite := bubble.get_child(0) as Sprite2D if bubble != null and bubble.get_child_count() > 0 else null
	return {
		"visible": bubble != null and bubble.visible,
		"texture": "" if sprite == null or sprite.texture == null else str(sprite.texture.resource_path)
	}

func _sprite_texture_path(sprite: AnimatedSprite2D) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return "" if frame == null else str(frame.resource_path)

func _valid_facing(raw: String) -> String:
	return raw if DIRECTIONS.has(raw) else "down"

func _release_walk_inputs() -> void:
	for action in WALK_ACTIONS.values():
		Input.action_release(str(action))

func _query_value(key: String) -> String:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var script := "new URLSearchParams(window.location.search).get('%s') || ''" % key
	var value: Variant = bridge.call("eval", script, true)
	return str(value) if typeof(value) == TYPE_STRING else ""

func _mark_debug_map_view(screen: Node) -> void:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	var player := screen.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
	var metadata = screen.get("_map_metadata")
	if player == null or metadata == null:
		bridge.call("eval", "globalThis.__psw_debug_map_view = null", true)
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		bridge.call("eval", "globalThis.__psw_debug_map_view = null", true)
		return
	var viewport_size := screen.get_viewport().get_visible_rect().size
	var canvas_size := Vector2.ZERO
	var raw_canvas: Variant = metadata.get("canvas_size")
	if typeof(raw_canvas) == TYPE_VECTOR2:
		canvas_size = raw_canvas
	var center := camera.global_position
	if camera.has_method("get_screen_center_position"):
		center = camera.call("get_screen_center_position")
	bridge.call("eval", "globalThis.__psw_debug_map_view = %s" % JSON.stringify({
		"canvas_width": canvas_size.x,
		"canvas_height": canvas_size.y,
		"center_x": center.x,
		"center_y": center.y,
		"zoom_x": camera.zoom.x,
		"zoom_y": camera.zoom.y,
		"viewport_width": viewport_size.x,
		"viewport_height": viewport_size.y
	}), true)

func _mark_debug_avatar(data: Dictionary) -> void:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	bridge.call("eval", "globalThis.__psw_debug_avatar_variant = %s" % JSON.stringify(data), true)

func _mark_debug_remote(data: Dictionary) -> void:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	bridge.call("eval", "globalThis.__psw_debug_remote_avatars = %s" % JSON.stringify(data), true)
