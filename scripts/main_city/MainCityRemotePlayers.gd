class_name MainCityRemotePlayers
extends RefCounted

signal profile_requested(profile: Dictionary)

const PlayerAvatarScript := preload("res://scripts/Entities/Player/PlayerAvatar.gd")
const EmoteBubbleScript := preload("res://scripts/UI/Emotes/OverheadEmoteBubble.gd")

const SIDE_UI_SAFE_PIXELS := 40.0
const TOP_UI_SAFE_PIXELS := 300.0
const BOTTOM_UI_SAFE_PIXELS := 150.0

var _remote_root: Node2D
var _local_player: CharacterBody2D
var _remote_avatars: Dictionary = {}

func bind(remote_root: Node2D, local_player: CharacterBody2D) -> void:
	_remote_root = remote_root
	_local_player = local_player

func show_emote(player_id: String, emote_id: String) -> void:
	if _remote_avatars.has(player_id):
		(_remote_avatars[player_id] as Node).call("show_emote", emote_id)

func apply_move(payload: Dictionary, local_id: String) -> void:
	var player_id := str(payload.get("player_id", ""))
	if player_id.is_empty() or player_id == local_id:
		return
	var avatar := _get_or_create_remote_avatar(player_id)
	avatar.apply_remote_state(payload)

func apply_snapshot(payload: Dictionary, local_id: String) -> void:
	for player_state in payload.get("players", []):
		if typeof(player_state) == TYPE_DICTIONARY:
			apply_move(player_state as Dictionary, local_id)

func sync_members(members: Array, local_id: String) -> void:
	var active_ids := {}
	for member in members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var player_id := str((member as Dictionary).get("player_id", ""))
		if player_id.is_empty() or player_id == local_id:
			continue
		active_ids[player_id] = true
		var avatar: Node = _get_or_create_remote_avatar(player_id)
		avatar.apply_remote_state({
			"display_name": display_name_for(member as Dictionary, player_id),
			"position": _spawn_position_for(player_id),
			"facing": _facing_for(player_id),
			"is_sitting": false
		})

	for player_id in _remote_avatars.keys():
		if active_ids.has(player_id):
			continue
		remove(player_id)

func remove(player_id: String) -> void:
	if not _remote_avatars.has(player_id):
		return
	var avatar: Node = _remote_avatars[player_id]
	_remote_avatars.erase(player_id)
	avatar.queue_free()

func display_name_for(member: Dictionary, player_id: String) -> String:
	var display_name := str(member.get("display_name", ""))
	if display_name.is_empty():
		return player_id
	return display_name

func _get_or_create_remote_avatar(player_id: String) -> CharacterBody2D:
	if _remote_avatars.has(player_id):
		return _remote_avatars[player_id] as CharacterBody2D

	var avatar := CharacterBody2D.new()
	avatar.name = "Remote_%s" % player_id.sha1_text().substr(0, 8)
	avatar.set_script(PlayerAvatarScript)
	avatar.set("player_id", player_id)
	avatar.set("input_enabled", false)
	avatar.set("speed", 0.0)
	avatar.connect("profile_requested", func(profile: Dictionary) -> void:
		profile_requested.emit(profile)
	)

	var body := Polygon2D.new()
	body.name = "Body"
	body.color = Color(0.22, 0.58, 0.72, 1.0)
	body.polygon = PackedVector2Array([-8, -12, 8, -12, 8, 12, -8, 12])
	avatar.add_child(body)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.unique_name_in_owner = true
	name_label.offset_left = -48.0
	name_label.offset_top = -38.0
	name_label.offset_right = 48.0
	name_label.offset_bottom = -14.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.add_child(name_label)

	var emote_bubble := Node2D.new()
	emote_bubble.name = "EmoteBubble"
	emote_bubble.position = Vector2(0, -52)
	emote_bubble.set_script(EmoteBubbleScript)
	avatar.add_child(emote_bubble)

	_remote_root.add_child(avatar)
	_remote_avatars[player_id] = avatar
	return avatar

func _spawn_position_for(player_id: String) -> Vector2:
	var hash_value: int = abs(player_id.hash())
	var angle: float = float(hash_value % 628) / 100.0
	var radius: float = 92.0 + float((hash_value >> 8) % 72)
	return _clamp_to_playable_view(Vector2(cos(angle) * radius, sin(angle) * radius))

func _clamp_to_playable_view(position: Vector2) -> Vector2:
	var safe_rect := _playable_world_rect()
	var max_position := safe_rect.position + safe_rect.size
	return Vector2(
		clamp(position.x, safe_rect.position.x, max_position.x),
		clamp(position.y, safe_rect.position.y, max_position.y)
	)

func _playable_world_rect() -> Rect2:
	var viewport_size := _local_player.get_viewport_rect().size
	var camera := _local_player.get_node_or_null("Camera2D") as Camera2D
	var zoom := camera.zoom if camera != null else Vector2.ONE
	var zoom_x: float = max(1.0, zoom.x)
	var zoom_y: float = max(1.0, zoom.y)
	var safe_left: float = -viewport_size.x * 0.5 / zoom_x + SIDE_UI_SAFE_PIXELS / zoom_x
	var safe_right: float = viewport_size.x * 0.5 / zoom_x - SIDE_UI_SAFE_PIXELS / zoom_x
	var safe_top: float = -viewport_size.y * 0.5 / zoom_y + TOP_UI_SAFE_PIXELS / zoom_y
	var safe_bottom: float = viewport_size.y * 0.5 / zoom_y - BOTTOM_UI_SAFE_PIXELS / zoom_y
	if safe_bottom <= safe_top:
		var center_y := (safe_top + safe_bottom) * 0.5
		safe_top = center_y - 8.0
		safe_bottom = center_y + 8.0
	return Rect2(Vector2(safe_left, safe_top), Vector2(safe_right - safe_left, safe_bottom - safe_top))

func _facing_for(player_id: String) -> String:
	var directions := PackedStringArray(["down", "right", "up", "left"])
	return directions[abs(player_id.hash()) % directions.size()]
