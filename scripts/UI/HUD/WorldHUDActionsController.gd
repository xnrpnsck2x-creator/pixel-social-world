class_name WorldHUDActionsController
extends RefCounted
signal emote_button_pressed
signal room_emote_requested(emote_id: String)
signal npc_primary_action(action_id: String)
signal home_invite_requested
signal home_visit_requested(owner_id: String)
signal map_travel_requested(map_id: String)
signal first_session_event(event_id: String)
signal overlay_layout_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const WorldHUDProfileActionsScript := preload("res://scripts/UI/HUD/WorldHUDProfileActions.gd")
const ChatActionRouterScript := preload("res://scripts/Systems/Chat/ChatActionRouter.gd")
const ACTION_BUTTON_MIN_SIZE := Vector2(44, 44)
var housing_service: Node
var minigame_registry: Node
var presence_service: Node
var chat_service: Node
var minigame_session_service: Node
var emote_button: Button
var map_button: Button
var fishing_button: Button
var home_button: Button
var inventory_button: Button
var minigames_button: Button
var social_button: Button
var mail_unread_badge: Label
var npc_dialog: PanelContainer
var online_room_panel: PanelContainer
var utility_panel: PanelContainer
var social_messages_panel: PanelContainer
var player_profile_card: PanelContainer
var chat_action_router := ChatActionRouterScript.new()
var profile_actions := WorldHUDProfileActionsScript.new()
func bind_ui(
	new_emote_button: Button,
	new_map_button: Button,
	new_fishing_button: Button,
	new_home_button: Button,
	new_inventory_button: Button,
	new_minigames_button: Button,
	new_npc_dialog: PanelContainer,
	new_online_room_panel: PanelContainer,
	new_utility_panel: PanelContainer,
	new_social_button: Button,
	new_mail_unread_badge: Label,
	new_social_messages_panel: PanelContainer,
	new_player_profile_card: PanelContainer
) -> void:
	emote_button = new_emote_button
	map_button = new_map_button
	fishing_button = new_fishing_button
	home_button = new_home_button
	inventory_button = new_inventory_button
	minigames_button = new_minigames_button
	social_button = new_social_button
	mail_unread_badge = new_mail_unread_badge
	npc_dialog = new_npc_dialog
	online_room_panel = new_online_room_panel
	utility_panel = new_utility_panel
	social_messages_panel = new_social_messages_panel
	player_profile_card = new_player_profile_card
	emote_button.pressed.connect(func() -> void: emote_button_pressed.emit())
	map_button.pressed.connect(func() -> void: show_utility_panel("map"))
	fishing_button.pressed.connect(_try_fishing)
	home_button.pressed.connect(_show_housing_status)
	inventory_button.pressed.connect(func() -> void: show_utility_panel("inventory"))
	minigames_button.pressed.connect(_toggle_room_panel)
	social_button.pressed.connect(func() -> void: show_messages_panel("mail"))
	npc_dialog.connect("primary_action", _on_npc_primary_action)
	npc_dialog.connect("close_requested", hide_npc_dialog)
	online_room_panel.close_requested.connect(hide_room_panel)
	online_room_panel.home_invite_requested.connect(_on_home_invite_requested)
	online_room_panel.home_visit_requested.connect(_on_home_visit_requested)
	online_room_panel.emote_requested.connect(_on_room_emote_requested)
	if online_room_panel.has_signal("profile_requested"):
		online_room_panel.connect("profile_requested", _on_room_profile_requested)
	if online_room_panel.has_signal("minigame_launch_requested"):
		online_room_panel.connect("minigame_launch_requested", _prepare_minigame_route)
	social_messages_panel.close_requested.connect(hide_messages_panel)
	player_profile_card.close_requested.connect(hide_profile_card)
	player_profile_card.private_chat_requested.connect(_on_profile_private_chat_requested)
	player_profile_card.home_visit_requested.connect(_on_profile_home_visit_requested)
	player_profile_card.emote_requested.connect(_on_room_emote_requested)
	player_profile_card.report_requested.connect(profile_actions.report)
	player_profile_card.follow_requested.connect(_on_profile_social_requested.bind("follow"))
	player_profile_card.block_requested.connect(_on_profile_social_requested.bind("block"))
	if social_messages_panel.has_signal("unread_count_changed"):
		social_messages_panel.connect("unread_count_changed", _on_messages_unread_count_changed)
	if utility_panel.has_signal("utility_action_requested"):
		utility_panel.connect("utility_action_requested", _on_utility_action_requested)

