extends Control

const RuntimeGatePanelScript := preload("res://scripts/UI/Panels/RuntimeGatePanel.gd")

@onready var login_panel: PanelContainer = %LoginPanel

var _gate_panel: PanelContainer

func _ready() -> void:
	login_panel.login_requested.connect(_handle_login)
	App.locale_changed.connect(func(_locale: String) -> void: _refresh_runtime_gate())
	_refresh_runtime_gate()

func _handle_login(display_name: String, character: Dictionary = {}) -> void:
	var gate: Dictionary = App.call("get_runtime_gate")
	if bool(gate.get("blocked", false)):
		return
	SaveSystem.set_profile_value("display_name", display_name)
	for key in ["gender_id", "class_id", "avatar_id", "character_variant_id"]:
		if character.has(key):
			SaveSystem.set_profile_value(key, character[key])
	SaveSystem.save_profile()
	await OnlineClient.guest_login(display_name)
	if OnlineClient.is_connected:
		await OnlineClient.fetch_profile()
	var post_login_route: String = str(App.app_config.get("post_login_route", "world"))
	SceneRouter.route_to(post_login_route)

func _refresh_runtime_gate() -> void:
	var gate: Dictionary = App.call("get_runtime_gate")
	var blocked := bool(gate.get("blocked", false))
	login_panel.visible = not blocked
	if not blocked:
		if _gate_panel != null:
			_gate_panel.visible = false
		return
	if _gate_panel == null:
		_gate_panel = RuntimeGatePanelScript.new()
		_gate_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_gate_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_gate_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		_gate_panel.offset_left = -220
		_gate_panel.offset_top = -100
		_gate_panel.offset_right = 220
		_gate_panel.offset_bottom = 100
		_gate_panel.refresh_requested.connect(_handle_gate_refresh)
		add_child(_gate_panel)
	_gate_panel.visible = true
	_gate_panel.set_gate(gate)

func _handle_gate_refresh() -> void:
	await App.refresh_runtime_config()
	_refresh_runtime_gate()
