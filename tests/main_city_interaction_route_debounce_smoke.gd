extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var controller_script: GDScript = load("res://scripts/main_city/MainCityInteractionController.gd")
	var controller: Node = controller_script.new()
	root.add_child(controller)
	var city_events: Array[String] = []
	var fishing_events: Array[String] = []
	controller.city_requested.connect(func() -> void: city_events.append("city"))
	controller.fishing_requested.connect(func() -> void: fishing_events.append("fishing"))

	controller.route_touch_hotspot_action("to_city")
	controller.route_touch_hotspot_action("fishing")
	controller.route_hotspot_action("fishing")
	if city_events.size() != 1:
		failures.append("Initial return city route did not emit.")
	if fishing_events.size() != 0:
		failures.append("Immediate follow-up map routes were not suppressed.")
	controller.set("_touch_route_guard_until_msec", Time.get_ticks_msec() - 1)
	controller.route_hotspot_action("fishing")
	if fishing_events.size() != 1:
		failures.append("Map route stayed suppressed after debounce window.")

	controller.call("_on_hotspot_input_activated", "to_city", "touch")
	controller.route_hotspot_action("fishing")
	if city_events.size() != 2:
		failures.append("Input hotspot return city route did not emit.")
	if fishing_events.size() != 1:
		failures.append("Input hotspot return did not suppress immediate follow-up map route.")

	controller.queue_free()
	if failures.is_empty():
		print("main city interaction route debounce smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
