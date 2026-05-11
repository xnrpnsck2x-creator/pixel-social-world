class_name WorldHUDFirstSessionGuide
extends RefCounted

signal reward_granted(coins: int)

const SAVE_KEY := "first_session_guide_completed_ids"
const REWARD_CLAIMED_KEY := "first_session_guide_reward_claimed"
const DEFAULT_REWARD_COINS := 5
const DEFAULT_REWARD_SOURCE := "first_session.guide_complete"
const STEPS: Array[Dictionary] = [
	{
		"id": "npc_met",
		"title_key": "first_session.step.npc.title",
		"body_key": "first_session.step.npc.body"
	},
	{
		"id": "map_opened",
		"title_key": "first_session.step.map.title",
		"body_key": "first_session.step.map.body"
	},
	{
		"id": "trade_opened",
		"title_key": "first_session.step.trade.title",
		"body_key": "first_session.step.trade.body"
	},
	{
		"id": "games_opened",
		"title_key": "first_session.step.games.title",
		"body_key": "first_session.step.games.body"
	},
	{
		"id": "chat_sent",
		"title_key": "first_session.step.chat.title",
		"body_key": "first_session.step.chat.body"
	}
]

var panel: PanelContainer
var margin: MarginContainer
var rows: VBoxContainer
var header: HBoxContainer
var title_label: Label
var body_label: Label
var progress_label: Label
var chat_service: Node
var _completed := {}
var _compact := false
var _mobile_chip := false
var _enabled := false
var _reward_pending := false

func bind_ui(
	new_panel: PanelContainer,
	new_title_label: Label,
	new_body_label: Label,
	new_progress_label: Label
) -> void:
	panel = new_panel
	margin = panel.get_node_or_null("FirstSessionMargin") as MarginContainer
	rows = panel.get_node_or_null("FirstSessionMargin/FirstSessionRows") as VBoxContainer
	header = panel.get_node_or_null("FirstSessionMargin/FirstSessionRows/FirstSessionHeader") as HBoxContainer
	title_label = new_title_label
	body_label = new_body_label
	progress_label = new_progress_label
	_load_completed()
	_prepare_labels()
	_render()

func bind_chat_service(new_chat_service: Node) -> void:
	if chat_service != null and chat_service.has_signal("message_added"):
		var old_callback := Callable(self, "_on_message_added")
		if chat_service.is_connected("message_added", old_callback):
			chat_service.disconnect("message_added", old_callback)
	chat_service = new_chat_service
	if chat_service == null or not chat_service.has_signal("message_added"):
		return
	var callback := Callable(self, "_on_message_added")
	if not chat_service.is_connected("message_added", callback):
		chat_service.connect("message_added", callback)

func record_event(event_id: String) -> void:
	if not _enabled:
		return
	if _completed.has(event_id) or not _step_id_exists(event_id):
		return
	_completed[event_id] = true
	_save_completed()
	_render()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_render()

func refresh_text() -> void:
	_render()

func layout(viewport_size: Vector2) -> void:
	if panel == null:
		return
	var mode_size := WorldHUDAssets.browser_window_size()
	if mode_size == Vector2.ZERO:
		mode_size = viewport_size
	var mobile_chip := mode_size.x >= 640.0 and mode_size.x <= 1100.0 and mode_size.y <= 540.0
	_mobile_chip = mobile_chip
	_compact = mobile_chip or mode_size.y <= 480.0 or mode_size.x <= 520.0
	var left := 10.0 if _compact else 16.0
	var top := 54.0 if _compact else 60.0
	var width_ratio := 0.30 if mobile_chip else 0.48 if _compact else 0.32
	var width: float = clamp(viewport_size.x * width_ratio, 166.0, 238.0 if mobile_chip else 304.0)
	var height := 36.0 if mobile_chip else 54.0 if _compact else 90.0
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = left
	panel.offset_right = left + width
	panel.offset_top = top
	panel.offset_bottom = top + height
	WorldHUDAssets.configure_first_session_guide_frame(panel, mobile_chip)
	if margin != null:
		var side_margin := 8 if _compact else 10
		var vertical_margin := 2 if mobile_chip else 4 if _compact else 8
		margin.add_theme_constant_override("margin_left", side_margin)
		margin.add_theme_constant_override("margin_right", side_margin)
		margin.add_theme_constant_override("margin_top", vertical_margin)
		margin.add_theme_constant_override("margin_bottom", vertical_margin)
	if rows != null:
		rows.add_theme_constant_override("separation", 0 if _compact else 2)
	if header != null:
		header.add_theme_constant_override("separation", 4 if mobile_chip else 6 if _compact else 8)
	if body_label != null:
		body_label.visible = not _compact
		body_label.custom_minimum_size = Vector2.ZERO if _compact else Vector2(0, 36)
	if progress_label != null:
		progress_label.visible = not mobile_chip
		progress_label.custom_minimum_size = Vector2.ZERO if mobile_chip else Vector2(34 if _compact else 42, 0)
	_render()

