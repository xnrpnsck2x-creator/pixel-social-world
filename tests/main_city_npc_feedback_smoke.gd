extends SceneTree

const MainCityNPCScript := preload("res://scripts/main_city/MainCityNPC.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var npc := MainCityNPCScript.new()
	var activated_ids: Array[String] = []
	npc.activated.connect(func(npc_id: String, _action_id: String) -> void:
		activated_ids.append(npc_id)
	)
	npc.setup({
		"id": "npc_feedback_smoke",
		"name_key": "npc.event_guide.name",
		"dialogue_key": "npc.event_guide.dialogue",
		"role_key": "npc.role.event_guide",
		"npc_visual_id": "notice_guide",
		"position": {"x": 120, "y": 120}
	})
	root.add_child(npc)
	await process_frame

	var name_label := npc.get_node_or_null("NameLabel") as Label
	if name_label == null:
		failures.append("NPC did not create a NameLabel.")
	elif name_label.visible:
		failures.append("NPC name should be hidden before interaction.")

	npc.call("activate")
	await process_frame
	if activated_ids != ["npc_feedback_smoke"]:
		failures.append("NPC activate did not emit its id exactly once.")
	if name_label == null or not name_label.visible or name_label.text.is_empty():
		failures.append("NPC name did not reveal after interaction.")
	elif not name_label.text.contains("Notice Guide"):
		failures.append("NPC reveal did not include the localized role tag.")

	await create_timer(2.05).timeout
	if name_label != null and name_label.visible:
		failures.append("NPC name did not auto-hide after the short reveal window.")

	npc.queue_free()
	if failures.is_empty():
		print("main city npc feedback smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
