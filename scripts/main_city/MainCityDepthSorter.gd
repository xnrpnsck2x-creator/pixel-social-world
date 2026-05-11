class_name MainCityDepthSorter
extends Node

const BASE_Z := 1000
const MIN_Z := 100
const MAX_Z := 1900
const SORT_INTERVAL_SECONDS := 0.08

var local_player: Node2D
var npc_root: Node
var remote_root: Node
var _sort_left := 0.0

func bind(new_local_player: Node2D, new_npc_root: Node, new_remote_root: Node) -> void:
	local_player = new_local_player
	npc_root = new_npc_root
	remote_root = new_remote_root
	_sort_left = 0.0
	set_process(local_player != null)
	sort_now()

func _process(delta: float) -> void:
	_apply_actor_depth(local_player)
	_sort_left -= delta
	if _sort_left > 0.0:
		return
	_sort_left = SORT_INTERVAL_SECONDS
	_apply_children(npc_root)
	_apply_children(remote_root)

func sort_now() -> void:
	_apply_actor_depth(local_player)
	_apply_children(npc_root)
	_apply_children(remote_root)

func _apply_children(root_node: Node) -> void:
	if root_node == null:
		return
	for child in root_node.get_children():
		if child is Node2D:
			_apply_actor_depth(child as Node2D)

func _apply_actor_depth(actor: Node2D) -> void:
	if actor == null:
		return
	actor.z_as_relative = false
	actor.z_index = clampi(BASE_Z + int(round(actor.global_position.y)), MIN_Z, MAX_Z)
