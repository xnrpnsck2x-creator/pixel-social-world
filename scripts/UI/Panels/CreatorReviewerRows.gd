class_name CreatorReviewerRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const STATUS_KEY := "creator_package_status"

var compact_layout := false

func render(items_rows: VBoxContainer, compact: bool) -> void:
	compact_layout = compact
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_rows.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30) if compact_layout else Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.check")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var title_label := Label.new()
	title_label.text = App.t_key("creator.reviewer.title")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = _review_text(_load_status())
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail_label)

func _review_text(status: Dictionary) -> String:
	if status.is_empty():
		return App.t_key("creator.reviewer.empty")
	var package: Dictionary = status.get("package", {}) as Dictionary
	if package.is_empty():
		return App.t_key("creator.reviewer.empty")
	var scan: Dictionary = package.get("scan_report", {}) as Dictionary
	var ai: Dictionary = package.get("ai_review", {}) as Dictionary
	var job: Dictionary = package.get("review_job", {}) as Dictionary
	var install: Dictionary = package.get("install", {}) as Dictionary
	return App.format_key("creator.reviewer.detail_format", {
		"scan": str(scan.get("status", status.get("status", "unknown"))),
		"issues": str((scan.get("issues", []) as Array).size()),
		"ai": str(ai.get("status", "pending")),
		"risk": str(ai.get("risk_level", "unknown")),
		"job": str(job.get("status", "pending")),
		"install": str(install.get("status", "not_installed"))
	})

func _load_status() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(STATUS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
