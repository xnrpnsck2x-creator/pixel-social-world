class_name CreatorContractRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var compact_layout := false

func render(items_rows: VBoxContainer, compact: bool) -> void:
	compact_layout = compact
	var config := ConfigLoader.load_config("creator_game_modes")
	for mode in config.get("modes", []):
		if typeof(mode) == TYPE_DICTIONARY:
			_add_mode_row(items_rows, mode as Dictionary)
	_add_contract_row(
		items_rows,
		"icon.check",
		App.t_key("creator.contract.manifest.title"),
		App.t_key("creator.contract.manifest.detail")
	)
	_add_contract_row(
		items_rows,
		"icon.shield",
		App.t_key("creator.contract.security.title"),
		App.t_key("creator.contract.security.detail")
	)

func _add_mode_row(items_rows: VBoxContainer, mode: Dictionary) -> void:
	var detail_key := "creator.mode.row_detail_compact_format" if compact_layout else "creator.mode.row_detail_format"
	var detail := App.format_key(detail_key, {
		"camera": App.t_key(str(mode.get("camera_key", ""))),
		"input": App.t_key(str(mode.get("input_key", ""))),
		"network": App.t_key(str(mode.get("network_key", ""))),
		"min": int(mode.get("min_players", 1)),
		"max": int(mode.get("max_players", 1))
	})
	_add_contract_row(
		items_rows,
		str(mode.get("icon_id", "icon.games")),
		App.t_key(str(mode.get("name_key", ""))),
		detail if compact_layout else "%s\n%s" % [App.t_key(str(mode.get("summary_key", ""))), detail]
	)

func _add_contract_row(items_rows: VBoxContainer, icon_id: String, title: String, detail: String) -> void:
	var row := PanelListFrameScript.new().add_hbox(items_rows, compact_layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24) if compact_layout else Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 10 if compact_layout else 14)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact_layout else TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = compact_layout
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 8 if compact_layout else 11)
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.autowrap_mode = TextServer.AUTOWRAP_OFF if compact_layout else TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text = compact_layout
	PanelTextThemeScript.apply_pair([title_label], [detail_label])
	labels.add_child(detail_label)
