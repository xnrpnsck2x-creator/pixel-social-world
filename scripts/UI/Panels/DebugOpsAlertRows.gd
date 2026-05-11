extends RefCounted

const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const MAX_ALERT_ROWS := 4

static func render(parent: VBoxContainer, alerts: Dictionary, compact: bool = false) -> void:
	var items: Array = alerts.get("items", []) as Array
	var highest := str(alerts.get("highest_severity", "ok"))
	var count := int(alerts.get("count", items.size()))
	_add_label(parent, App.format_key("ops.console.alerts.summary", {
		"count": count,
		"severity": highest
	}), false, compact)
	if items.is_empty():
		_add_label(parent, App.t_key("ops.console.alerts.empty"), true, compact)
		return
	var shown := 0
	for raw in items:
		if shown >= MAX_ALERT_ROWS:
			break
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw as Dictionary
		_add_label(parent, App.format_key("ops.console.alerts.row", {
			"area": str(item.get("area", "-")),
			"code": str(item.get("code", "-")),
			"critical": int(item.get("critical", 0)),
			"severity": str(item.get("severity", "-")),
			"value": int(item.get("value", 0)),
			"warning": int(item.get("warning", 0))
		}), true, compact)
		shown += 1

static func _add_label(parent: VBoxContainer, text: String, wrap: bool, compact: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = PanelTextThemeScript.MUTED if wrap else PanelTextThemeScript.PRIMARY
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelListFrameScript.new().add_hbox(parent, compact).add_child(label)
