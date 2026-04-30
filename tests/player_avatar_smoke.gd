extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var player := instance.get_node("PlayerRoot/LocalPlayer")
	var sprite := player.get_node_or_null("AvatarSprite")
	if sprite == null:
		failures.append("AvatarSprite was not created.")
	var name_label := player.get_node("NameLabel") as Label
	player.set("display_name", "Avatar Smoke")
	await process_frame
	if name_label.visible:
		failures.append("Player name should be hidden by default.")
	player.call("reveal_name", 1.0)
	if not name_label.visible or name_label.text != "Avatar Smoke":
		failures.append("Player name did not reveal on demand.")
	player.call("hide_name")
	if name_label.visible:
		failures.append("Player name did not hide after reveal.")

	player.call("sit_down")
	var sit_state: Dictionary = player.call("get_avatar_state")
	if not bool(sit_state.get("is_sitting", false)):
		failures.append("sit_down did not enter sitting state.")
	if not str(sit_state.get("animation", "")).begins_with("sit_"):
		failures.append("sit_down did not play a sit animation.")

	player.call("start_attack")
	var attack_state: Dictionary = player.call("get_avatar_state")
	if not bool(attack_state.get("is_attacking", false)):
		failures.append("start_attack did not enter attack state.")
	if not str(attack_state.get("animation", "")).begins_with("attack_"):
		failures.append("start_attack did not play an attack animation.")

	instance.queue_free()

	if failures.is_empty():
		print("player avatar smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
