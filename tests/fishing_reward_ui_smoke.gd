extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
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

	if not _has_image2_panel(instance.get_node("RootMargin/Layout/PondPanel")):
		failures.append("Fishing pond panel is not using an Image 2 frame.")
	if not _has_image2_button(instance.get_node("RootMargin/Layout/ActionRow/CastButton")):
		failures.append("Fishing cast button is not using an Image 2 frame.")

	instance.get_node("RootMargin/Layout/ActionRow/CastButton").pressed.emit()
	await create_timer(1.8).timeout
	var reward_panel := instance.get_node("RootMargin/Layout/PondPanel/PondMargin/PondRows/RewardPanel")
	if not bool(reward_panel.get("visible")):
		failures.append("Fishing reward panel did not open after a catch.")
	if not _has_image2_panel(reward_panel):
		failures.append("Fishing reward panel is not using an Image 2 frame.")
	if not _has_image2_button(reward_panel.get_node("RewardMargin/RewardRows/CastAgainButton")):
		failures.append("Fishing cast-again button is not using an Image 2 frame.")
	var icon := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardFishIcon") as TextureRect
	if icon == null or icon.texture == null:
		failures.append("Fishing reward panel did not show an Image 2 fish icon.")
	var coin_label := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardTextRows/RewardCoinLabel") as Label
	if coin_label == null or not coin_label.text.begins_with("+"):
		failures.append("Fishing reward coin label did not show the gained coin amount.")
	var rarity_label := reward_panel.get_node("RewardMargin/RewardRows/RewardContentRow/RewardTextRows/RewardRarityLabel") as Label
	if rarity_label == null or rarity_label.text.is_empty():
		failures.append("Fishing reward panel did not show a rarity callout.")
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

func _has_image2_button(node: Node) -> bool:
	if not node is Button:
		return false
	var style := (node as Button).get_theme_stylebox("normal")
	return style is StyleBoxTexture and (style as StyleBoxTexture).texture != null
