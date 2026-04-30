extends CanvasLayer

const OVERLAY_COLOR := Color(0.07, 0.08, 0.12, 0.96)
const PANEL_SIZE := Vector2(520.0, 132.0)
const WEB_OS_NAME := "Web"

var overlay: Control
var message_label: Label

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	get_viewport().size_changed.connect(_refresh)
	if App.has_signal("locale_changed"):
		App.locale_changed.connect(_on_locale_changed)
	if App.has_signal("initialized") and not App.is_initialized:
		App.initialized.connect(_on_app_initialized, CONNECT_ONE_SHOT)
	call_deferred("_refresh")

func _input(_event: InputEvent) -> void:
	if overlay.visible:
		get_viewport().set_input_as_handled()

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.name = "OrientationGuardOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var background := ColorRect.new()
	background.color = OVERLAY_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 22)
	margin.add_child(message_label)
	_refresh_text()

func _refresh() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	overlay.visible = OS.get_name() == WEB_OS_NAME and viewport_size.y > viewport_size.x

func _refresh_text() -> void:
	message_label.text = App.t_key("ui.orientation.landscape_required")

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _on_app_initialized() -> void:
	_refresh_text()
