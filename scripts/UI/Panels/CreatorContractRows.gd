class_name CreatorContractRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

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
	var detail := App.format_key("creator.mode.row_detail_format", {
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
		"%s\n%s" % [App.t_key(str(mode.get("summary_key", ""))), detail]
	)

func _add_contract_row(items_rows: VBoxContainer, icon_id: String, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_rows.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30) if compact_layout else Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail_label)
