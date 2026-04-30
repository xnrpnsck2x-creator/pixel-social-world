extends SceneTree

const EmoteCatalogScript := preload("res://scripts/Systems/Emotes/EmoteCatalog.gd")
const BubbleScript := preload("res://scripts/UI/Emotes/OverheadEmoteBubble.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var emote_ids: PackedStringArray = EmoteCatalogScript.get_starter_ids()
	if emote_ids.size() != 30:
		failures.append("Expected 30 emotes, got %d" % emote_ids.size())

	for emote_id in emote_ids:
		var texture: Texture2D = EmoteCatalogScript.load_texture(emote_id)
		if texture == null:
			failures.append("Failed to load starter emote: %s" % emote_id)

	if EmoteCatalogScript.get_asset_path("emote.laugh") != "res://assets/ui/sliced/overhead_emotes_v1/overhead_emotes_v1_016.png":
		failures.append("emote.laugh mapping changed.")
	if EmoteCatalogScript.get_asset_path("emote.exclamation") != "res://assets/ui/sliced/overhead_emotes_v1/overhead_emotes_v1_001.png":
		failures.append("emote.exclamation mapping changed.")

	var bubble: Node2D = BubbleScript.new()
	root.add_child(bubble)
	await process_frame
	bubble.call("play", "emote.heart")
	await create_timer(0.05).timeout

	if not bubble.visible:
		failures.append("Overhead emote bubble did not become visible.")

	bubble.free()
	await _check_hud_palette(failures)

	if failures.is_empty():
		print("emote smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_hud_palette(failures: Array[String]) -> void:
	var hud_scene: PackedScene = load("res://scenes/ui/WorldHUD.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame

	var grid: GridContainer = hud.get_node("Root/EmotePalette/EmotePaletteMargin/EmoteGrid")
	if grid.get_child_count() != 30:
		failures.append("HUD emote palette expected 30 buttons.")

	var received := PackedStringArray()
	hud.emote_requested.connect(func(emote_id: String) -> void:
		received.append(emote_id)
	)

	var laugh_button: Button = grid.get_child(15) as Button
	laugh_button.emit_signal("pressed")
	await process_frame

	if received.is_empty() or received[0] != "emote.laugh":
		failures.append("HUD emote palette did not emit emote.laugh.")

	hud.free()
