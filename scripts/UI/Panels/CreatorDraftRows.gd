class_name CreatorDraftRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const CreatorWorkflowScript := preload("res://scripts/UI/Panels/CreatorWorkflow.gd")

var compact_layout := false
var workflow := CreatorWorkflowScript.new()
var analysis_completed := Callable()
var client_override: Node

func render(
	items_rows: VBoxContainer,
	compact: bool,
	input_added: Callable = Callable(),
	on_analysis_completed: Callable = Callable()
) -> void:
	compact_layout = compact
	analysis_completed = on_analysis_completed
	var section := PanelListFrameScript.new().add_vbox(items_rows, compact_layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	section.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24) if compact_layout else Vector2(30, 30)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.games")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var title_label := Label.new()
	title_label.text = App.t_key("creator.workflow.title")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 10 if compact_layout else 14)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.clip_text = true
	header.add_child(title_label)

	var mode_picker := OptionButton.new()
	mode_picker.name = "CreatorModePicker"
	mode_picker.custom_minimum_size = Vector2(92, 28) if compact_layout else Vector2(126, 32)
	mode_picker.add_theme_font_size_override("font_size", 9 if compact_layout else 12)
	WorldHUDAssetsScript.configure_button_frame(mode_picker)
	_populate_modes(mode_picker)
	header.add_child(mode_picker)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 5)
	section.add_child(input_row)
	var idea_input := LineEdit.new()
	idea_input.name = "CreatorIdeaInput"
	idea_input.placeholder_text = App.t_key("creator.workflow.idea_placeholder")
	idea_input.text = str(workflow.load_state().get("idea", ""))
	idea_input.max_length = 96
	idea_input.clear_button_enabled = true
	idea_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idea_input.custom_minimum_size = Vector2(0, 30 if compact_layout else 34)
	idea_input.add_theme_font_size_override("font_size", 10 if compact_layout else 13)
	input_row.add_child(idea_input)
	idea_input.item_rect_changed.connect(func() -> void:
		WorldHUDAssetsScript.mark_debug_control_rect("creator_idea_input", idea_input, true)
	)

	var analyze_button := Button.new()
	analyze_button.name = "CreatorAnalyzeButton"
	analyze_button.text = App.t_key("creator.workflow.analyze_button")
	analyze_button.custom_minimum_size = Vector2(58, 30) if compact_layout else Vector2(76, 34)
	analyze_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	analyze_button.add_theme_font_size_override("font_size", 10 if compact_layout else 12)
	analyze_button.disabled = idea_input.text.strip_edges().is_empty()
	WorldHUDAssetsScript.configure_button_frame(analyze_button)
	input_row.add_child(analyze_button)

	var detail_label := Label.new()
	detail_label.name = "CreatorWorkflowStatus"
	detail_label.text = _state_text(workflow.load_state())
	detail_label.add_theme_font_size_override("font_size", 8 if compact_layout else 11)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.clip_text = true
	PanelTextThemeScript.apply_pair([title_label], [detail_label])
	section.add_child(detail_label)

	idea_input.text_changed.connect(func(value: String) -> void:
		analyze_button.disabled = value.strip_edges().is_empty()
	)
	analyze_button.pressed.connect(
		_analyze.bind(idea_input, mode_picker, detail_label, analyze_button)
	)
	idea_input.text_submitted.connect(func(_value: String) -> void:
		if not analyze_button.disabled:
			_analyze(idea_input, mode_picker, detail_label, analyze_button)
	)
	if input_added.is_valid():
		input_added.call(idea_input)
	WorldHUDAssetsScript.mark_debug_control_rect("creator_idea_input", idea_input, true)
	_refresh_debug_rect_after_layout(idea_input)

func _refresh_debug_rect_after_layout(idea_input: LineEdit) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(idea_input) and idea_input.is_inside_tree():
		WorldHUDAssetsScript.mark_debug_control_rect("creator_idea_input", idea_input, true)

func _populate_modes(picker: OptionButton) -> void:
	var state := workflow.load_state()
	var selected_mode := str(state.get(
		"mode_id",
		ConfigLoader.load_config("creator_game_modes").get("default_mode_id", "casual_activity")
	))
	for value in ConfigLoader.load_config("creator_game_modes").get("modes", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var mode := value as Dictionary
		if not bool(mode.get("public_runtime_enabled", false)):
			continue
		picker.add_item(App.t_key(str(mode.get("name_key", ""))))
		var index := picker.item_count - 1
		picker.set_item_metadata(index, str(mode.get("id", "")))
		if str(mode.get("id", "")) == selected_mode:
			picker.select(index)

func _analyze(
	idea_input: LineEdit,
	mode_picker: OptionButton,
	detail_label: Label,
	analyze_button: Button
) -> void:
	analyze_button.disabled = true
	detail_label.text = App.t_key("creator.workflow.status.analyzing")
	var mode_id := str(mode_picker.get_item_metadata(mode_picker.selected))
	var result: Dictionary = await workflow.analyze(
		_online_client(),
		idea_input.text,
		mode_id
	)
	if not is_instance_valid(detail_label) or not is_instance_valid(analyze_button):
		return
	if bool(result.get("ok", false)):
		detail_label.text = _state_text(result.get("state", {}) as Dictionary)
		if analysis_completed.is_valid():
			analysis_completed.call()
	else:
		detail_label.text = _failed_text(result)
	analyze_button.disabled = idea_input.text.strip_edges().is_empty()
	idea_input.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _state_text(state: Dictionary) -> String:
	if state.is_empty():
		return App.t_key("creator.workflow.status.none")
	var matches: Array = state.get("matches", []) as Array
	var resolved := state.get("resolved_manifest", {}) as Dictionary
	return App.format_key("creator.workflow.status.resolved", {
		"keywords": matches.size(),
		"capabilities": (resolved.get("capabilities", []) as Array).size(),
		"lock": str(resolved.get("lock_digest", "")).substr(0, 8),
		"version": str(state.get("version", "0.1.0"))
	})

func _failed_text(result: Dictionary) -> String:
	if bool(result.get("offline", false)):
		return App.t_key("creator.workflow.status.offline")
	return App.format_key("creator.workflow.status.failed", {
		"error": str(result.get("error", "analyze_failed"))
	})

func _online_client() -> Node:
	if client_override != null:
		return client_override
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("OnlineClient")
