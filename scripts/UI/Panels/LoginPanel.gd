class_name LoginPanel
extends PanelContainer

signal login_requested(display_name: String)

@onready var title_label: Label = %TitleLabel
@onready var name_input: LineEdit = %NameInput
@onready var play_button: Button = %PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	App.locale_changed.connect(_on_locale_changed)
	_refresh_text()

func _on_play_pressed() -> void:
	var display_name: String = name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = App.t_key("login.default_name")
	login_requested.emit(display_name)

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	title_label.text = App.t_key("login.title")
	name_input.placeholder_text = App.t_key("login.name_placeholder")
	play_button.text = App.t_key("login.play_button")
