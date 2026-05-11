class_name WorldHUDProfileActions
extends RefCounted

var chat_service: Node
var player_profile_card: PanelContainer

func bind(new_chat_service: Node, new_player_profile_card: PanelContainer) -> void:
	chat_service = new_chat_service
	player_profile_card = new_player_profile_card

func report(profile: Dictionary) -> void:
	var online_client := _online_client()
	if online_client == null or not bool(online_client.get("is_connected")):
		_announce_system_feedback("profile.report_unavailable")
		player_profile_card.call("mark_report_sent", false)
		return
	player_profile_card.call("set_report_busy", true)
	var response: Dictionary = await online_client.call("report_player_profile", profile)
	var ok := bool(response.get("ok", false))
	player_profile_card.call("set_report_busy", false)
	player_profile_card.call("mark_report_sent", ok)
	_announce_system_feedback("profile.report_sent" if ok else "profile.report_failed")

func social(profile: Dictionary, action: String) -> void:
	var online_client := _online_client()
	var peer_id := str(profile.get("player_id", ""))
	if online_client == null or peer_id.is_empty() or not bool(online_client.get("is_connected")):
		_announce_system_feedback("profile.social_unavailable")
		return
	var response: Dictionary = await online_client.call("social_action", action, peer_id)
	var ok := bool(response.get("ok", false))
	player_profile_card.call("mark_social_action", action, ok)
	var key := "profile.follow_sent" if action == "follow" else "profile.block_sent"
	_announce_system_feedback(key if ok else "profile.social_failed")

func _announce_system_feedback(key: String) -> void:
	if chat_service != null and chat_service.has_method("add_system_message"):
		chat_service.call("add_system_message", App.t_key("chat.system.name"), App.t_key(key))

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("OnlineClient")
