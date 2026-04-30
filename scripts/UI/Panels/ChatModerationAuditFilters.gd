class_name ChatModerationAuditFilters
extends HBoxContainer

signal export_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var _target_input: LineEdit
var _action_filter: OptionButton
var _export_button: Button

func build() -> void:
	if _target_input != null:
		return
	add_theme_constant_override("separation", 6)
	_target_input = LineEdit.new()
	_target_input.placeholder_text = App.t_key("moderation.console.target_filter_placeholder")
	_target_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_target_input)
	_action_filter = OptionButton.new()
	for key in ["all", "mute", "ban", "restore"]:
		_action_filter.add_item(App.t_key("moderation.console.action_filter.%s" % key))
	add_child(_action_filter)
	_export_button = Button.new()
	_export_button.text = App.t_key("ui.action.export_csv")
	_export_button.custom_minimum_size = Vector2(86, 32)
	_export_button.pressed.connect(func() -> void: export_requested.emit())
	add_child(_export_button)
	apply_image2_style()

func target_player_id() -> String:
	return _target_input.text.strip_edges() if _target_input != null else ""

func action() -> String:
	var actions := ["", "mute", "ban", "restore"]
	if _action_filter == null or _action_filter.selected < 0 or _action_filter.selected >= actions.size():
		return ""
	return actions[_action_filter.selected]

func apply_image2_style() -> void:
	if _target_input != null:
		WorldHUDAssetsScript.configure_line_edit_frame(_target_input)
	if _export_button != null:
		WorldHUDAssetsScript.configure_button_frame(_export_button)
