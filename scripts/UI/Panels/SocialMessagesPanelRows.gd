class_name SocialMessagesPanelRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

static func unread_count(messages: Array) -> int:
	var count := 0
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and int((message as Dictionary).get("read_at", 0)) <= 0:
			count += 1
	return count

static func add_mail_row(parent: VBoxContainer, message: Dictionary, app: Node, action: Callable, compact: bool = false) -> void:
	var title := str(app.call("format_key", "messages.mail.row_title_format", {
		"sender": str(message.get("sender_id", "")),
		"subject": str(message.get("subject", ""))
	}))
	if int(message.get("read_at", 0)) <= 0:
		title = "%s %s" % [str(app.call("t_key", "messages.mail.unread_badge")), title]
	add_row(parent, "icon.mail", title, str(message.get("body", "")), str(app.call("t_key", "messages.mail.read")), action, compact)

static func add_private_row(parent: VBoxContainer, message: Dictionary, app: Node, compact: bool = false) -> void:
	var sender := str(message.get("sender_id", ""))
	var title := str(app.call("format_key", "messages.private.row_title_format", {"sender": sender}))
	add_row(parent, "icon.chat", title, str(message.get("body", "")), "", Callable(), compact)

static func add_conversation_row(parent: VBoxContainer, conversation: Dictionary, app: Node, action: Callable, compact: bool = false) -> void:
	var peer_id := str(conversation.get("peer_id", ""))
	var unread := int(conversation.get("unread_count", 0))
	var title := str(app.call("format_key", "messages.private.conversation_title_format", {
		"peer": peer_id,
		"unread": unread
	}))
	var latest: Dictionary = conversation.get("latest_message", {}) as Dictionary
	add_row(
		parent,
		"icon.chat",
		title,
		str(latest.get("body", "")),
		str(app.call("t_key", "messages.private.open")),
		action,
		compact
	)

static func add_empty_row(parent: VBoxContainer, icon_id: String, title: String, compact: bool = false) -> void:
	add_row(parent, icon_id, title, "", "", Callable(), compact)

static func add_row(
	parent: VBoxContainer,
	icon_id: String,
	title: String,
	detail: String,
	action_label: String = "",
	action: Callable = Callable(),
	compact: bool = false
) -> void:
	var row := PanelListFrameScript.new().add_hbox(parent, compact)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(22, 22) if compact else Vector2(28, 28)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title_label := Label.new()
	title_label.text = title
	title_label.modulate = PanelTextThemeScript.PRIMARY
	title_label.add_theme_font_size_override("font_size", 10 if compact else 13)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	labels.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.modulate = PanelTextThemeScript.MUTED
	detail_label.add_theme_font_size_override("font_size", 8 if compact else 11)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.clip_text = true
	labels.add_child(detail_label)
	if action_label.is_empty() or not action.is_valid():
		return
	var button := Button.new()
	button.text = action_label
	button.custom_minimum_size = Vector2(52, 24) if compact else Vector2(64, 30)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	WorldHUDAssetsScript.configure_button_frame(button)
	button.pressed.connect(action)
	row.add_child(button)
