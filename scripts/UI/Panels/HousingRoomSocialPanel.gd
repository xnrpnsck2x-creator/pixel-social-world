class_name HousingRoomSocialPanel
extends PanelContainer

signal chat_send_requested(body: String)

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var presence_service: Node
var chat_service: Node
var owner_id := ""
var _compact_layout := false
var margin_container: MarginContainer
var rows_container: VBoxContainer
var input_row: HBoxContainer
var members_label: Label
var chat_preview_label: Label
var chat_input: LineEdit
var send_button: Button

func _ready() -> void:
	WorldHUDAssetsScript.configure_light_panel_frame(self)
	_build_ui()
	_refresh_text()

func bind_services(new_presence_service: Node, new_chat_service: Node, new_owner_id: String) -> void:
	presence_service = new_presence_service
	chat_service = new_chat_service
	owner_id = new_owner_id
	if presence_service != null:
		presence_service.presence_updated.connect(_on_presence_updated)
	if chat_service != null:
		chat_service.message_added.connect(_on_chat_message_added)
	_refresh_all()

func _build_ui() -> void:
	margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	add_child(margin_container)

	rows_container = VBoxContainer.new()
	rows_container.add_theme_constant_override("separation", 6)
	margin_container.add_child(rows_container)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = App.t_key("housing.social_title")
	title.modulate = PanelTextThemeScript.PRIMARY
	rows_container.add_child(title)

	members_label = Label.new()
	members_label.name = "MembersLabel"
	members_label.custom_minimum_size = Vector2(0, 46)
	members_label.modulate = PanelTextThemeScript.PRIMARY
	members_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows_container.add_child(members_label)

	chat_preview_label = Label.new()
	chat_preview_label.name = "ChatPreviewLabel"
	chat_preview_label.custom_minimum_size = Vector2(0, 58)
	chat_preview_label.modulate = PanelTextThemeScript.PRIMARY
	chat_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows_container.add_child(chat_preview_label)

	input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	rows_container.add_child(input_row)

	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = App.t_key("housing.chat_placeholder")
	WorldHUDAssetsScript.configure_line_edit_frame(chat_input)
	chat_input.text_submitted.connect(_on_chat_submitted)
	input_row.add_child(chat_input)

	send_button = Button.new()
	send_button.name = "SendButton"
	send_button.text = App.t_key("world.send_button")
	send_button.custom_minimum_size = Vector2(68, 36)
	send_button.pressed.connect(_send_chat)
	WorldHUDAssetsScript.configure_button_frame(send_button)
	input_row.add_child(send_button)

func set_compact_layout(enabled: bool) -> void:
	if _compact_layout == enabled:
		return
	_compact_layout = enabled
	custom_minimum_size = Vector2(236, 136) if _compact_layout else Vector2(276, 172)
	_apply_compact_spacing()
	if members_label != null:
		members_label.custom_minimum_size = Vector2(0, 36) if _compact_layout else Vector2(0, 46)
	if chat_preview_label != null:
		chat_preview_label.visible = not _compact_layout
		chat_preview_label.custom_minimum_size = Vector2(0, 0) if _compact_layout else Vector2(0, 58)
	if send_button != null:
		send_button.custom_minimum_size = Vector2(50, 30) if _compact_layout else Vector2(68, 36)
	if chat_input != null:
		chat_input.custom_minimum_size = Vector2(82, 30) if _compact_layout else Vector2.ZERO

func _apply_compact_spacing() -> void:
	var margin := Vector4(8, 6, 8, 6) if _compact_layout else Vector4(10, 8, 10, 8)
	margin_container.add_theme_constant_override("margin_left", int(margin.x))
	margin_container.add_theme_constant_override("margin_top", int(margin.y))
	margin_container.add_theme_constant_override("margin_right", int(margin.z))
	margin_container.add_theme_constant_override("margin_bottom", int(margin.w))
	rows_container.add_theme_constant_override("separation", 4 if _compact_layout else 6)
	input_row.add_theme_constant_override("separation", 4 if _compact_layout else 6)

func _refresh_all() -> void:
	_refresh_members()
	_refresh_chat()

func _refresh_text() -> void:
	if chat_input != null:
		chat_input.placeholder_text = App.t_key("housing.chat_placeholder")
	if send_button != null:
		send_button.text = App.t_key("world.send_button")
	_refresh_all()

func _refresh_members() -> void:
	if members_label == null:
		return
	var members: Array = presence_service.get_members() if presence_service != null else []
	if members.is_empty():
		members_label.text = App.t_key("world.members_empty")
		return
	var rows := PackedStringArray()
	for member in members.slice(0, 4):
		rows.append("- %s" % str(member.get("display_name", member.get("player_id", ""))))
	members_label.text = App.format_key("world.members_format", {"count": members.size()}) + "\n" + "\n".join(rows)

func _refresh_chat() -> void:
	if chat_preview_label == null:
		return
	if chat_service == null:
		chat_preview_label.text = App.t_key("world.chat_empty")
		return
	var rows := PackedStringArray()
	for message in chat_service.get_visible_messages(3):
		rows.append(App.format_key("chat.message_format", {
			"channel": chat_service.get_channel_name(str(message.get("channel_id", ""))),
			"name": str(message.get("sender_name", "")),
			"body": str(message.get("body", ""))
		}))
	chat_preview_label.text = "\n".join(rows) if not rows.is_empty() else App.t_key("world.chat_empty")

func _on_chat_submitted(_text: String) -> void:
	_send_chat()

func _send_chat() -> void:
	var body := chat_input.text.strip_edges()
	if body.is_empty():
		return
	chat_input.clear()
	chat_send_requested.emit(body)

func _on_presence_updated(_members: Array[Dictionary], _is_online: bool, _seconds: int) -> void:
	_refresh_members()

func _on_chat_message_added(_message: Dictionary) -> void:
	_refresh_chat()