func bind_services(
	new_presence_service: Node,
	new_chat_service: Node,
	new_minigame_registry: Node,
	new_minigame_session_service: Node,
	new_housing_service: Node
) -> void:
	presence_service = new_presence_service
	chat_service = new_chat_service
	minigame_registry = new_minigame_registry
	minigame_session_service = new_minigame_session_service
	housing_service = new_housing_service
	chat_action_router.bind_minigame_session_service(minigame_session_service)
	profile_actions.bind(chat_service, player_profile_card)
	online_room_panel.bind_services(
		presence_service,
		chat_service,
		minigame_registry,
		minigame_session_service
	)
	if social_messages_panel.has_method("bind_presence_service"):
		social_messages_panel.call("bind_presence_service", presence_service)

func refresh_text() -> void:
	WorldHUDAssetsScript.set_action_tooltip(emote_button, "world.emote_button")
	WorldHUDAssetsScript.set_action_tooltip(map_button, "world.map_button")
	WorldHUDAssetsScript.set_action_tooltip(fishing_button, "world.fishing_button")
	WorldHUDAssetsScript.set_action_tooltip(home_button, "world.home_button")
	WorldHUDAssetsScript.set_action_tooltip(inventory_button, "world.inventory_button")
	WorldHUDAssetsScript.set_action_tooltip(minigames_button, "world.minigames_button")
	WorldHUDAssetsScript.set_action_tooltip(social_button, "world.social_button")

