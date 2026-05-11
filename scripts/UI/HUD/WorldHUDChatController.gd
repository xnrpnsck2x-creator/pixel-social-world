class_name WorldHUDChatController
extends RefCounted

signal join_invite_requested(action: Dictionary)
signal layout_refresh_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const ACTION_BUTTON_MIN_SIZE := Vector2(44, 44)

var chat_service: Node
var minigame_registry: Node
var player_name := ""
var active_channel_id := ""
var chat_log: Label
var invite_button: Button
var channel_picker: OptionButton
var chat_input: LineEdit
var send_button: Button

func bind_ui(
	new_chat_log: Label,
	new_invite_button: Button,
	new_channel_picker: OptionButton,
	new_chat_input: LineEdit,
	new_send_button: Button
) -> void:
	chat_log = new_chat_log
	invite_button = new_invite_button
	channel_picker = new_channel_picker
	chat_input = new_chat_input
	send_button = new_send_button
	invite_button.pressed.connect(_on_invite_pressed)
	channel_picker.item_selected.connect(_on_channel_selected)
	chat_input.text_submitted.connect(func(_text: String) -> void: _send_chat())
	send_button.pressed.connect(_send_chat)

func bind_service(new_chat_service: Node) -> void:
	chat_service = new_chat_service
	chat_service.message_added.connect(_on_message_added)
	build_channel_picker()
	refresh_chat_log()

func bind_minigame_registry(new_minigame_registry: Node) -> void:
	minigame_registry = new_minigame_registry
	_refresh_invite_button()

func set_player_name(display_name: String) -> void:
	player_name = display_name

func refresh_text() -> void:
	if chat_input != null:
		chat_input.placeholder_text = App.t_key("world.chat_placeholder")
	if channel_picker != null:
		channel_picker.tooltip_text = App.t_key("world.channel_picker")
	WorldHUDAssetsScript.set_action_tooltip(send_button, "world.send_button")
	build_channel_picker()
	refresh_chat_log()

func apply_icon() -> void:
	WorldHUDAssetsScript.configure_action_button(send_button, "icon.send", ACTION_BUTTON_MIN_SIZE)
	WorldHUDAssetsScript.configure_button_frame(invite_button)

func refresh_chat_log() -> void:
	if chat_service == null or chat_log == null:
		return
	var rows := PackedStringArray()
	for message in chat_service.get_visible_messages(5):
		rows.append(App.format_key("chat.message_format", {
			"channel": chat_service.get_channel_name(str(message.get("channel_id", ""))),
			"name": str(message.get("sender_name", "")),
			"body": str(message.get("body", ""))
		}))
	chat_log.text = "\n".join(rows)
	_refresh_invite_button()

func build_channel_picker() -> void:
	if channel_picker == null or chat_service == null:
		return
	var previous_channel := active_channel_id
	if previous_channel.is_empty():
		previous_channel = chat_service.get_default_channel_id()
	channel_picker.clear()
	active_channel_id = previous_channel
	var selected_index := 0
	for channel in chat_service.get_postable_channels():
		var channel_id := str(channel.get("id", ""))
		var index := channel_picker.item_count
		channel_picker.add_item(App.t_key(str(channel.get("name_key", ""))))
		channel_picker.set_item_metadata(index, channel_id)
		if channel_id == previous_channel:
			selected_index = index
	if channel_picker.item_count > 0:
		channel_picker.select(selected_index)
		active_channel_id = str(channel_picker.get_item_metadata(selected_index))
		chat_service.set_view_channel(active_channel_id)

func _send_chat() -> void:
	if chat_service == null or chat_input == null:
		return
	var body: String = chat_input.text.strip_edges()
	if body.is_empty():
		return
	var channel_id: String = active_channel_id
	if channel_id.is_empty():
		channel_id = chat_service.get_default_channel_id()
	if chat_service.send_local_message(channel_id, player_name, body):
		chat_input.clear()
		_release_mobile_keyboard()

func _release_mobile_keyboard() -> void:
	if OS.get_name() not in ["Android", "iOS"]:
		return
	chat_input.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _on_channel_selected(index: int) -> void:
	if channel_picker == null:
		return
	active_channel_id = str(channel_picker.get_item_metadata(index))
	if chat_service != null:
		chat_service.set_view_channel(active_channel_id)
		chat_service.load_history(chat_service.room_id, active_channel_id)
	refresh_chat_log()

func _on_message_added(_message: Dictionary) -> void:
	refresh_chat_log()

func _refresh_invite_button() -> void:
	if invite_button == null:
		return
	var was_visible := invite_button.visible
	var invite := _latest_join_invite()
	invite_button.visible = not invite.is_empty()
	invite_button.disabled = invite.is_empty()
	if invite.is_empty():
		invite_button.text = ""
		if was_visible != invite_button.visible:
			layout_refresh_requested.emit()
		return
	var action: Dictionary = invite.get("action", {}) as Dictionary
	var message: Dictionary = invite.get("message", {}) as Dictionary
	invite_button.text = App.format_key("world.session_invite_chip_format", {
		"game": _game_name(str(action.get("game_id", ""))),
		"name": str(message.get("sender_name", ""))
	})
	invite_button.tooltip_text = App.t_key("world.session_invite_chip_tooltip")
	if was_visible != invite_button.visible:
		layout_refresh_requested.emit()

func _latest_join_invite() -> Dictionary:
	if chat_service == null or not chat_service.has_method("get_latest_action"):
		return {}
	return chat_service.call("get_latest_action", "join_minigame") as Dictionary

func _game_name(game_id: String) -> String:
	if minigame_registry != null:
		var game: Dictionary = minigame_registry.get_minigame(game_id)
		if not game.is_empty():
			return App.t_key(str(game.get("name_key", game_id)))
	return game_id

func _on_invite_pressed() -> void:
	var invite := _latest_join_invite()
	if invite.is_empty():
		return
	var action: Dictionary = invite.get("action", {}) as Dictionary
	join_invite_requested.emit(action.duplicate(true))
