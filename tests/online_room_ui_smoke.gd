extends SceneTree

const SmokeAssertions := preload("res://tests/helpers/MainCitySmokeAssertions.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var assertions := SmokeAssertions.new()
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "offline-player",
		"device_id": "test-device",
		"display_name": "UI Smoke",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "main_city",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"map_activity_inventory": {"trail_token": {"item_id": "trail_token", "quantity": 2, "rarity": "common"}},
		"map_activity_skill_xp": {"exploration": 4},
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")

	root.get_node("OnlineClient").call("configure", {
		"offline_mode_enabled": true,
		"network": {"online_enabled": false}
	})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame

	var hud := instance.get_node("WorldHUD")
	var panel := hud.get_node("Root/OnlineRoomPanel")
	var chat_service := instance.get_node("ServiceRoot/ChatService")
	var presence_service := instance.get_node("ServiceRoot/PresenceService")
	var chat_invite_button := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/ChatInviteButton") as Button
	var games_button := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/MinigamesButton")
	var inventory_button := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/InventoryButton")
	var utility_panel := hud.get_node("Root/WorldUtilityPanel")
	if hud.get("chat_controller") == null:
		failures.append("World HUD chat was not split into a chat controller.")
	if hud.get("action_controller") == null:
		failures.append("World HUD actions were not split into an action controller.")
	elif hud.get("action_controller").get("chat_action_router") == null:
		failures.append("World HUD actions did not bind a chat action router.")

	if not assertions.has_image2_panel(hud.get_node("Root/TopBar")):
		failures.append("HUD TopBar is not using an Image 2 panel frame.")
	for badge_name in ["TitleBadge", "PlayerBadge", "CoinBadge", "PresenceBadge"]:
		if not assertions.has_image2_panel(hud.get_node("Root/TopBar/TopMargin/TopRow/%s" % badge_name)):
			failures.append("HUD %s is not using an Image 2 badge frame." % badge_name)
	if not assertions.has_image2_panel(hud.get_node("Root/BottomBar")):
		failures.append("HUD BottomBar is not using an Image 2 panel frame.")
	if not assertions.has_image2_button(games_button):
		failures.append("HUD minigames button is not using an Image 2 button frame.")
	if not assertions.has_image2_button(inventory_button):
		failures.append("HUD inventory button is not using an Image 2 button frame.")
	if not assertions.has_image2_line_edit(hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/ChatInput")):
		failures.append("HUD chat input is not using an Image 2 field frame.")
	if not assertions.has_image2_button(chat_invite_button):
		failures.append("HUD chat invite chip is not using an Image 2 button frame.")
	var hud_chat_input := hud.get_node("Root/BottomBar/BottomMargin/BottomRows/InputRow/ChatInput") as LineEdit
	hud_chat_input.text = "Android enter hello"
	hud_chat_input.emit_signal("text_submitted", hud_chat_input.text)
	await process_frame
	if not assertions.chat_rows_contain(chat_service.call("get_recent_messages", 3), "Android enter hello"):
		failures.append("HUD chat input did not send when text_submitted was emitted.")
	if not hud_chat_input.text.is_empty():
		failures.append("HUD chat input did not clear after text_submitted send.")
	var long_player_name := "VeryVeryLongPlayerNameForTopBarOverflowCheck"
	var player_label := hud.get_node("%PlayerLabel") as Label
	hud.call("set_player_name", long_player_name)
	await process_frame
	if player_label.text.contains(long_player_name) or not player_label.text.contains("..."):
		failures.append("HUD top bar did not shorten a long player name.")
	if not player_label.tooltip_text.contains(long_player_name):
		failures.append("HUD top bar did not preserve the full player name in tooltip.")
	inventory_button.pressed.emit()
	await process_frame
	if not bool(utility_panel.get("visible")):
		failures.append("Inventory utility panel did not open.")
	if not assertions.has_image2_panel(utility_panel):
		failures.append("Inventory utility panel is not using an Image 2 panel frame.")
	var utility_title := utility_panel.get_node("Margin/Rows/HeaderRow/TitleLabel") as Label
	if utility_title == null or utility_title.text != "Inventory":
		failures.append("Inventory utility panel did not render localized title.")
	if not assertions.utility_rows_contain(utility_panel, "Starter Wallpaper"):
		failures.append("Inventory utility panel did not render owned item rows.")
	if not assertions.utility_rows_contain(utility_panel, "Trail Token") or not assertions.utility_rows_contain(utility_panel, "Exploration"):
		failures.append("Inventory utility panel did not render map activity rewards.")
	if assertions.utility_row_card_count(utility_panel) < 1:
		failures.append("Inventory utility panel did not apply v2 row card frames.")
	utility_panel.call("show_panel", "shop")
	await process_frame
	if not assertions.utility_rows_contain(utility_panel, "Simple Chair"):
		failures.append("Shop utility panel did not render configured shop stock.")
	utility_panel.call("show_panel", "mail")
	await process_frame
	if not assertions.utility_rows_contain(utility_panel, "Welcome home"):
		failures.append("Mail utility panel did not render configured messages.")
	utility_panel.call("show_panel", "notice")
	await process_frame
	if not assertions.utility_rows_contain(utility_panel, "Creator alpha"):
		failures.append("Notice utility panel did not render configured notices.")
	utility_panel.call("show_panel", "creator")
	await process_frame
	if utility_title == null or utility_title.text != "Creator Lab":
		failures.append("Creator utility panel did not render localized title.")
	if not assertions.utility_rows_contain(utility_panel, "Side-Scrolling 2D"):
		failures.append("Creator utility panel did not render side-scroller mode.")
	if not assertions.utility_rows_contain(utility_panel, "2D Fighting"):
		failures.append("Creator utility panel did not render 2D fighting mode.")
	if not assertions.utility_rows_contain(utility_panel, "Battle Royale"):
		failures.append("Creator utility panel did not render battle royale mode.")
	if not assertions.utility_rows_contain(utility_panel, "Draft Review Probe"):
		failures.append("Creator utility panel did not render draft submission status row.")
	if not assertions.utility_rows_contain(utility_panel, "Package Intake Probe"):
		failures.append("Creator utility panel did not render package intake status row.")
	if not assertions.utility_rows_contain(utility_panel, "Review Signals"):
		failures.append("Creator utility panel did not render reviewer signal row.")
	if not assertions.utility_rows_contain(utility_panel, "Creator Status Page"):
		failures.append("Creator utility panel did not render creator status page row.")
	if assertions.utility_row_card_count(utility_panel) < 10:
		failures.append("Creator utility panel did not apply v2 row card frames.")
	utility_panel.call("hide_panel")
	games_button.pressed.emit()
	await process_frame

	if not bool(panel.get("visible")):
		failures.append("Online room panel did not open.")
	if not assertions.has_image2_panel(panel):
		failures.append("Online room panel is not using an Image 2 panel frame.")
	var report_button := panel.get_node("Margin/Rows/HeaderRow/ReportButton") as Button
	if not assertions.has_image2_button(report_button):
		failures.append("Chat report button is not using an Image 2 button frame.")
	if not report_button.disabled:
		failures.append("Chat report button should be disabled without a reportable online message.")
	var room_chat_row := panel.get_node("Margin/Rows/RoomChatRow") as HBoxContainer
	var room_chat_input := panel.get_node("Margin/Rows/RoomChatRow/RoomChatInput") as LineEdit
	var room_send_button := panel.get_node("Margin/Rows/RoomChatRow/RoomSendButton") as Button
	var laugh_emote_button := panel.get_node("Margin/Rows/QuickEmoteRow/LaughEmoteButton") as Button
	var heart_emote_button := panel.get_node("Margin/Rows/QuickEmoteRow/HeartEmoteButton") as Button
	var exclamation_emote_button := panel.get_node("Margin/Rows/QuickEmoteRow/ExclamationEmoteButton") as Button
	if not assertions.has_image2_line_edit(room_chat_input):
		failures.append("Room chat input is not using an Image 2 field frame.")
	if not assertions.has_image2_button(room_send_button):
		failures.append("Room chat send button is not using an Image 2 button frame.")
	if not assertions.has_image2_button(laugh_emote_button) or not assertions.has_image2_button(heart_emote_button) or not assertions.has_image2_button(exclamation_emote_button):
		failures.append("Room quick emote buttons are not using Image 2 button frames.")
	laugh_emote_button.pressed.emit()
	await process_frame
	var emote_bubble := instance.get_node("PlayerRoot/LocalPlayer/EmoteBubble") as Node2D
	if not bool(emote_bubble.get("visible")):
		failures.append("Room quick emote button did not trigger the local overhead emote bubble.")
	room_chat_input.text = "Hello from room panel"
	room_send_button.pressed.emit()
	await process_frame
	var chat_preview := panel.get_node("Margin/Rows/ChatPreviewLabel") as Label
	if not chat_preview.text.contains("Hello from room panel"):
		failures.append("Room chat panel did not send and preview a local message.")
	if not room_chat_input.text.is_empty():
		failures.append("Room chat input did not clear after send.")
	panel.call("_announce_game_invite", "fishing")
	await process_frame
	if not chat_preview.text.contains("hosting Fishing"):
		failures.append("Room panel did not post a localized minigame invite message.")
	var panel_invite_button := panel.get_node("Margin/Rows/PanelInviteButton") as Button
	if not assertions.has_image2_button(panel_invite_button):
		failures.append("Room invite chip is not using an Image 2 button frame.")
	if not bool(panel_invite_button.get("visible")) or not panel_invite_button.text.contains("Join Fishing"):
		failures.append("Room invite chip did not show the latest minigame invite.")
	if not bool(chat_invite_button.get("visible")) or not chat_invite_button.text.contains("Join Fishing"):
		failures.append("HUD chat invite chip did not show the latest minigame invite.")
	var latest_invite: Dictionary = chat_service.call("get_latest_action", "join_minigame")
	var invite_action: Dictionary = latest_invite.get("action", {}) as Dictionary
	if latest_invite.is_empty() or str(invite_action.get("game_id", "")) != "fishing":
		failures.append("Room minigame invite did not register a join_minigame action.")
	if str(invite_action.get("session_id", "")) != "local_fishing":
		failures.append("Room minigame invite did not target the local fishing session.")
	if not assertions.has_image2_button(panel.get_node("Margin/Rows/ActionRow/HostFishingButton")):
		failures.append("Host Fishing button is not using an Image 2 button frame.")
	var invite_home_button := panel.get_node("Margin/Rows/HousingActionRow/InviteHomeButton")
	var visit_home_button := panel.get_node("Margin/Rows/HousingActionRow/VisitHomeButton")
	if not assertions.has_image2_button(invite_home_button):
		failures.append("Invite Home button is not using an Image 2 button frame.")
	if not assertions.has_image2_button(visit_home_button):
		failures.append("Visit Home button is not using an Image 2 button frame.")
	panel.home_visit_requested.connect(func(owner_id: String) -> void:
		panel.set_meta("visit_owner", owner_id)
	)
	panel.call("_visit_first_member_home")
	await process_frame
	var visit_owner := str(panel.get_meta("visit_owner", ""))
	if visit_owner != "offline-player":
		failures.append("Visit Home did not target the local fallback home: %s" % visit_owner)

	var members_label := panel.get_node("Margin/Rows/MembersLabel") as Label
	if not members_label.text.contains("UI Smoke"):
		failures.append("Presence member list did not show the local player.")
	if not members_label.text.contains("you"):
		failures.append("Presence member list did not mark the local player.")
	var fake_members: Array[Dictionary] = [
		{"player_id": "offline-player", "room_id": "world_town_square", "display_name": "UI Smoke", "last_seen_at": int(Time.get_unix_time_from_system())},
		{"player_id": "peer-room-smoke", "room_id": "world_town_square", "display_name": "Peer Room", "last_seen_at": int(Time.get_unix_time_from_system())}
	]
	presence_service.set("members", fake_members)
	panel.call("_refresh_presence")
	await process_frame
	var members_list := panel.get_node("Margin/Rows/MemberActionRow/MembersList") as ItemList
	var private_member_button := panel.get_node("Margin/Rows/MemberActionRow/PrivateMemberButton") as Button
	if members_list.get_item_count() < 2 or not members_list.get_item_text(1).contains("Peer Room"):
		failures.append("Presence member picker did not render a selectable remote player.")
	if private_member_button.disabled:
		failures.append("Presence member picker did not enable private chat for a remote player.")
	panel.profile_requested.connect(func(profile: Dictionary) -> void:
		panel.set_meta("profile_peer", str(profile.get("player_id", "")))
	)
	private_member_button.pressed.emit()
	await process_frame
	if str(panel.get_meta("profile_peer", "")) != "peer-room-smoke":
		failures.append("Presence member profile action did not emit the selected peer.")

	var sessions_label := panel.get_node("Margin/Rows/SessionsLabel") as Label
	if sessions_label.text.is_empty():
		failures.append("Session list did not render.")
	if not sessions_label.text.contains("Host you") or not sessions_label.text.contains("3 open"):
		failures.append("Session list did not show host and open slot state: %s" % sessions_label.text)
	if sessions_label.max_lines_visible > 3:
		failures.append("Online room regular layout did not cap session rows.")
	var game_catalog_label := panel.get_node("Margin/Rows/GameCatalogLabel") as Label
	if game_catalog_label.text.is_empty() or not game_catalog_label.text.contains("Fishing"):
		failures.append("Game lobby catalog did not render enabled games.")

	var presence_label := hud.get_node("%PresenceLabel") as Label
	if presence_label.text.is_empty():
		failures.append("Presence heartbeat label did not render.")
	presence_service.set("_last_heartbeat_msec", Time.get_ticks_msec())
	hud.call("_on_presence_updated", presence_service.get_members(), true, 0)
	var offline_text := str(root.get_node("App").call("t_key", "ui.status.offline"))
	if presence_label.text.contains(offline_text):
		failures.append("Presence heartbeat label showed offline despite a fresh heartbeat: %s" % presence_label.text)
	panel.call("set_compact_layout", true)
	await process_frame
	if panel.custom_minimum_size.y > 226.0:
		failures.append("Online room compact layout did not reduce panel height.")
	if bool(members_label.get("visible")):
		failures.append("Online room compact layout kept the full members list visible.")
	if not bool(room_chat_row.get("visible")):
		failures.append("Online room compact layout hid the room chat input.")
	room_chat_input.text = "Compact room hello"
	room_send_button.pressed.emit()
	await process_frame
	if not assertions.chat_rows_contain(chat_service.call("get_recent_messages", 3), "Compact room hello"):
		failures.append("Online room compact chat did not send through ChatService.")
	if not room_chat_input.text.is_empty():
		failures.append("Online room compact chat input did not clear after send.")
	if sessions_label.max_lines_visible > 2:
		failures.append("Online room compact layout did not cap session rows.")
	panel.call("set_compact_layout", false)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("online room ui smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
