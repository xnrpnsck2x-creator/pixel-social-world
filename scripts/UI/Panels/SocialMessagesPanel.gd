class_name SocialMessagesPanel
extends PanelContainer

signal close_requested
signal unread_count_changed(unread_count: int)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const SocialMessagesPanelRowsScript := preload("res://scripts/UI/Panels/SocialMessagesPanelRows.gd")
const SocialMessagesPanelUnreadControllerScript := preload("res://scripts/UI/Panels/SocialMessagesPanelUnreadController.gd")

var presence_service: Node
var _active_tab := "mail"
var _latest_reportable_private_message := {}
var _last_unread_count := 0
var _unread_controller

@onready var title_label: Label = %TitleLabel
@onready var mail_tab_button: Button = %MailTabButton
@onready var private_tab_button: Button = %PrivateTabButton
@onready var refresh_button: Button = %RefreshButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel
@onready var mailbox_box: VBoxContainer = %MailboxBox
@onready var mail_scroll: ScrollContainer = %MailScroll
@onready var mail_rows: VBoxContainer = %MailRows
@onready var private_box: VBoxContainer = %PrivateBox
@onready var peer_input: LineEdit = %PeerInput
@onready var conversation_scroll: ScrollContainer = %ConversationScroll
@onready var conversation_rows: VBoxContainer = %ConversationRows
@onready var private_scroll: ScrollContainer = %PrivateScroll
@onready var private_rows: VBoxContainer = %PrivateRows
@onready var private_input: LineEdit = %PrivateInput
@onready var private_send_button: Button = %PrivateSendButton
@onready var private_report_button: Button = %PrivateReportButton

func _ready() -> void:
	visible = false
	_app().locale_changed.connect(_on_locale_changed)
	mail_tab_button.pressed.connect(func() -> void: _set_tab("mail"))
	private_tab_button.pressed.connect(func() -> void: _set_tab("private"))
	refresh_button.pressed.connect(_refresh_active_tab)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	private_send_button.pressed.connect(_send_private)
	private_report_button.pressed.connect(_report_private)
	peer_input.text_submitted.connect(func(_text: String) -> void: _refresh_private())
	private_input.text_submitted.connect(func(_text: String) -> void: _send_private())
	_unread_controller = SocialMessagesPanelUnreadControllerScript.new()
	_unread_controller.count_changed.connect(_on_unread_count_changed)
	_unread_controller.bind(self)
	_apply_image2_style()
	_refresh_text()

func bind_presence_service(new_presence_service: Node) -> void:
	presence_service = new_presence_service

func show_panel(tab_id: String = "mail") -> void:
	_active_tab = tab_id if tab_id == "private" else "mail"
	visible = true
	_prefill_peer_from_presence()
	_refresh_text()
	await _refresh_active_tab()

func hide_panel() -> void: visible = false

func open_private_conversation(peer_id: String) -> void:
	peer_input.text = peer_id
	await show_panel("private")

func get_unread_count() -> int: return _last_unread_count

func set_compact_layout(enabled: bool) -> void:
	custom_minimum_size = Vector2(300, 220) if enabled else Vector2(340, 360)
	mail_scroll.custom_minimum_size = Vector2(0, 96) if enabled else Vector2(0, 188)
	conversation_scroll.custom_minimum_size = Vector2(0, 48) if enabled else Vector2(0, 72)
	private_scroll.custom_minimum_size = Vector2(0, 84) if enabled else Vector2(0, 132)
	private_input.custom_minimum_size = Vector2(0, 32) if enabled else Vector2(0, 38)
	peer_input.custom_minimum_size = Vector2(0, 32) if enabled else Vector2(0, 38)

func _set_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_refresh_text()
	await _refresh_active_tab()

