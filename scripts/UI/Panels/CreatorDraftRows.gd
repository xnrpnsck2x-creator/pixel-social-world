class_name CreatorDraftRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const STATUS_KEY := "creator_submission_status"
const DRAFT_GAME_ID := "creator_duel_draft"

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
	title_label.text = App.t_key("creator.submission.draft.title")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = _status_text(_load_status())
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(detail_label)

	var submit_button := Button.new()
	submit_button.text = App.t_key("creator.submission.submit_button")
	submit_button.custom_minimum_size = Vector2(62, 30) if compact_layout else Vector2(76, 32)
	WorldHUDAssetsScript.configure_button_frame(submit_button)
	submit_button.pressed.connect(_submit_draft.bind(detail_label, submit_button))
	row.add_child(submit_button)

func _submit_draft(detail_label: Label, submit_button: Button) -> void:
	submit_button.disabled = true
	detail_label.text = App.t_key("creator.submission.status.submitting")
	var client := _online_client()
	var response: Dictionary = await client.call("submit_creator_draft", _draft_payload())
	if not bool(response.get("ok", false)):
		detail_label.text = _failed_status(response)
		submit_button.disabled = false
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	_save_status(data)
	var status_response: Dictionary = await client.call("fetch_creator_submission_status", DRAFT_GAME_ID)
	if bool(status_response.get("ok", false)):
		data = status_response.get("data", {}) as Dictionary
		_save_status(data)
	detail_label.text = _status_text(data)
	submit_button.disabled = false

func _draft_payload() -> Dictionary:
	return {
		"game_id": DRAFT_GAME_ID,
		"version": "0.1.0",
		"mode_id": "2d_fighting",
		"name": {"en": "Creator Duel Draft", "ja": "Creator Duel Draft", "zh": "Creator Duel Draft"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["fighting", "fixture"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "side_view",
			"input_profile": "fighting_action",
			"network_profile": "authoritative_realtime"
		},
		"entry_scene": "res://creator/creator_duel_draft/main.tscn",
		"main_script": "res://creator/creator_duel_draft/game.gd",
		"asset_budget_bytes": 5242880
	}

func _status_text(status: Dictionary) -> String:
	if status.is_empty():
		return App.t_key("creator.submission.status.none")
	return App.format_key("creator.submission.status.format", {
		"game": str(status.get("game_id", DRAFT_GAME_ID)),
		"status": str(status.get("status", "pending_review")),
		"mode": str(status.get("mode_id", "2d_fighting"))
	})

func _failed_status(response: Dictionary) -> String:
	if bool(response.get("offline", false)) or int(response.get("status", 0)) == 0:
		return App.t_key("creator.submission.status.offline")
	return App.format_key("creator.submission.status.failed", {
		"error": str(response.get("error", "submit_failed"))
	})

func _load_status() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(STATUS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _save_status(status: Dictionary) -> void:
	SaveSystem.set_profile_value(STATUS_KEY, status)
	SaveSystem.save_profile()

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
