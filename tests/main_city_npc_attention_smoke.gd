extends SceneTree

const MainCityNPCScript := preload("res://scripts/main_city/MainCityNPC.gd")

class FakeHUD:
	extends Node
	signal npc_primary_action(action_id: String)
	var shown_record: Dictionary = {}

	func show_npc_dialog(record: Dictionary) -> void:
		shown_record = record.duplicate(true)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var screen := Node2D.new()
	screen.name = "MainCityScreen"
	var player_root := Node2D.new()
	player_root.name = "PlayerRoot"
	var player := Node2D.new()
	player.name = "LocalPlayer"
	player.position = Vector2(180, 120)
	player_root.add_child(player)
	screen.add_child(player_root)
	root.add_child(screen)

	var npc_root := Node2D.new()
	npc_root.name = "NPCRoot"
	screen.add_child(npc_root)
	var npc := MainCityNPCScript.new()
	npc.setup({
		"id": "attention_npc",
		"name_key": "npc.event_guide.name",
		"role_key": "npc.role.event_guide",
		"facing": "down",
		"position": {"x": 120, "y": 120}
	})
	npc_root.add_child(npc)
	await process_frame

	var name_label := npc.get_node_or_null("NameLabel") as Label
	var controller_script: GDScript = load("res://scripts/main_city/MainCityInteractionController.gd")
	var controller: Node = controller_script.new()
	var fake_hud := FakeHUD.new()
	root.add_child(fake_hud)
	controller.screen_root = screen
	controller.npc_root = npc_root
	controller.hud = fake_hud
	controller.set("_npc_records_by_id", {"attention_npc": {"id": "attention_npc"}})
	root.add_child(controller)

	controller.call("_refresh_nearby_npc_attention")
	await process_frame
	if str(npc.get("facing")) != "right":
		failures.append("Nearby player did not turn NPC toward the player.")
	if name_label != null and name_label.visible:
		failures.append("Nearby attention revealed the NPC name without a click.")

	await create_timer(1.3).timeout
	if str(npc.get("facing")) != "down":
		failures.append("NPC did not restore its authored facing after nearby attention.")

	controller.call("_on_npc_activated", "attention_npc", "")
	await process_frame
	if str(npc.get("facing")) != "right":
		failures.append("Clicked NPC did not face the player.")
	if name_label == null or not name_label.visible:
		failures.append("Clicked NPC did not reveal its name.")
	if fake_hud.shown_record.is_empty():
		failures.append("Clicked NPC did not open the service dialog.")

	screen.queue_free()
	controller.queue_free()
	fake_hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("main city npc attention smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