func _refresh_text() -> void:
	title_label.text = _t("messages.title")
	mail_tab_button.text = _t("messages.tab.mail")
	private_tab_button.text = _t("messages.tab.private")
	refresh_button.text = ""
	refresh_button.tooltip_text = _t("messages.refresh")
	close_button.text = ""
	close_button.tooltip_text = _t("ui.action.close")
	peer_input.placeholder_text = _t("messages.private.peer_placeholder")
	private_input.placeholder_text = _t("messages.private.input_placeholder")
	private_send_button.text = _t("messages.private.send")
	private_report_button.text = _t("messages.private.report")
	mailbox_box.visible = _active_tab == "mail"
	private_box.visible = _active_tab == "private"
	mail_tab_button.disabled = _active_tab == "mail"
	private_tab_button.disabled = _active_tab == "private"

func _refresh_active_tab() -> void:
	if _active_tab == "private":
		await _refresh_private()
	else:
		await _refresh_mailbox()

func _refresh_mailbox() -> void:
	_clear_rows(mail_rows)
	if not _online_ready():
		status_label.text = _t("messages.status.offline")
		_set_mail_unread_count(0)
		SocialMessagesPanelRowsScript.add_empty_row(mail_rows, "icon.mail", _t("messages.mail.empty"))
		return
	var response: Dictionary = await _online_client().call("fetch_mailbox", 30)
	if not bool(response.get("ok", false)):
		status_label.text = _t("messages.status.mail_failed")
		_set_mail_unread_count(0)
		SocialMessagesPanelRowsScript.add_empty_row(mail_rows, "icon.mail", _t("messages.mail.empty"))
		return
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	var unread := SocialMessagesPanelRowsScript.unread_count(messages)
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY:
			var mail_id := str((message as Dictionary).get("id", ""))
			SocialMessagesPanelRowsScript.add_mail_row(mail_rows, message as Dictionary, _app(), Callable(self, "_mark_mail_read").bind(mail_id))
	if messages.is_empty():
		SocialMessagesPanelRowsScript.add_empty_row(mail_rows, "icon.mail", _t("messages.mail.empty"))
	_set_mail_unread_count(unread)
	status_label.text = _fmt("messages.status.mail_summary_format", {
		"count": messages.size(),
		"unread": unread
	})

func _refresh_private() -> void:
	_clear_rows(private_rows)
	_latest_reportable_private_message = {}
	private_report_button.disabled = true
	if not _online_ready():
		status_label.text = _t("messages.status.offline")
		_set_private_unread_count(0)
		return
	await _refresh_private_conversations()
	var peer_id := peer_input.text.strip_edges()
	if peer_id.is_empty():
		status_label.text = _t("messages.status.peer_required")
		SocialMessagesPanelRowsScript.add_empty_row(private_rows, "icon.chat", _t("messages.private.empty"))
		return
	var response: Dictionary = await _online_client().call("fetch_private_conversation", peer_id, 30)
	if not bool(response.get("ok", false)):
		status_label.text = _t("messages.status.private_failed")
		return
	var messages: Array = (response.get("data", {}) as Dictionary).get("messages", []) as Array
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY:
			_add_private_message(message as Dictionary)
	if messages.is_empty():
		SocialMessagesPanelRowsScript.add_empty_row(private_rows, "icon.chat", _t("messages.private.empty"))
	await _online_client().call("mark_private_read", peer_id)
	await _refresh_private_conversations()
	status_label.text = _t("messages.status.private_ready")

func _refresh_private_conversations() -> void:
	_clear_rows(conversation_rows)
	var response: Dictionary = await _online_client().call("fetch_private_conversations", 30)
	if not bool(response.get("ok", false)):
		_set_private_unread_count(0)
		SocialMessagesPanelRowsScript.add_empty_row(conversation_rows, "icon.chat", _t("messages.private.conversations_empty"))
		return
	var conversations: Array = (response.get("data", {}) as Dictionary).get("conversations", []) as Array
	var unread := 0
	for conversation in conversations:
		if typeof(conversation) != TYPE_DICTIONARY:
			continue
		var row := conversation as Dictionary
		var peer_id := str(row.get("peer_id", ""))
		unread += int(row.get("unread_count", 0))
		SocialMessagesPanelRowsScript.add_conversation_row(
			conversation_rows,
			row,
			_app(),
			Callable(self, "_select_private_peer").bind(peer_id)
		)
	if conversations.is_empty():
		SocialMessagesPanelRowsScript.add_empty_row(conversation_rows, "icon.chat", _t("messages.private.conversations_empty"))
	_set_private_unread_count(unread)

