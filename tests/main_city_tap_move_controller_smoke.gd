extends SceneTree

const TapMoveController := preload("res://scripts/main_city/MainCityTapMoveController.gd")

class MockPlayer:
	extends Node2D
	var walkable := true

	func can_enter_world_position(_position: Vector2) -> bool:
		return walkable

class MockHotspot:
	extends Area2D
	signal activated(action_id: String)

	var action_id := ""
	var feedback_count := 0

	func activate() -> void:
		activated.emit(action_id)

	func show_prompt_feedback(_seconds: float = 1.6) -> void:
		feedback_count += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var controller := TapMoveController.new()
	var player := MockPlayer.new()
	root.add_child(player)
	root.add_child(controller)
	controller.bind(player)
	if controller.is_processing():
		failures.append("Tap move controller should not process while idle.")

	controller.call("_set_target", Vector2(120, 0))
	if not controller.is_processing():
		failures.append("Tap move controller should process while moving toward a target.")
	_assert_marker(controller, true, Vector2(120, 0), "valid movement target", failures)
	controller.call("_process", 0.016)
	if not Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller did not press ui_right for a right-side target.")
	player.global_position = Vector2(118, 0)
	controller.call("_process", 0.016)
	if Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller did not release movement after arriving.")
	if controller.is_processing():
		failures.append("Tap move controller should stop processing after arriving.")
	_assert_marker(controller, false, Vector2.ZERO, "arrival clear", failures)

	player.walkable = false
	controller.call("_set_target", Vector2(240, 0))
	controller.call("_process", 0.016)
	if Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller moved toward an unwalkable target.")
	_assert_marker(controller, false, Vector2.ZERO, "unwalkable target", failures)
	player.walkable = true

	var hotspot := MockHotspot.new()
	hotspot.action_id = "games"
	hotspot.position = Vector2(160, 0)
	hotspot.add_to_group("main_city_hotspot")
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 48)
	collision.shape = shape
	hotspot.add_child(collision)
	var prompt := Label.new()
	prompt.name = "PromptLabel"
	hotspot.add_child(prompt)
	root.add_child(hotspot)
	await process_frame

	var activations: Array[String] = []
	controller.hotspot_requested.connect(func(action_id: String) -> void: activations.append(action_id))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(320, 0)
	player.walkable = false
	controller.call("_unhandled_input", touch)
	controller.call("_process", 0.016)
	if activations != ["games"]:
		failures.append("Tap move controller did not prioritize a nearby mobile hotspot touch.")
	if hotspot.feedback_count != 1:
		failures.append("Tap move controller did not show feedback for a nearby mobile hotspot touch.")
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_down"):
		failures.append("Tap move controller kept moving after activating a hotspot.")
	_assert_marker(controller, false, Vector2.ZERO, "hotspot activation", failures)

	player.walkable = true
	controller.call("_unhandled_input", touch)
	controller.call("_process", 0.016)
	if activations.size() != 1:
		failures.append("Tap move controller reactivated a hotspot for a walkable nearby tap.")
	if hotspot.feedback_count != 1:
		failures.append("Tap move controller showed feedback for a walkable nearby tap.")
	if not Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller did not keep walkable nearby taps as movement.")
	controller.call("_clear_target")
	hotspot.set_meta("mobile_touch_rect", Rect2(Vector2(300, -30), Vector2(70, 60)))
	controller.call("_unhandled_input", touch)
	controller.call("_process", 0.016)
	if activations != ["games"]:
		failures.append("Tap move controller activated a broad mobile touch rect on walkable ground.")
	if hotspot.feedback_count != 1:
		failures.append("Tap move controller showed feedback for a walkable mobile touch rect tap.")
	if not Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller did not keep walkable mobile touch rect taps as movement.")
	controller.call("_clear_target")

	player.walkable = false
	controller.call("_unhandled_input", touch)
	controller.call("_process", 0.016)
	if activations != ["games", "games"]:
		failures.append("Tap move controller ignored a configured mobile hotspot touch rect when the destination was blocked.")
	if hotspot.feedback_count != 2:
		failures.append("Tap move controller did not show feedback for a blocked mobile hotspot touch rect.")
	if Input.is_action_pressed("ui_right"):
		failures.append("Tap move controller moved after a blocked mobile hotspot touch rect hit.")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = touch.position
	controller.call("_unhandled_input", mouse)
	if activations != ["games", "games"]:
		failures.append("Tap move controller allowed a synthetic mouse event to double-activate a hotspot.")
	if hotspot.feedback_count != 2:
		failures.append("Tap move controller showed feedback for a synthetic duplicate mouse event.")

	hotspot.queue_free()
	controller.queue_free()
	player.queue_free()
	await process_frame

	if failures.is_empty():
		print("main city tap move controller smoke passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_marker(
	controller: Node,
	should_show: bool,
	expected_position: Vector2,
	label: String,
	failures: Array[String]
) -> void:
	var marker := controller.get_node_or_null("TapTargetMarker") as Sprite2D
	if marker == null:
		failures.append("Tap move controller is missing TapTargetMarker for %s." % label)
		return
	if marker.visible != should_show:
		failures.append("Tap target marker visibility drifted for %s." % label)
	if not should_show:
		return
	if marker.texture == null:
		failures.append("Tap target marker is missing its formal texture for %s." % label)
	if marker.global_position.distance_to(expected_position) > 0.5:
		failures.append("Tap target marker did not move to %s for %s." % [str(expected_position), label])
	var pulse := controller.get_node_or_null("TapTargetPulse") as Line2D
	if pulse == null:
		failures.append("Tap move controller is missing TapTargetPulse for %s." % label)
	elif pulse.visible != should_show:
		failures.append("Tap target pulse visibility drifted for %s." % label)
