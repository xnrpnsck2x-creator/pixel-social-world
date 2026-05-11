extends SceneTree

const MOBILE_VIEWPORT := Vector2i(844, 390)
const MIN_PROMPT_TOP_Y := 108.0
const SCREEN_MARGIN := 4.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var original_size: Vector2i = root.size
	var original_content_scale_size: Vector2i = root.content_scale_size
	root.size = MOBILE_VIEWPORT
	root.content_scale_size = MOBILE_VIEWPORT
	var save_system := root.get_node("SaveSystem")
	save_system.call("load_profile")
	var original_profile: Dictionary = (save_system.get("profile") as Dictionary).duplicate(true)
	save_system.set("profile", {
		"id": "hotspot-prompt-safe-area",
		"display_name": "Prompt Safe",
		"locale": "en",
		"coin_balance": 0,
		"coin_ledger": [],
		"discovered_world_map_ids": ["city_forest_dawn_v1", "social_trade_market_v1"]
	})
	save_system.call("_apply_defaults")
	root.get_node("OnlineClient").call("configure", {"network": {"online_enabled": false}})

	var scene: PackedScene = load("res://scenes/main_city/MainCity.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	await _assert_hotspot_prompt(instance, "MapRoot/InteractionPoints/ShopHotspot", failures)
	instance.call("_switch_world_map", "social_trade_market_v1", "world.map_travel_generic")
	await process_frame
	await process_frame
	await _assert_hotspot_prompt(instance, "MapRoot/InteractionPoints/TradeMarketHotspot", failures)

	instance.queue_free()
	save_system.set("profile", original_profile)
	save_system.call("save_profile")
	root.content_scale_size = original_content_scale_size
	root.size = original_size
	if failures.is_empty():
		print("hotspot prompt safe area smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_hotspot_prompt(instance: Node, path: String, failures: Array[String]) -> void:
	var hotspot := instance.get_node_or_null(path)
	if hotspot == null or not hotspot.visible:
		failures.append("%s is not available for mobile prompt safe-area testing." % path)
		return
	var prompt := hotspot.get_node_or_null("PromptLabel") as Label
	if prompt == null:
		failures.append("%s is missing PromptLabel." % path)
		return
	if prompt.visible:
		failures.append("%s prompt should start hidden before touch feedback." % path)
	if not hotspot.has_method("show_prompt_feedback"):
		failures.append("%s does not expose touch feedback." % path)
		return
	hotspot.call("show_prompt_feedback", 2.0)
	await process_frame
	if hotspot.has_method("refresh_prompt_layout"):
		hotspot.call("refresh_prompt_layout")
	await process_frame
	if not prompt.visible:
		failures.append("%s prompt did not show for touch feedback." % path)
		return
	var rect := _prompt_screen_rect(prompt)
	if rect.position.y < MIN_PROMPT_TOP_Y:
		failures.append("%s prompt overlaps mobile top HUD at y %.1f." % [path, rect.position.y])
	if rect.position.x < SCREEN_MARGIN or rect.end.x > float(MOBILE_VIEWPORT.x) - SCREEN_MARGIN:
		failures.append("%s prompt is outside mobile side margins: %s." % [path, rect])

func _prompt_screen_rect(prompt: Label) -> Rect2:
	var size := Vector2(
		prompt.offset_right - prompt.offset_left,
		prompt.offset_bottom - prompt.offset_top
	)
	var transform := prompt.get_global_transform_with_canvas()
	var rect := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	rect = rect.expand(transform * Vector2(size.x, 0.0))
	rect = rect.expand(transform * Vector2(0.0, size.y))
	rect = rect.expand(transform * size)
	return rect
