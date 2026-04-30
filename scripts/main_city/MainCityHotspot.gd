class_name MainCityHotspot
extends Area2D

signal activated(action_id: String)

@export var action_id := ""
@export var label_key := ""

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	add_to_group("main_city_hotspot")
	input_pickable = true
	if has_node("/root/App"):
		App.locale_changed.connect(_on_locale_changed)
	_refresh_text()

func activate() -> void:
	if not action_id.is_empty():
		activated.emit(action_id)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		activate()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		activate()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	if prompt_label == null:
		return
	prompt_label.text = App.t_key(label_key) if not label_key.is_empty() else action_id
