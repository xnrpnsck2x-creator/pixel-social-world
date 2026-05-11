extends SceneTree

const MainCityNPCScript := preload("res://scripts/main_city/MainCityNPC.gd")
const MainCityNPCAmbienceScript := preload("res://scripts/main_city/MainCityNPCAmbience.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var screen := Node2D.new()
	var player_root := Node2D.new()
	player_root.name = "PlayerRoot"
	var player := Node2D.new()
	player.name = "LocalPlayer"
	player.position = Vector2(360, 120)
	player_root.add_child(player)
	screen.add_child(player_root)
	root.add_child(screen)

	var npc_root := Node2D.new()
	screen.add_child(npc_root)
	var npc := MainCityNPCScript.new()
	npc.setup({
		"id": "ambience_npc",
		"name_key": "npc.event_guide.name",
		"emote_id": "emote.heart",
		"npc_visual_id": "merchant_v1",
		"facing": "down",
		"position": {"x": 120, "y": 120}
	})
	npc_root.add_child(npc)
	await process_frame

	var ambience := MainCityNPCAmbienceScript.new()
	root.add_child(ambience)
	ambience.bind(screen, npc_root)
	if ambience.is_processing():
		failures.append("NPC ambience should not process while waiting for the scan timer.")
	ambience.pulse_npc(npc, false)
	await process_frame
	if not ambience.is_processing():
		failures.append("NPC ambience should process while an action glance is active.")
	if not ["present", "ledger"].has(str(npc.get("pose"))):
		failures.append("NPC ambience pulse did not switch to a profession action pose.")
	var sprite := npc.get_node_or_null("Sprite") as Sprite2D
	if sprite == null or sprite.texture == null or not str(sprite.texture.resource_path).contains(str(npc.get("pose"))):
		failures.append("NPC ambience pulse did not load the profession action texture.")
	var name_label := npc.get_node_or_null("NameLabel") as Label
	if name_label != null and name_label.visible:
		failures.append("NPC ambience pulse revealed the name label.")

	await create_timer(0.75).timeout
	if str(npc.get("facing")) != "down" or str(npc.get("pose")) != "idle":
		failures.append("NPC ambience pulse did not restore the home facing and pose.")
	if ambience.is_processing():
		failures.append("NPC ambience should stop processing after active glances restore.")

	player.position = Vector2(130, 120)
	ambience.pulse_npc(npc, false)
	await process_frame
	if str(npc.get("facing")) != "down":
		failures.append("NPC ambience pulse ran while the local player was too close.")

	screen.queue_free()
	ambience.queue_free()
	await process_frame
	if failures.is_empty():
		print("main city npc ambience smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
