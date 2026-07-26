class_name CreatorPackageRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CreatorWorkflowScript := preload("res://scripts/UI/Panels/CreatorWorkflow.gd")
const STATUS_KEY := "creator_package_status"

var compact_layout := false
var workflow := CreatorWorkflowScript.new()
var detail_label: Label
var submit_button: Button

func render(items_rows: VBoxContainer, compact: bool) -> void:
	compact_layout = compact
	var row := PanelListFrameScript.new().add_hbox(items_rows, compact_layout)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24) if compact_layout else Vector2(32, 32)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.shield")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title_label := Label.new()
	title_label.text = App.t_key("creator.package.title")
	title_label.add_theme_font_size_override("font_size", 10 if compact_layout else 14)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	labels.add_child(title_label)
	detail_label = Label.new()
	detail_label.text = _status_text(_load_status())
	detail_label.add_theme_font_size_override("font_size", 8 if compact_layout else 11)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.clip_text = true
	PanelTextThemeScript.apply_pair([title_label], [detail_label])
	labels.add_child(detail_label)

	submit_button = Button.new()
	submit_button.name = "CreatorPackageSubmitButton"
	submit_button.text = App.t_key("creator.package.submit_button")
	submit_button.custom_minimum_size = Vector2(58, 30) if compact_layout else Vector2(76, 32)
	submit_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	submit_button.add_theme_font_size_override("font_size", 10 if compact_layout else 12)
	submit_button.disabled = not workflow.has_resolved_state()
	WorldHUDAssetsScript.configure_button_frame(submit_button)
	submit_button.pressed.connect(_submit_package.bind(detail_label, submit_button))
	row.add_child(submit_button)

func refresh_state() -> void:
	if not is_instance_valid(detail_label) or not is_instance_valid(submit_button):
		return
	detail_label.text = _status_text(_load_status())
	submit_button.disabled = not workflow.has_resolved_state()

func _submit_package(detail_label: Label, submit_button: Button) -> void:
	var payload := workflow.build_package()
	if payload.is_empty():
		detail_label.text = App.t_key("creator.package.status.manifest_required")
		submit_button.disabled = true
		return
	submit_button.disabled = true
	detail_label.text = App.t_key("creator.package.status.submitting")
	var client := _online_client()
	var response: Dictionary = await client.call("submit_creator_package", payload)
	if not is_instance_valid(detail_label) or not is_instance_valid(submit_button):
		return
	if not bool(response.get("ok", false)):
		detail_label.text = _failed_status(response)
		submit_button.disabled = false
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	_save_status(data)
	var status_response: Dictionary = await _wait_for_package_status(
		client,
		str(payload.get("game_id", ""))
	)
	if not is_instance_valid(detail_label) or not is_instance_valid(submit_button):
		return
	if bool(status_response.get("ok", false)):
		data = status_response.get("data", {}) as Dictionary
		_save_status(data)
	detail_label.text = _status_text(data)
	submit_button.disabled = false

func _status_text(status: Dictionary) -> String:
	if status.is_empty():
		if workflow.has_resolved_state():
			return App.t_key("creator.package.status.ready")
		return App.t_key("creator.package.status.manifest_required")
	return App.format_key("creator.package.status.format", {
		"game": str(status.get("game_id", workflow.current_game_id())),
		"status": str(status.get("status", "needs_review")),
		"mode": str(status.get("mode_id", ""))
	})

func _failed_status(response: Dictionary) -> String:
	if bool(response.get("offline", false)) or int(response.get("status", 0)) == 0:
		return App.t_key("creator.package.status.offline")
	var data: Dictionary = response.get("data", {}) as Dictionary
	var record: Dictionary = data.get("record", {}) as Dictionary
	if not record.is_empty():
		_save_status(record)
	return App.format_key("creator.package.status.failed", {
		"error": str(response.get("error", "package_scan_failed"))
	})

func _wait_for_package_status(client: Node, game_id: String) -> Dictionary:
	var response := {}
	var tree := Engine.get_main_loop() as SceneTree
	for _attempt in range(50):
		response = await client.call("fetch_creator_submission_status", game_id)
		if bool(response.get("ok", false)):
			var data: Dictionary = response.get("data", {}) as Dictionary
			var status := str(data.get("status", ""))
			if status != "submitted" and status != "scanning":
				return response
		await tree.create_timer(0.1).timeout
	return response

func _load_status() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(STATUS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _save_status(status: Dictionary) -> void:
	SaveSystem.set_profile_value(STATUS_KEY, status)
	SaveSystem.save_profile()

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
