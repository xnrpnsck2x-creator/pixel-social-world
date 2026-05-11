extends SceneTree

const SAVE_KEY := "first_session_guide_completed_ids"

class FakeChatService:
	extends Node
	signal message_added(message: Dictionary)
	var system_messages: Array[String] = []

	func add_system_message(_sender_name: String, body: String) -> void:
		system_messages.append(body)
		message_added.emit({
			"sender_id": "system",
			"channel_id": "system",
			"body": body
		})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "first-session-guide-player",
		"device_id": "test-device",
		"display_name": "Guide Tester",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": []
	})
	save_system.call("_apply_defaults")
	root.get_node("App").call("load_localization", "en")

	var hud_scene: PackedScene = load("res://scenes/ui/WorldHUD.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.first_session_guide.set_enabled(true)
	await process_frame
	var chat_service := FakeChatService.new()
	root.add_child(chat_service)
	hud.first_session_guide.bind_chat_service(chat_service)

	var panel := hud.get_node("Root/FirstSessionGuidePanel") as PanelContainer
	var body := hud.get_node("%FirstSessionGuideBody") as Label
	var progress := hud.get_node("%FirstSessionGuideProgress") as Label
	if panel == null or not panel.visible:
		failures.append("First-session guide did not appear for a new profile.")
	elif not _node_tree_contains(panel, "First Errand"):
		failures.append("First-session guide did not start at the NPC objective.")

	hud.first_session_guide.layout(Vector2(375, 480))
	await process_frame
	if body == null or body.visible:
		failures.append("First-session guide did not collapse body copy in narrow layout.")
	hud.first_session_guide.layout(Vector2(844, 390))
	await process_frame
	if panel.size.y > 42.0 or panel.size.x > 240.0:
		failures.append("First-session guide did not compact into a mobile landscape objective chip: %s." % panel.size)
	if body == null or body.visible:
		failures.append("First-session guide mobile landscape chip should hide body copy.")
	if progress == null or progress.visible:
		failures.append("First-session guide mobile landscape chip should hide progress text.")
	hud.first_session_guide.layout(Vector2(960, 540))
	await process_frame
	if panel.size.y > 42.0 or panel.size.x > 240.0:
		failures.append("First-session guide did not compact at the 960x540 mobile design baseline: %s." % panel.size)
	if body == null or body.visible:
		failures.append("First-session guide 960x540 chip should hide body copy.")
	if progress == null or progress.visible:
		failures.append("First-session guide 960x540 chip should hide progress text.")

	hud.first_session_guide.set_enabled(false)
	await process_frame
	if panel.visible:
		failures.append("First-session guide did not hide when disabled by map context.")
	hud.first_session_guide.set_enabled(true)
	await process_frame
	if not panel.visible or not _node_tree_contains(panel, "First Errand"):
		failures.append("First-session guide did not restore when returning to the starter map.")

	hud.get_node("%MapButton").pressed.emit()
	await process_frame
	if not _node_tree_contains(panel, "First Errand"):
		failures.append("Direct map button should not advance past the first visible objective.")

	hud.show_npc_dialog({
		"name_key": "npc.event_guide.name",
		"dialogue_key": "npc.event_guide.dialogue",
		"primary_action_key": "world.panel.action.games",
		"primary_action_id": "games"
	})
	await process_frame
	if not _node_tree_contains(panel, "Market Stalls"):
		failures.append("NPC completion did not skip the already completed map objective.")

	hud.show_social_facility_panel("trade")
	await process_frame
	if not _node_tree_contains(panel, "Game Hall"):
		failures.append("Trade panel did not advance the first-session guide.")

	hud.get_node("%MinigamesButton").pressed.emit()
	await process_frame
	if not _node_tree_contains(panel, "A Small Hello"):
		failures.append("Direct games button did not advance to the chat objective.")

	chat_service.message_added.emit({
		"sender_id": save_system.call("get_player_id"),
		"channel_id": "global",
		"body": "hello town"
	})
	await process_frame
	if panel.visible:
		failures.append("Local chat completion did not hide the completed first-session guide.")
	if int(save_system.call("get_coin_balance")) != 30:
		failures.append("First-session guide reward did not add exactly 5 coins.")
	var coin_label := hud.get_node("%CoinLabel") as Label
	if coin_label == null or not coin_label.text.contains("30"):
		failures.append("First-session guide reward did not refresh the HUD coin label.")
	if not bool(save_system.call("get_profile_value", "first_session_guide_reward_claimed", false)):
		failures.append("First-session guide reward claim flag was not persisted.")
	if not bool(save_system.call("validate_coin_ledger")):
		failures.append("First-session guide reward broke the local coin ledger.")
	if not _ledger_contains_source(save_system.call("get_coin_ledger"), "first_session.guide_complete"):
		failures.append("First-session guide reward did not use the expected ledger source.")
	if chat_service.system_messages.is_empty() or not chat_service.system_messages.back().contains("+5"):
		failures.append("First-session guide reward did not show a system chat notice.")

	hud.first_session_guide.record_event("chat_sent")
	await process_frame
	if int(save_system.call("get_coin_balance")) != 30:
		failures.append("First-session guide reward was granted more than once.")

	chat_service.free()
	hud.free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("first session guide smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _node_tree_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_tree_contains(child, text):
			return true
	return false

func _ledger_contains_source(ledger: Array, source_id: String) -> bool:
	for event in ledger:
		if typeof(event) == TYPE_DICTIONARY and str((event as Dictionary).get("source_id", "")) == source_id:
			return true
	return false
