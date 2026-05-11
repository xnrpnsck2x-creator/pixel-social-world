class_name WorldHUDStatusPresenter
extends RefCounted

signal layout_refresh_requested

const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var player_name := ""
var world_title := ""
var presence_service: Node
var layout_controller
var title_label: Label
var player_label: Label
var coin_label: Label
var presence_dot: ColorRect
var presence_label: Label
var status_label: Label
var _status_nonce := 0

func bind_ui(
	new_title_label: Label,
	new_player_label: Label,
	new_coin_label: Label,
	new_presence_dot: ColorRect,
	new_presence_label: Label,
	new_status_label: Label
) -> void:
	title_label = new_title_label
	player_label = new_player_label
	coin_label = new_coin_label
	presence_dot = new_presence_dot
	presence_label = new_presence_label
	status_label = new_status_label
	_apply_label_theme()

func set_layout_controller(new_layout_controller) -> void:
	layout_controller = new_layout_controller

func set_presence_service(new_presence_service: Node) -> void:
	presence_service = new_presence_service

func set_player_name(display_name: String) -> void:
	player_name = display_name
	refresh_player_label()
	refresh_coin()

func set_world_title(title: String) -> void:
	world_title = title
	refresh_title()

func refresh_text() -> void:
	refresh_title()
	refresh_player_label()
	refresh_coin()
	if status_label != null:
		status_label.text = App.t_key("world.status_ready")
		status_label.visible = false
		layout_refresh_requested.emit()
	refresh_presence_pill()

func show_status_message(message: String, seconds: float = 2.8) -> void:
	if status_label == null or message.is_empty():
		return
	_status_nonce += 1
	var nonce := _status_nonce
	status_label.text = message
	status_label.tooltip_text = message
	status_label.visible = true
	layout_refresh_requested.emit()
	var tree := status_label.get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.2, seconds)).timeout.connect(func() -> void:
		if nonce == _status_nonce and status_label != null:
			status_label.visible = false
			status_label.text = App.t_key("world.status_ready")
			layout_refresh_requested.emit()
	)

func refresh_title() -> void:
	if title_label == null:
		return
	title_label.text = world_title if not world_title.is_empty() else App.t_key("world.title")

func refresh_coin() -> void:
	if coin_label == null:
		return
	coin_label.text = App.format_key("world.coin_format", {
		"coins": SaveSystem.get_coin_balance()
	})

func refresh_player_label() -> void:
	if player_label == null:
		return
	var display_name := player_name
	if layout_controller != null:
		display_name = layout_controller.trim_player_name(player_name)
	var player_format_key := "world.player_format"
	if layout_controller != null and layout_controller.is_compact():
		player_format_key = "world.player_compact_format"
	player_label.text = App.format_key(player_format_key, {"name": display_name})
	player_label.tooltip_text = App.format_key("world.player_format", {"name": player_name})

func refresh_presence_pill() -> void:
	if presence_dot == null or presence_label == null:
		return
	var seconds: int = presence_service.seconds_since_heartbeat() if presence_service != null else -1
	var online: bool = seconds >= 0
	var stale: bool = presence_service != null and bool(presence_service.call("is_stale"))
	if online and stale:
		presence_dot.color = Color(0.95, 0.72, 0.22, 1.0)
	elif online:
		presence_dot.color = Color(0.24, 0.76, 0.38, 1.0)
	else:
		presence_dot.color = Color(0.54, 0.55, 0.55, 1.0)
	var count: int = presence_service.get_members().size() if presence_service != null else 1
	var state_key := "ui.status.stale" if online and stale else ("ui.status.online" if online else "ui.status.offline")
	var presence_format_key := "world.presence_format"
	if layout_controller != null and layout_controller.is_compact():
		presence_format_key = "world.presence_compact_format"
	presence_label.text = App.format_key(presence_format_key, {
		"state": App.t_key(state_key),
		"seconds": max(0, seconds),
		"count": count
	})
	var room_id := str(presence_service.call("get_room_id")) if presence_service != null else "local"
	var tooltip := App.format_key("world.presence_tooltip_format", {
		"room": room_id,
		"seconds": max(0, seconds),
		"state": App.t_key(state_key)
	})
	presence_dot.tooltip_text = tooltip
	presence_label.tooltip_text = tooltip

func _apply_label_theme() -> void:
	for label in [title_label, player_label, coin_label, presence_label, status_label]:
		if label != null:
			label.modulate = PanelTextThemeScript.PRIMARY
			label.add_theme_color_override("font_outline_color", Color(1.0, 0.88, 0.58, 0.86))
			label.add_theme_constant_override("outline_size", 2)