func _load_completed() -> void:
	_completed.clear()
	var ids_value: Variant = SaveSystem.get_profile_value(SAVE_KEY, [])
	if typeof(ids_value) != TYPE_ARRAY:
		return
	var saved_ids: Array = ids_value as Array
	for id_value in saved_ids:
		var id := str(id_value)
		if _step_id_exists(id):
			_completed[id] = true

func _save_completed() -> void:
	var ids: Array[String] = []
	for step in STEPS:
		var id := str(step.get("id", ""))
		if _completed.has(id):
			ids.append(id)
	SaveSystem.set_profile_value(SAVE_KEY, ids)
	SaveSystem.save_profile()

func _prepare_labels() -> void:
	for label in [title_label, body_label, progress_label]:
		if label == null:
			continue
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if body_label != null:
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _render() -> void:
	if panel == null:
		return
	if not _enabled:
		panel.visible = false
		WorldHUDAssets.mark_debug_control_rect("first_session", panel)
		return
	if _is_complete():
		_try_grant_completion_reward()
		panel.visible = false
		WorldHUDAssets.mark_debug_control_rect("first_session", panel)
		return
	var index := _next_step_index()
	var step := STEPS[index]
	var title := App.t_key(str(step.get("title_key", "")))
	var body := App.t_key(str(step.get("body_key", "")))
	panel.visible = true
	panel.tooltip_text = "%s\n%s" % [title, body]
	if title_label != null:
		title_label.text = title
	if body_label != null:
		body_label.text = body
		body_label.visible = not _compact
	if progress_label != null:
		progress_label.visible = not _mobile_chip
		progress_label.text = App.format_key("first_session.progress_format", {
			"current": index + 1,
			"total": STEPS.size()
		})
	WorldHUDAssets.mark_debug_control_rect("first_session", panel)

func _next_step_index() -> int:
	for index in range(STEPS.size()):
		if not _completed.has(str(STEPS[index].get("id", ""))):
			return index
	return STEPS.size() - 1

func _is_complete() -> bool:
	for step in STEPS:
		if not _completed.has(str(step.get("id", ""))):
			return false
	return true

func _step_id_exists(event_id: String) -> bool:
	for step in STEPS:
		if str(step.get("id", "")) == event_id:
			return true
	return false

func _on_message_added(message: Dictionary) -> void:
	if str(message.get("channel_id", "")) == "system":
		return
	if str(message.get("sender_id", "")) != SaveSystem.get_player_id():
		return
	if str(message.get("body", "")).strip_edges().is_empty():
		return
	record_event("chat_sent")

func _try_grant_completion_reward() -> void:
	if bool(SaveSystem.get_profile_value(REWARD_CLAIMED_KEY, false)) or _reward_pending:
		return
	var client := _online_client()
	if _can_claim_online(client):
		_reward_pending = true
		_claim_online_reward(client)
		return
	_grant_local_completion_reward()

func _grant_local_completion_reward() -> void:
	var reward := _reward_config()
	var coins := int(reward.get("coins", DEFAULT_REWARD_COINS))
	if coins <= 0:
		SaveSystem.set_profile_value(REWARD_CLAIMED_KEY, true)
		SaveSystem.save_profile()
		return
	SaveSystem.set_profile_value(REWARD_CLAIMED_KEY, true)
	SaveSystem.grant_coins(coins, str(reward.get("source", DEFAULT_REWARD_SOURCE)))
	reward_granted.emit(coins)
	if chat_service != null and chat_service.has_method("add_system_message"):
		chat_service.call(
			"add_system_message",
			App.t_key("chat.system.name"),
			App.format_key("first_session.reward_chat_format", {"coins": coins})
		)

func _can_claim_online(client: Node) -> bool:
	return client != null and bool(client.get("online_enabled")) and bool(client.get("is_connected")) and client.has_method("claim_first_session_reward")

func _claim_online_reward(client: Node) -> void:
	var response: Dictionary = await client.call("claim_first_session_reward", _completed_step_ids())
	if not bool(response.get("ok", false)):
		_grant_local_completion_reward()
		_reward_pending = false
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	var delta := int(data.get("delta", 0))
	SaveSystem.set_profile_value(REWARD_CLAIMED_KEY, true)
	SaveSystem.sync_coin_balance(int(data.get("balance", SaveSystem.get_coin_balance())), "server.first_session")
	SaveSystem.save_profile()
	reward_granted.emit(delta)
	if delta > 0 and chat_service != null and chat_service.has_method("add_system_message"):
		chat_service.call(
			"add_system_message",
			App.t_key("chat.system.name"),
			App.format_key("first_session.reward_chat_format", {"coins": delta})
		)
	_reward_pending = false

func _reward_config() -> Dictionary:
	var economy := ConfigLoader.load_config("economy")
	var config: Dictionary = economy.get("first_session", {}) as Dictionary
	return {
		"coins": int(config.get("completion_reward_coins", DEFAULT_REWARD_COINS)),
		"source": str(config.get("reward_source", DEFAULT_REWARD_SOURCE))
	}

func _completed_step_ids() -> Array[String]:
	var ids: Array[String] = []
	for step in STEPS:
		var id := str(step.get("id", ""))
		if _completed.has(id):
			ids.append(id)
	return ids

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("OnlineClient")
