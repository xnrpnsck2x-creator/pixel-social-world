extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	DisplayServer.window_set_size(Vector2i(844, 390))
	root.size = Vector2i(844, 390)
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "fishing-reward-ui-player",
		"device_id": "fishing-reward-ui-device",
		"display_name": "Fishing UI",
		"locale": "en",
		"coin_balance": 25,
		"coin_ledger": [],
		"current_route": "minigame_fishing",
		"inventory": [],
		"owned_items": ["starter_wallpaper", "wooden_floor"],
		"house_styles": {"wall": "starter_wallpaper", "floor": "wooden_floor"},
		"house_items": [],
		"house_sync_required": false
	})
	save_system.call("_apply_defaults")

	var scene: PackedScene = load("res://scenes/minigames/fishing/main.tscn")
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.call("_apply_layout_density", true)

	var pond_panel := instance.get_node("RootMargin/Layout/PondPanel") as PanelContainer
	if not _has_image2_panel(pond_panel):
		failures.append("Fishing pond panel is not using an Image 2 frame.")
	elif not _uses_large_panel_frame(pond_panel):
		failures.append("Fishing pond panel is using a stretched HUD bar frame instead of the large panel frame.")
	if pond_panel.custom_minimum_size.x > 610.0:
		failures.append("Fishing compact pond panel still stretches too wide on mobile landscape.")
	if not _has_image2_button(instance.get_node("%CastButton")):
		failures.append("Fishing cast button is not using an Image 2 frame.")
	elif (instance.get_node("%CastButton") as Button).custom_minimum_size.y > 32.0:
		failures.append("Fishing compact cast button stayed too tall.")

	instance.get_node("%CastButton").pressed.emit()
	await create_timer(1.8).timeout
	var reward_panel := instance.get_node("RootMargin/Layout/PondPanel/PondMargin/PondRows/RewardPanel")
	if not bool(reward_panel.get("visible")):
		failures.append("Fishing reward panel did not open after a catch.")
	if (reward_panel as Control).custom_minimum_size.y > 82.0:
		failures.append("Fishing compact reward panel stayed too tall.")
	if not _has_image2_panel(reward_panel):
		failures.append("Fishing reward panel is not using an Image 2 frame.")
	elif not _uses_large_panel_frame(reward_panel):
		failures.append("Fishing reward panel is using a stretched HUD bar frame instead of the large panel frame.")
	if not _has_image2_button(reward_panel.get_node("RewardMargin/RewardRows/CastAgainButton")):
		failures.append("Fishing cast-again button is not using an Image 2 frame.")
	var icon := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardFishIcon") as TextureRect
	if icon == null or icon.texture == null:
		failures.append("Fishing reward panel did not show an Image 2 fish icon.")
	elif icon.custom_minimum_size.x > 42.0:
		failures.append("Fishing compact reward icon stayed oversized.")
	var coin_label := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardTextRows/RewardCoinLabel") as Label
	if coin_label == null or not coin_label.text.begins_with("+"):
		failures.append("Fishing reward coin label did not show the gained coin amount.")
	elif not _uses_readable_panel_text(coin_label):
		failures.append("Fishing reward coin label did not use readable panel text color.")
	var rarity_label := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardTextRows/RewardRarityLabel") as Label
	if rarity_label == null or rarity_label.text.is_empty():
		failures.append("Fishing reward panel did not show a rarity callout.")
	var status_label := instance.get_node("%StatusLabel") as Label
	if status_label == null or not _uses_readable_panel_text(status_label):
		failures.append("Fishing status label did not use readable panel text color.")
	if int(save_system.call("get_coin_balance")) <= 25:
		failures.append("Fishing catch did not add coins to the wallet.")

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")

	if failures.is_empty():
		print("fishing reward ui smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _has_image2_panel(node: Node) -> bool:
	if not node is PanelContainer:
		return false
	var style := (node as PanelContainer).get_theme_stylebox("panel")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func _uses_large_panel_frame(node: Node) -> bool:
	var style := (node as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	return style.texture.resource_path.ends_with("ui_panel_frame_v1_alpha.png")

func _has_image2_button(node: Node) -> bool:
	if not node is Button:
		return false
	var style := (node as Button).get_theme_stylebox("normal")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null

func _uses_readable_panel_text(label: Label) -> bool:
	var color := label.get_theme_color("font_color")
	return color.r < 0.55 and color.g < 0.45 and color.b < 0.35
