class_name OnlineRoomPanelMembers
extends RefCounted

signal profile_requested(profile: Dictionary)

const Formatter := preload("res://scripts/UI/Panels/OnlineRoomPanelFormatter.gd")

var members_label: Label
var members_list: ItemList
var private_button: Button
var _selected_peer_id := ""

func bind(new_members_label: Label, new_members_list: ItemList, new_private_button: Button) -> void:
	members_label = new_members_label
	members_list = new_members_list
	private_button = new_private_button
	members_list.item_selected.connect(_on_member_selected)
	members_list.item_activated.connect(func(index: int) -> void:
		_select_index(index)
		request_profile()
	)
	private_button.pressed.connect(request_profile)
	refresh_text()

func refresh_text() -> void:
	private_button.text = App.t_key("world.room_panel.profile_button")
	private_button.tooltip_text = App.t_key("world.room_panel.profile_button")

func refresh(members: Array, local_id: String, compact: bool) -> void:
	members_label.text = Formatter.member_rows(members, local_id, 8)
	members_label.visible = false
	members_list.visible = not compact
	private_button.visible = not compact
	members_list.clear()
	_selected_peer_id = ""
	for member in members.slice(0, 8):
		if typeof(member) == TYPE_DICTIONARY:
			_add_member(member as Dictionary, local_id)
	private_button.disabled = _selected_peer_id.is_empty()

func request_profile() -> void:
	if _selected_peer_id.is_empty():
		return
	profile_requested.emit(_selected_profile())

func _add_member(member: Dictionary, local_id: String) -> void:
	var player_id := str(member.get("player_id", ""))
	var name := str(member.get("display_name", player_id))
	var seconds := Formatter._seconds_since(int(member.get("last_seen_at", 0)))
	var is_self := player_id == local_id
	var key := "world.room_panel.member_self_format" if is_self else "world.room_panel.member_format"
	members_list.add_item(App.format_key(key, {"name": name, "seconds": seconds}))
	var index := members_list.get_item_count() - 1
	members_list.set_item_metadata(index, {
		"player_id": player_id,
		"display_name": name,
		"character_variant_id": str(member.get("character_variant_id", ""))
	})
	members_list.set_item_disabled(index, is_self)
	if _selected_peer_id.is_empty() and not is_self:
		_select_index(index)

func _on_member_selected(index: int) -> void:
	_select_index(index)

func _select_index(index: int) -> void:
	var profile := _profile_at(index)
	var peer_id := str(profile.get("player_id", ""))
	_selected_peer_id = "" if peer_id == SaveSystem.get_player_id() else peer_id
	if not _selected_peer_id.is_empty():
		members_list.select(index)
	private_button.disabled = _selected_peer_id.is_empty()

func _selected_profile() -> Dictionary:
	var selected := members_list.get_selected_items()
	if selected.is_empty():
		return {"player_id": _selected_peer_id, "display_name": _selected_peer_id}
	return _profile_at(int(selected[0]))

func _profile_at(index: int) -> Dictionary:
	var metadata: Variant = members_list.get_item_metadata(index)
	if typeof(metadata) == TYPE_DICTIONARY:
		return (metadata as Dictionary).duplicate(true)
	return {"player_id": str(metadata), "display_name": str(metadata)}
