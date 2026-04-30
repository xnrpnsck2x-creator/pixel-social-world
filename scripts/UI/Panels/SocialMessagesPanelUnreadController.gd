class_name SocialMessagesPanelUnreadController
extends RefCounted

signal count_changed(total_count: int)

const POLL_SECONDS := 20.0

var panel: Node
var mail_unread := 0
var private_unread := 0
var _timer: Timer

func bind(new_panel: Node) -> void:
	panel = new_panel
	_timer = Timer.new()
	_timer.wait_time = POLL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(poll)
	panel.add_child(_timer)

func get_total() -> int:
	return mail_unread + private_unread

func set_mail_unread(count: int) -> void:
	mail_unread = max(0, count)
	_emit_total()

func set_private_unread(count: int) -> void:
	private_unread = max(0, count)
	_emit_total()

func poll() -> void:
	if panel == null or not panel.call("_online_ready"):
		set_mail_unread(0)
		set_private_unread(0)
		return
	var client: Node = panel.call("_online_client")
	var mailbox: Dictionary = await client.call("fetch_mailbox", 30)
	if bool(mailbox.get("ok", false)):
		set_mail_unread(_mail_unread_count((mailbox.get("data", {}) as Dictionary).get("messages", []) as Array))
	var conversations: Dictionary = await client.call("fetch_private_conversations", 30)
	if bool(conversations.get("ok", false)):
		set_private_unread(_private_unread_count(
			(conversations.get("data", {}) as Dictionary).get("conversations", []) as Array
		))

func _mail_unread_count(messages: Array) -> int:
	var count := 0
	for message in messages:
		if typeof(message) == TYPE_DICTIONARY and int((message as Dictionary).get("read_at", 0)) <= 0:
			count += 1
	return count

func _private_unread_count(conversations: Array) -> int:
	var count := 0
	for conversation in conversations:
		if typeof(conversation) == TYPE_DICTIONARY:
			count += int((conversation as Dictionary).get("unread_count", 0))
	return count

func _emit_total() -> void:
	count_changed.emit(get_total())
