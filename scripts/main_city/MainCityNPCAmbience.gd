class_name MainCityNPCAmbience
extends Node

const GLANCE_SECONDS := 0.65
const SCAN_SECONDS := 2.8
const PLAYER_SAFE_RADIUS := 112.0
const EMOTE_CHANCE := 0.35
const DIRECTIONS := ["down", "right", "up", "left"]

var screen_root: Node
var npc_root: Node
var _rng := RandomNumberGenerator.new()
var _scan_timer: Timer
var _active_glances: Dictionary = {}

func _ready() -> void:
	_rng.seed = 17419
	_ensure_scan_timer()
	set_process(false)

func bind(new_screen_root: Node, new_npc_root: Node) -> void:
	screen_root = new_screen_root
	npc_root = new_npc_root
	_active_glances.clear()
	set_process(false)
	_schedule_next_scan(SCAN_SECONDS)

func _process(delta: float) -> void:
	_update_glances(delta)
	if _active_glances.is_empty():
		set_process(false)

func _ensure_scan_timer() -> void:
	if _scan_timer != null:
		return
	_scan_timer = Timer.new()
	_scan_timer.one_shot = true
	_scan_timer.timeout.connect(_on_scan_timer_timeout)
	add_child(_scan_timer)

func _schedule_next_scan(seconds := -1.0) -> void:
	_ensure_scan_timer()
	if npc_root == null:
		_scan_timer.stop()
		return
	_scan_timer.stop()
	_scan_timer.wait_time = maxf(0.1, seconds if seconds > 0.0 else SCAN_SECONDS + _rng.randf_range(0.0, 1.4))
	_scan_timer.start()

func _on_scan_timer_timeout() -> void:
	_pulse_random_npc()
	_schedule_next_scan()

func pulse_npc(npc: Node, play_emote := true) -> void:
	if not _can_pulse(npc):
		return
	_start_glance(npc)
	if play_emote:
		_play_emote(npc)

func _pulse_random_npc() -> void:
	var candidates := _candidate_npcs()
	if candidates.is_empty():
		return
	var index := _rng.randi_range(0, candidates.size() - 1)
	var npc: Node = candidates[index] as Node
	pulse_npc(npc, _rng.randf() < EMOTE_CHANCE)

func _candidate_npcs() -> Array:
	var candidates: Array = []
	if npc_root == null:
		return candidates
	for child in npc_root.get_children():
		var npc := child as Node
		if _can_pulse(npc):
			candidates.append(npc)
	return candidates

func _can_pulse(npc: Node) -> bool:
	if npc == null or not npc.has_method("face_toward"):
		return false
	if _active_glances.has(str(npc.get("npc_id"))) or _name_visible(npc):
		return false
	var player := _local_player()
	if player == null:
		return true
	var actor := npc as Node2D
	return actor != null and actor.global_position.distance_to(player.global_position) > PLAYER_SAFE_RADIUS

func _start_glance(npc: Node) -> void:
	var npc_id := str(npc.get("npc_id"))
	var home_facing := str(npc.get("facing"))
	var home_pose := str(npc.get("pose"))
	var next_pose := _next_pose(npc)
	if next_pose.is_empty():
		npc.set("facing", _next_direction(home_facing))
	else:
		npc.set("pose", next_pose)
	npc.call("_refresh")
	_active_glances[npc_id] = {
		"node": npc,
		"home_facing": home_facing,
		"home_pose": home_pose,
		"left": GLANCE_SECONDS
	}
	set_process(true)

func _update_glances(delta: float) -> void:
	for npc_id in _active_glances.keys():
		var data: Dictionary = _active_glances[npc_id] as Dictionary
		var left := float(data.get("left", 0.0)) - delta
		if left > 0.0:
			data["left"] = left
			_active_glances[npc_id] = data
			continue
		var npc: Node = data.get("node") as Node
		if is_instance_valid(npc):
			npc.set("facing", str(data.get("home_facing", "down")))
			npc.set("pose", str(data.get("home_pose", "idle")))
			npc.call("_refresh")
		_active_glances.erase(npc_id)

func _next_direction(home: String) -> String:
	var next := str(DIRECTIONS[_rng.randi_range(0, DIRECTIONS.size() - 1)])
	if next == home:
		return "right" if home != "right" else "left"
	return next

func _next_pose(npc: Node) -> String:
	var poses := _ambience_poses(npc)
	if poses.is_empty():
		return ""
	return str(poses[_rng.randi_range(0, poses.size() - 1)])

func _ambience_poses(npc: Node) -> Array:
	var point_poses := _point_ambience_poses(npc)
	if not point_poses.is_empty():
		return point_poses
	var visual_id := str(npc.get("npc_visual_id"))
	if visual_id.is_empty() or not is_inside_tree():
		return []
	var loader := get_tree().root.get_node_or_null("ConfigLoader")
	if loader == null or not loader.has_method("load_config"):
		return []
	var data: Dictionary = loader.call("load_config", "npc_professions") as Dictionary
	for role in data.get("roles", []):
		if typeof(role) == TYPE_DICTIONARY and str((role as Dictionary).get("id", "")) == visual_id:
			return (role as Dictionary).get("ambience_poses", []) as Array
	return []

func _point_ambience_poses(npc: Node) -> Array:
	if npc == null or not npc.has_meta("ambience_poses"):
		return []
	var poses := npc.get_meta("ambience_poses") as Array
	var cleaned: Array = []
	for pose in poses:
		var pose_id := str(pose)
		if not pose_id.is_empty():
			cleaned.append(pose_id)
	return cleaned

func _play_emote(npc: Node) -> void:
	var emote_id := str(npc.get("emote_id"))
	if emote_id.is_empty():
		return
	var bubble := npc.get_node_or_null("EmoteBubble")
	if bubble != null and bubble.has_method("play"):
		bubble.call("play", emote_id)

func _name_visible(npc: Node) -> bool:
	var label := npc.get_node_or_null("NameLabel") as CanvasItem
	return label != null and label.visible

func _local_player() -> Node2D:
	if screen_root == null:
		return null
	return screen_root.get_node_or_null("PlayerRoot/LocalPlayer") as Node2D
