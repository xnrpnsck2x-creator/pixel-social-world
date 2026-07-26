class_name CreatorStatusRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CreatorWorkflowScript := preload("res://scripts/UI/Panels/CreatorWorkflow.gd")
const HISTORY_KEY := "creator_submission_history"
const STATUS_KEY := "creator_package_status"

var compact_layout := false
var workflow := CreatorWorkflowScript.new()

func render(items_rows: VBoxContainer, compact: bool) -> void:
	compact_layout = compact
	var row := PanelListFrameScript.new().add_hbox(items_rows, compact_layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30) if compact_layout else Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.quest")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var title_label := Label.new()
	title_label.text = App.t_key("creator.status.title")
	title_label.add_theme_font_size_override("font_size", 10 if compact_layout else 14)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact_layout else TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = compact_layout
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = _history_text(_load_history(), _load_status())
	detail_label.add_theme_font_size_override("font_size", 8 if compact_layout else 11)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact_layout else TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text = compact_layout
	PanelTextThemeScript.apply_pair([title_label], [detail_label])
	labels.add_child(detail_label)

	var refresh_button := Button.new()
	refresh_button.text = App.t_key("creator.status.refresh_button")
	refresh_button.custom_minimum_size = Vector2(62, 30) if compact_layout else Vector2(76, 32)
	refresh_button.add_theme_font_size_override("font_size", 10 if compact_layout else 12)
	refresh_button.disabled = _game_id().is_empty()
	WorldHUDAssetsScript.configure_button_frame(refresh_button)
	refresh_button.pressed.connect(_refresh_history.bind(detail_label, refresh_button))
	row.add_child(refresh_button)

func _refresh_history(detail_label: Label, refresh_button: Button) -> void:
	refresh_button.disabled = true
	detail_label.text = App.t_key("creator.status.loading")
	var game_id := _game_id()
	if game_id.is_empty():
		detail_label.text = App.t_key("creator.status.empty")
		return
	var response: Dictionary = await _online_client().call("fetch_creator_submission_history", game_id)
	if bool(response.get("ok", false)):
		var data: Dictionary = response.get("data", {}) as Dictionary
		_save_history(data)
		detail_label.text = _history_text(data, _load_status())
	else:
		detail_label.text = App.t_key("creator.status.offline")
	refresh_button.disabled = false

func _history_text(history: Dictionary, latest_status: Dictionary) -> String:
	var items: Array = history.get("items", []) as Array
	if items.is_empty() and latest_status.is_empty():
		return App.t_key("creator.status.empty")
	var latest := _latest_item(items, latest_status)
	var record: Dictionary = latest.get("record", latest_status) as Dictionary
	var package: Dictionary = record.get("package", latest_status.get("package", {})) as Dictionary
	var scan: Dictionary = package.get("scan_report", {}) as Dictionary
	var ai: Dictionary = package.get("ai_review", {}) as Dictionary
	var install: Dictionary = package.get("install", {}) as Dictionary
	return App.format_key("creator.status.detail_format", {
		"versions": str(max(1, items.size())),
		"version": str(latest.get("version", record.get("version", "0.1.0"))),
		"status": str(latest.get("status", record.get("status", "local"))),
		"scan": str(scan.get("status", record.get("status", "pending"))),
		"ai": str(ai.get("status", "pending")),
		"install": str(install.get("status", "not_installed"))
	})

func _latest_item(items: Array, latest_status: Dictionary) -> Dictionary:
	if items.is_empty():
		return {"record": latest_status, "version": latest_status.get("version", "0.1.0"), "status": latest_status.get("status", "local")}
	var best: Dictionary = items[0] as Dictionary
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("updated_unix", 0)) >= int(best.get("updated_unix", 0)):
			best = item as Dictionary
	return best

func _load_history() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(HISTORY_KEY, {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var history := value as Dictionary
	if not str(history.get("game_id", "")).is_empty() and str(history.get("game_id", "")) != _game_id():
		return {}
	return history

func _load_status() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(STATUS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _save_history(history: Dictionary) -> void:
	SaveSystem.set_profile_value(HISTORY_KEY, history)
	SaveSystem.save_profile()

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")

func _game_id() -> String:
	var status := _load_status()
	return str(status.get("game_id", workflow.current_game_id()))
