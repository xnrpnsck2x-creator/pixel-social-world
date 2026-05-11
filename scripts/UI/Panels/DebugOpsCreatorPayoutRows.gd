extends RefCounted

const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const MAX_PAYOUT_ROWS := 4

static func render(parent: VBoxContainer, snapshot: Dictionary, compact: bool = false) -> void:
	_add_label(parent, App.format_key("ops.console.creator_payouts.summary", {
		"coins": int(snapshot.get("total_revenue_coins", 0)),
		"creators": int(snapshot.get("total_creators", 0)),
		"events": int(snapshot.get("total_revenue_events", 0))
	}), compact)
	var items: Array = snapshot.get("items", []) as Array
	if items.is_empty():
		_add_label(parent, App.t_key("ops.console.creator_payouts.empty"), compact)
		return
	var shown := 0
	for raw_item in items:
		if shown >= MAX_PAYOUT_ROWS:
			break
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item as Dictionary
		_add_label(parent, App.format_key("ops.console.creator_payouts.row", {
			"coins": int(item.get("revenue_coins", 0)),
			"creator": str(item.get("creator_id", "-")),
			"events": int(item.get("revenue_events", 0)),
			"game": str(item.get("game_id", "unknown"))
		}), compact)
		shown += 1

static func _add_label(parent: VBoxContainer, text: String, compact: bool) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = PanelTextThemeScript.MUTED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelListFrameScript.new().add_hbox(parent, compact).add_child(label)
