class_name DebugOpsPanel
extends PanelContainer

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var compact_layout := false
var _embedded_admin_mode := false
var _built := false
var _token_input: LineEdit
var _status_label: Label
var _rows: VBoxContainer
var _refresh_button: Button
var _ops_snapshot: Dictionary = {}
var _room_snapshot: Dictionary = {}

func _ready() -> void:
	_build()
	_apply_image2_style()

func set_compact_layout(enabled: bool) -> void:
	compact_layout = enabled
	if _rows != null:
		_rows.add_theme_constant_override("separation", 4 if enabled else 6)

func set_admin_token(token: String) -> void:
	_build()
	_token_input.text = token

func set_embedded_admin_mode(enabled: bool) -> void:
	_embedded_admin_mode = enabled
	_build()
	if _token_input != null:
		_token_input.visible = not enabled

func set_ops_snapshot(snapshot: Dictionary) -> void:
	_build()
	_ops_snapshot = snapshot.duplicate(true)
	_render_rows()

func set_room_snapshot(snapshot: Dictionary) -> void:
	_build()
	_room_snapshot = snapshot.duplicate(true)
	_render_rows()

func refresh_ops() -> void:
	_build()
	var token := _token_input.text.strip_edges()
	if token.is_empty():
		_status_label.text = App.t_key("reviewer.console.token_required")
		return
	_refresh_button.disabled = true
	_status_label.text = App.t_key("ops.console.loading")
	var response: Dictionary = await _online_client().call("fetch_debug_ops_admin", token)
	if not bool(response.get("ok", false)):
		_status_label.text = App.format_key("reviewer.console.failed_format", {"error": str(response.get("error", "request_failed"))})
		_refresh_button.disabled = false
		return
	_ops_snapshot = response.get("data", {}) as Dictionary
	var rooms_response: Dictionary = await _online_client().call("fetch_debug_rooms_admin", token)
	if bool(rooms_response.get("ok", false)):
		_room_snapshot = rooms_response.get("data", {}) as Dictionary
	_render_rows()
	_refresh_button.disabled = false

func _render_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	if _ops_snapshot.is_empty():
		_status_label.text = App.t_key("ops.console.empty")
		if _refresh_button != null:
			_refresh_button.disabled = false
		return
	var rooms: Dictionary = _ops_snapshot.get("rooms", {}) as Dictionary
	var realtime: Dictionary = _ops_snapshot.get("realtime", {}) as Dictionary
	var chat: Dictionary = _ops_snapshot.get("chat", {}) as Dictionary
	var fishing: Dictionary = _ops_snapshot.get("fishing_rewards", {}) as Dictionary
	var economy: Dictionary = _ops_snapshot.get("economy", {}) as Dictionary
	_status_label.text = App.format_key("ops.console.summary_format", {
		"online": _int(rooms, "online_count"),
		"messages": _int(chat, "total_messages"),
		"reports": _int(chat, "total_reports"),
		"rewards": _int(fishing, "granted")
	})
	_add_row("ops.console.row.rooms", [_int(rooms, "online_count"), _dict_size(rooms.get("rooms", {}))])
	_add_row("ops.console.row.realtime", [_int(realtime, "local_delivered"), _int(realtime, "move_rate_limited"), _int(realtime, "emote_rate_limited")])
	_add_row("ops.console.row.realtime_load", [_int(realtime, "connections_opened"), _int(realtime, "local_delivery_target"), _int(realtime, "slow_writes"), _int(realtime, "write_failed")])
	_add_row("ops.console.row.chat", [_int(chat, "total_messages"), _int(chat, "total_reports"), _int(chat, "rejected_rate_limited")])
	_add_row("ops.console.row.moderation", [_int(chat, "active_moderation"), _int(chat, "moderation_actions")])
	_add_row("ops.console.row.fishing", [_int(fishing, "granted"), _int(fishing, "capped"), _int(fishing, "replayed")])
	_add_row("ops.console.row.economy", [_int(economy, "creator_play_rewards"), _int(economy, "creator_revenue_coins"), _int(economy, "reward_cap_hits")])
	_add_room_rows()
	_refresh_button.disabled = false

func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(360, 220)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	_add_header(layout)
	_token_input = LineEdit.new()
	_token_input.placeholder_text = App.t_key("reviewer.console.token_placeholder")
	_token_input.secret = true
	_token_input.visible = not _embedded_admin_mode
	layout.add_child(_token_input)
	_status_label = Label.new()
	_status_label.text = App.t_key("ops.console.empty")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status_label)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	layout.add_child(_rows)

func _add_header(layout: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	_add_icon(header)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(labels)
	var title := Label.new()
	title.text = App.t_key("ops.console.title")
	labels.add_child(title)
	var detail := Label.new()
	detail.text = App.t_key("ops.console.detail")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail)
	_refresh_button = Button.new()
	_refresh_button.text = App.t_key("ui.action.refresh")
	_refresh_button.custom_minimum_size = Vector2(72, 32)
	_refresh_button.pressed.connect(refresh_ops)
	header.add_child(_refresh_button)

func _add_row(key: String, values: Array) -> void:
	var label := Label.new()
	label.text = App.format_key(key, {
		"a": values[0],
		"b": values[1],
		"c": values[2] if values.size() > 2 else 0,
		"d": values[3] if values.size() > 3 else 0
	})
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)

func _add_room_rows() -> void:
	if _room_snapshot.is_empty():
		return
	var title := Label.new()
	title.text = App.t_key("ops.console.rooms_title")
	_rows.add_child(title)
	var room_states: Dictionary = _room_snapshot.get("rooms", {}) as Dictionary
	if room_states.is_empty():
		_add_plain_row(App.t_key("ops.console.rooms_empty"))
		return
	var shown := 0
	for room_id in _sorted_keys(room_states):
		if shown >= 4:
			break
		var state: Dictionary = room_states[room_id] as Dictionary
		_add_plain_row(App.format_key("ops.console.row.room_detail", {
			"age": _age_seconds(int(state.get("last_active_at", 0))),
			"connected": int(state.get("connected", 0)),
			"culled": int(state.get("movement_culled", 0)),
			"delivered": int(state.get("local_delivered", 0)),
			"failed": int(state.get("write_failed", 0)),
			"room": str(room_id),
			"snapshot": int(state.get("snapshot_players", 0)),
			"slow": int(state.get("slow_writes", 0)),
			"target": int(state.get("local_delivery_target", 0)),
			"type": str(state.get("room_type", "custom"))
		}))
		shown += 1

func _add_plain_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)

func _sorted_keys(data: Dictionary) -> Array:
	var keys := data.keys()
	keys.sort()
	return keys

func _age_seconds(last_active_at: int) -> int:
	if last_active_at <= 0:
		return -1
	return max(0, int(Time.get_unix_time_from_system()) - last_active_at)

func _add_icon(parent: Control) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.quest")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(icon)

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	if _token_input != null:
		WorldHUDAssetsScript.configure_line_edit_frame(_token_input)
	if _refresh_button != null:
		WorldHUDAssetsScript.configure_button_frame(_refresh_button)

func _int(data: Dictionary, key: String) -> int:
	return int(data.get(key, 0))

func _dict_size(value: Variant) -> int:
	return (value as Dictionary).size() if typeof(value) == TYPE_DICTIONARY else 0

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
