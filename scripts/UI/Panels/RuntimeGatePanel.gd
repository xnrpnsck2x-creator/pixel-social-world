class_name RuntimeGatePanel
extends PanelContainer

signal refresh_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var _gate: Dictionary = {}
var _title_label: Label
var _detail_label: Label
var _refresh_button: Button

func _ready() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	_build_layout()
	App.locale_changed.connect(_on_locale_changed)
	_refresh_text()

func set_gate(gate: Dictionary) -> void:
	_gate = gate.duplicate(true)
	if is_inside_tree():
		_refresh_text()

func _build_layout() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	WorldHUDAssetsScript.add_margin_child(self, box, Vector4(24, 22, 24, 22))

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_label)

	_refresh_button = Button.new()
	_refresh_button.custom_minimum_size = Vector2(160, 34)
	_refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	WorldHUDAssetsScript.configure_button_frame(_refresh_button)
	_refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	box.add_child(_refresh_button)

func _refresh_text() -> void:
	if _title_label == null:
		return
	var detail_values: Dictionary = _gate.get("detail_values", {}) as Dictionary
	_title_label.text = App.t_key(str(_gate.get("title_key", "login.maintenance.title")))
	_detail_label.text = App.format_key(
		str(_gate.get("detail_key", "login.maintenance.detail")),
		detail_values
	)
	_refresh_button.text = App.t_key("ui.action.refresh")

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
