class_name ReviewerConsoleAudit
extends RefCounted

static func summary(snapshot: Dictionary) -> String:
	var items: Array = snapshot.get("items", []) as Array
	if items.is_empty():
		return App.format_key("reviewer.console.audit_summary_format", {
			"count": 0,
			"action": "-",
			"status": "-"
		})
	var last: Dictionary = items[items.size() - 1] as Dictionary
	return App.format_key("reviewer.console.audit_summary_format", {
		"count": items.size(),
		"action": str(last.get("action", "-")),
		"status": str(last.get("status", "-"))
	})