func apply_icons() -> void:
	WorldHUDAssetsScript.configure_action_button(emote_button, "emote.laugh", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(map_button, "icon.map", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(fishing_button, "icon.fishing", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(home_button, "icon.home", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(inventory_button, "icon.backpack", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(minigames_button, "icon.games", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_action_button(social_button, "icon.mail", ACTION_BUTTON_MIN_SIZE)
	_configure_unread_badge()

func show_room_panel() -> void:
	hide_npc_dialog()
	hide_utility_panel()
	hide_messages_panel()
	hide_profile_card()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_overlay = 'room'", true)
	online_room_panel.visible = true
	overlay_layout_requested.emit()
	first_session_event.emit("games_opened")
	if minigame_session_service != null:
		minigame_session_service.refresh_sessions()

func join_chat_invite(action: Dictionary) -> void:
	show_room_panel()
	await chat_action_router.handle_action(action)

func hide_room_panel() -> void:
	online_room_panel.visible = false
	overlay_layout_requested.emit()

func show_utility_panel(panel_id: String) -> void:
	hide_npc_dialog()
	hide_room_panel()
	hide_messages_panel()
	hide_profile_card()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_overlay = %s" % JSON.stringify(panel_id), true)
	utility_panel.call("show_panel", panel_id)
	overlay_layout_requested.emit()
	if panel_id == "map":
		first_session_event.emit("map_opened")

func hide_utility_panel() -> void:
	if utility_panel != null:
		utility_panel.call("hide_panel")
		overlay_layout_requested.emit()

func show_messages_panel(tab_id: String = "mail") -> void:
	hide_npc_dialog()
	hide_room_panel()
	hide_utility_panel()
	hide_profile_card()
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_overlay = %s" % JSON.stringify(tab_id), true)
	social_messages_panel.call("show_panel", tab_id)
	overlay_layout_requested.emit()
func show_player_profile(profile: Dictionary) -> void: _on_room_profile_requested(profile)

func hide_messages_panel() -> void:
	if social_messages_panel != null:
		social_messages_panel.call("hide_panel")
		overlay_layout_requested.emit()

func hide_profile_card() -> void:
	if player_profile_card != null:
		player_profile_card.call("hide_card")
		overlay_layout_requested.emit()

func _on_messages_unread_count_changed(unread_count: int) -> void:
	if mail_unread_badge == null:
		return
	mail_unread_badge.visible = unread_count > 0
	mail_unread_badge.text = "9+" if unread_count > 9 else str(unread_count)

func show_npc_dialog(record: Dictionary) -> void:
	hide_utility_panel()
	hide_messages_panel()
	hide_profile_card()
	npc_dialog.call("show_dialog", record)

func hide_npc_dialog() -> void:
	npc_dialog.call("hide_dialog")

func _try_fishing() -> void:
	if minigame_session_service != null:
		var response: Dictionary = await minigame_session_service.create_session("fishing")
		if bool(response.get("ok", false)):
			_prepare_minigame_route()
			minigame_session_service.launch_game("fishing")
		return
	SaveSystem.set_profile_value("pending_minigame_id", "fishing")
	SaveSystem.save_profile()
	_prepare_minigame_route()
	SceneRouter.route_to("minigame_fishing")

func _show_housing_status() -> void:
	if housing_service == null:
		return
	SceneRouter.route_to("home_edit")

func _toggle_room_panel() -> void:
	if online_room_panel.visible:
		hide_room_panel()
	else:
		show_room_panel()

func _prepare_minigame_route() -> void:
	hide_npc_dialog()
	hide_room_panel()
	hide_utility_panel()
	hide_messages_panel()
	hide_profile_card()
	overlay_layout_requested.emit()

func _on_npc_primary_action(action_id: String) -> void:
	npc_primary_action.emit(action_id)

func _on_home_invite_requested() -> void:
	home_invite_requested.emit()

func _on_home_visit_requested(owner_id: String) -> void:
	home_visit_requested.emit(owner_id)

func _on_room_emote_requested(emote_id: String) -> void:
	room_emote_requested.emit(emote_id)

func _on_room_profile_requested(profile: Dictionary) -> void:
	hide_npc_dialog()
	hide_room_panel()
	hide_utility_panel()
	hide_messages_panel()
	player_profile_card.call("show_profile", profile)
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"): Engine.get_singleton("JavaScriptBridge").call("eval", "globalThis.__psw_debug_overlay = 'profile'", true)
	overlay_layout_requested.emit()

func _on_profile_private_chat_requested(peer_id: String) -> void:
	hide_profile_card()
	if social_messages_panel.has_method("open_private_conversation"):
		social_messages_panel.call("open_private_conversation", peer_id)

func _on_profile_home_visit_requested(owner_id: String) -> void:
	hide_profile_card()
	home_visit_requested.emit(owner_id)

func _on_profile_social_requested(profile: Dictionary, action: String) -> void:
	profile_actions.social(profile, action)

func _on_utility_action_requested(action_id: String) -> void:
	if action_id.begins_with("map:"):
		hide_utility_panel()
		map_travel_requested.emit(action_id.trim_prefix("map:"))
		return
	match action_id:
		"home":
			_show_housing_status()
		"games":
			show_room_panel()
		"mail":
			show_messages_panel("mail")
		"map_atlas":
			show_utility_panel("map_atlas")
		"shop", "notice", "inventory", "creator":
			show_utility_panel(action_id)

func _configure_unread_badge() -> void:
	if mail_unread_badge == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.16, 0.13, 0.96)
	style.border_color = Color(0.98, 0.86, 0.52, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	mail_unread_badge.add_theme_stylebox_override("normal", style)
	mail_unread_badge.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0))
	mail_unread_badge.add_theme_font_size_override("font_size", 10)
	mail_unread_badge.visible = false
