extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/LiveOpsConsolePanel.tscn")
	var panel := scene.instantiate()
	root.add_child(panel)
	await process_frame

	panel.call("set_admin_token", "admin-smoke")
	panel.call("set_admin_session_snapshot", {"role": "owner"})
	panel.call("set_reviewer_snapshot", {
		"items": [{
			"game_id": "creator_liveops",
			"version": "0.1.0",
			"status": "needs_review",
			"mode_id": "casual_activity",
			"name": {"en": "Creator LiveOps"},
			"scan": {"status": "clean", "issue_count": 0},
			"ai": {"status": "approved"},
			"job": {"status": "completed"},
			"install": {"status": "not_installed"}
		}]
	})
	panel.call("set_chat_reports_snapshot", {
		"items": [{
			"id": "report-ops-1",
			"room_id": "world_town_square",
			"reason": "spam",
			"status": "open",
			"message_sender_id": "player_reported",
			"message_sender_name": "Bea",
			"message_body": "reported in live ops"
		}]
	})
	panel.call("set_moderation_snapshot", {
		"active": [{
			"id": "mod-liveops-1",
			"target_player_id": "player_reported",
			"target_name": "Muted LiveOps",
			"action": "mute",
			"scope": "room",
			"room_id": "world_town_square",
			"reason": "spam",
			"expires_at": int(Time.get_unix_time_from_system()) + 3600
		}],
		"recent": []
	})
	panel.call("set_admin_action_audit_snapshot", {
		"count": 2,
		"matched": 2,
		"items": [{
			"action": "player_map.discover",
			"status": "unlocked",
			"role": "owner",
			"target_type": "player_map",
			"target_id": "player_reported:social_trade_market_v1",
			"request_id": "ops-smoke-1",
			"note": "audit smoke"
		}]
	})
	panel.call("set_trade_history_audit_snapshot", {
		"count": 1,
		"matched": 1,
		"items": [{
			"id": "trade-liveops-1",
			"type": "sold",
			"listing_id": "listing-liveops",
			"seller_id": "seller_liveops",
			"buyer_id": "buyer_liveops",
			"item_id": "simple_chair",
			"icon_id": "icon.home",
			"price": 7
		}]
	})
	panel.call("set_ops_snapshot", {
		"rooms": {"online_count": 2, "rooms": {"world_town_square": 2}},
		"realtime": {"local_delivered": 4, "move_rate_limited": 1, "emote_rate_limited": 0},
		"chat": {"total_messages": 7, "total_reports": 1, "rejected_rate_limited": 1, "active_moderation": 1, "moderation_actions": 2},
		"fishing_rewards": {"granted": 3, "capped": 0, "replayed": 1},
		"economy": {"creator_play_rewards": 2, "creator_revenue_coins": 14, "reward_cap_hits": 1},
		"creator_payouts": {
			"total_creators": 1,
			"total_revenue_coins": 14,
			"total_revenue_events": 2,
			"items": [{
				"creator_id": "creator_liveops",
				"game_id": "creator_duel",
				"revenue_events": 2,
				"revenue_coins": 14
			}]
		},
		"alerts": {
			"highest_severity": "warning",
			"count": 1,
			"items": [{
				"area": "moderation",
				"code": "open_chat_reports",
				"severity": "warning",
				"value": 21,
				"warning": 20,
				"critical": 50
			}]
		}
	})
	panel.call("set_room_snapshot", {
		"online_count": 2,
		"rooms": {
			"world_town_square": {
				"connected": 2,
				"last_active_at": int(Time.get_unix_time_from_system()),
				"room_type": "main_city",
				"snapshot_players": 2
			}
		}
	})
	await process_frame

	for text in ["LiveOps Console", "role: owner", "Creator LiveOps", "Chat Reports", "reported in live ops", "Moderation Audit", "Muted LiveOps", "Action Audit", "player_map.discover", "Trade History", "seller_liveops", "buyer_liveops", "Debug Ops", "Inventory Audit", "Online 2", "Economy", "Creator Payouts", "creator_liveops", "creator_duel", "Alerts: warning", "open_chat_reports", "Room Drilldown", "world_town_square", "main_city", "Export CSV"]:
		if not _node_text_contains(panel, text):
			failures.append("LiveOps console missing text: %s" % text)
	if _scroll_row_card_count(panel) < 5:
		failures.append("LiveOps console row cards were not applied to audit lists.")

	panel.queue_free()
	if failures.is_empty():
		print("liveops console smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false

func _scroll_row_card_count(node: Node) -> int:
	var count := 0
	if node is ScrollContainer:
		count += _panel_descendant_count(node)
	for child in node.get_children():
		count += _scroll_row_card_count(child)
	return count

func _panel_descendant_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is PanelContainer:
			count += 1
		count += _panel_descendant_count(child)
	return count
