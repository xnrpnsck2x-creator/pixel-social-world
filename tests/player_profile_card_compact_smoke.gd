extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var app := root.get_node("App")
	app.call("load_localization", "en")
	var scene: PackedScene = load("res://scenes/ui/PlayerProfileCard.tscn")
	var card := scene.instantiate()
	root.add_child(card)
	await process_frame
	card.call("set_compact_layout", true)
	card.call("show_profile", {
		"player_id": "peer-profile-smoke",
		"display_name": "Peer Profile Smoke",
		"character_variant_id": "female_ranged_v0"
	})
	await process_frame
	var role_label := card.get_node("%RoleLabel") as Label
	var avatar_preview := card.get_node("%AvatarPreview") as TextureRect
	var close_button := card.get_node("%CloseButton") as Button
	var header_row := card.get_node("Margin/Rows/HeaderRow") as HBoxContainer
	var action_grid := card.get_node("Margin/Rows/ActionGrid") as GridContainer
	if role_label == null or not role_label.text.contains("Female") or not role_label.text.contains("Far"):
		failures.append("Compact profile card did not show the selected role/range.")
	elif role_label.text.begins_with("Role:"):
		failures.append("Compact profile card kept the long role prefix.")
	if avatar_preview == null or avatar_preview.custom_minimum_size.x > 42.0:
		failures.append("Compact profile avatar preview did not release text width.")
	elif avatar_preview.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
		failures.append("Compact profile avatar preview still uses texture-size expansion.")
	if close_button == null or close_button.custom_minimum_size.x > 28.0:
		failures.append("Compact profile close button stayed oversized.")
	if header_row == null or header_row.get_theme_constant("separation") > 6:
		failures.append("Compact profile header gap stayed oversized.")
	if action_grid == null or action_grid.get_theme_constant("h_separation") > 6 or action_grid.get_theme_constant("v_separation") > 6:
		failures.append("Compact profile action grid gaps stayed oversized.")
	card.queue_free()
	await process_frame
	if failures.is_empty():
		print("player profile card compact smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
