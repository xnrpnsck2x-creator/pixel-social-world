class_name CreatorPackageRows
extends RefCounted

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const STATUS_KEY := "creator_package_status"
const PACKAGE_GAME_ID := "creator_package_probe"

var compact_layout := false

func render(items_rows: VBoxContainer, compact: bool) -> void:
	compact_layout = compact
	var row := PanelListFrameScript.new().add_hbox(items_rows, compact_layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30) if compact_layout else Vector2(34, 34)
	icon.texture = WorldHUDAssetsScript.load_ui_texture("icon.shield")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)

	var title_label := Label.new()
	title_label.text = App.t_key("creator.package.title")
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(title_label)

	var detail_label := Label.new()
	detail_label.text = _status_text(_load_status())
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PanelTextThemeScript.apply_pair([title_label], [detail_label])
	labels.add_child(detail_label)

	var submit_button := Button.new()
	submit_button.text = App.t_key("creator.package.submit_button")
	submit_button.custom_minimum_size = Vector2(62, 30) if compact_layout else Vector2(76, 32)
	WorldHUDAssetsScript.configure_button_frame(submit_button)
	submit_button.pressed.connect(_submit_package.bind(detail_label, submit_button))
	row.add_child(submit_button)

func _submit_package(detail_label: Label, submit_button: Button) -> void:
	submit_button.disabled = true
	detail_label.text = App.t_key("creator.package.status.submitting")
	var client := _online_client()
	var response: Dictionary = await client.call("submit_creator_package", _package_payload())
	if not bool(response.get("ok", false)):
		detail_label.text = _failed_status(response)
		submit_button.disabled = false
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	_save_status(data)
	var status_response: Dictionary = await _wait_for_package_status(client)
	if bool(status_response.get("ok", false)):
		data = status_response.get("data", {}) as Dictionary
		_save_status(data)
	detail_label.text = _status_text(data)
	submit_button.disabled = false

func _package_payload() -> Dictionary:
	var manifest := _manifest()
	var meta_text := JSON.stringify(manifest)
	var script := "class_name CreatorPackageProbe\nextends IMinigame\n\nfunc get_game_id() -> String:\n\treturn \"%s\"\n" % PACKAGE_GAME_ID
	var scene := "[gd_scene format=3]\n[node name=\"CreatorPackageProbe\" type=\"Node\"]\nscript = ExtResource(\"1_script\")\n"
	var payload := manifest.duplicate(true)
	payload["files"] = [
		_file("meta.json", meta_text),
		_file("main.tscn", scene),
		_file("game.gd", script),
		_file("README.md", "Creator package probe for intake scanner.")
	]
	return payload

func _manifest() -> Dictionary:
	return {
		"game_id": PACKAGE_GAME_ID,
		"version": "0.1.0",
		"mode_id": "2d_fighting",
		"name": {"en": "Creator Package Probe", "ja": "Creator Package Probe", "zh": "Creator Package Probe"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["fighting", "package"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "side_view",
			"input_profile": "fighting_action",
			"network_profile": "authoritative_realtime"
		},
		"entry_scene": "res://creator/%s/main.tscn" % PACKAGE_GAME_ID,
		"main_script": "res://creator/%s/game.gd" % PACKAGE_GAME_ID,
		"asset_budget_bytes": 5242880
	}

func _file(path: String, content: String) -> Dictionary:
	return {
		"path": path,
		"size_bytes": content.to_utf8_buffer().size(),
		"content_text": content
	}

func _status_text(status: Dictionary) -> String:
	if status.is_empty():
		return App.t_key("creator.package.status.none")
	return App.format_key("creator.package.status.format", {
		"game": str(status.get("game_id", PACKAGE_GAME_ID)),
		"status": str(status.get("status", "needs_review")),
		"mode": str(status.get("mode_id", "2d_fighting"))
	})

func _failed_status(response: Dictionary) -> String:
	if bool(response.get("offline", false)) or int(response.get("status", 0)) == 0:
		return App.t_key("creator.package.status.offline")
	var data: Dictionary = response.get("data", {}) as Dictionary
	var record: Dictionary = data.get("record", {}) as Dictionary
	if not record.is_empty():
		_save_status(record)
	return App.format_key("creator.package.status.failed", {
		"error": str(response.get("error", "package_scan_failed"))
	})

func _wait_for_package_status(client: Node) -> Dictionary:
	var response := {}
	var tree := Engine.get_main_loop() as SceneTree
	for _attempt in range(12):
		response = await client.call("fetch_creator_submission_status", PACKAGE_GAME_ID)
		if bool(response.get("ok", false)):
			var data: Dictionary = response.get("data", {}) as Dictionary
			var status := str(data.get("status", ""))
			if status != "submitted" and status != "scanning":
				return response
		await tree.create_timer(0.08).timeout
	return response

func _load_status() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(STATUS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _save_status(status: Dictionary) -> void:
	SaveSystem.set_profile_value(STATUS_KEY, status)
	SaveSystem.save_profile()

func _online_client() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node("OnlineClient")