func _send_private() -> void:
	var peer_id := peer_input.text.strip_edges()
	var body := private_input.text.strip_edges()
	if peer_id.is_empty() or body.is_empty():
		status_label.text = _t("messages.status.peer_required")
		return
	if not _online_ready():
		status_label.text = _t("messages.status.offline")
		return
	var response: Dictionary = await _online_client().call("send_private_message", peer_id, body)
	if bool(response.get("ok", false)):
		private_input.clear()
		status_label.text = _t("messages.status.private_sent")
		await _refresh_private()
		return
	var error := str(response.get("error", ""))
	status_label.text = _t("messages.status.private_rate_limited" if error == "private_rate_limited" else "messages.status.private_failed")

func _report_private() -> void:
	if _latest_reportable_private_message.is_empty():
		status_label.text = _t("chat.report.empty")
		return
	var response: Dictionary = await _online_client().call(
		"report_private_message",
		_latest_reportable_private_message,
		"player_report"
	)
	status_label.text = _t("messages.status.report_sent" if bool(response.get("ok", false)) else "messages.status.report_failed")

func _add_private_message(message: Dictionary) -> void:
	SocialMessagesPanelRowsScript.add_private_row(private_rows, message, _app())
	var local_id := _player_id()
	var sender := str(message.get("sender_id", ""))
	if sender != local_id:
		_latest_reportable_private_message = message.duplicate(true)
		private_report_button.disabled = false

func _mark_mail_read(mail_id: String) -> void:
	if mail_id.is_empty():
		return
	var response: Dictionary = await _online_client().call("mark_mail_read", mail_id)
	if bool(response.get("ok", false)):
		await _refresh_mailbox()

func _select_private_peer(peer_id: String) -> void:
	if peer_id.is_empty():
		return
	peer_input.text = peer_id
	await _refresh_private()

func _prefill_peer_from_presence() -> void:
	if peer_input == null or not peer_input.text.strip_edges().is_empty() or presence_service == null:
		return
	var local_id := _player_id()
	for member in presence_service.get_members():
		if typeof(member) == TYPE_DICTIONARY:
			var player_id := str((member as Dictionary).get("player_id", ""))
			if not player_id.is_empty() and player_id != local_id:
				peer_input.text = player_id
				return

func _clear_rows(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()

func _set_unread_count(unread_count: int) -> void: _set_mail_unread_count(unread_count)

func _set_mail_unread_count(unread_count: int) -> void: _unread_controller.set_mail_unread(unread_count)

func _set_private_unread_count(unread_count: int) -> void: _unread_controller.set_private_unread(unread_count)

func _on_unread_count_changed(unread_count: int) -> void:
	_last_unread_count = unread_count
	unread_count_changed.emit(_last_unread_count)

func _online_ready() -> bool:
	var client := _online_client()
	return client != null and bool(client.get("is_connected"))

func _online_client() -> Node:
	return get_node("/root/OnlineClient") if has_node("/root/OnlineClient") else null

func _player_id() -> String:
	if has_node("/root/SaveSystem"):
		return str(get_node("/root/SaveSystem").call("get_player_id"))
	return "offline-player"

func _t(key: String) -> String:
	return str(_app().call("t_key", key))

func _fmt(key: String, values: Dictionary) -> String:
	return str(_app().call("format_key", key, values))

func _app() -> Node:
	return get_node("/root/App")

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	for button in [mail_tab_button, private_tab_button, refresh_button, close_button, private_send_button, private_report_button]:
		WorldHUDAssetsScript.configure_button_frame(button)
	for icon_button in [refresh_button, close_button]:
		icon_button.custom_minimum_size = Vector2(40, 40)
		icon_button.expand_icon = true
	refresh_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.mail")
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	WorldHUDAssetsScript.configure_line_edit_frame(peer_input)
	WorldHUDAssetsScript.configure_line_edit_frame(private_input)

func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_text()
