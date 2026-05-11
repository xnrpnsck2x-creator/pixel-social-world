extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var config: Dictionary = root.get_node("ConfigLoader").call("load_config", "map_points")
	var maps: Dictionary = config.get("maps", {}) as Dictionary
	var main_city: Dictionary = maps.get("city_forest_dawn_v1", {}) as Dictionary
	var trade_point := _point_by_id(main_city.get("interaction_points", []) as Array, "trade")
	if trade_point.is_empty():
		failures.append("Main city trade hotspot is missing.")
	else:
		_assert_trade_hotspot_precision(trade_point, failures)
	if failures.is_empty():
		print("main city hotspot precision smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _assert_trade_hotspot_precision(trade_point: Dictionary, failures: Array[String]) -> void:
	var rect: Dictionary = trade_point.get("touch_rect", {}) as Dictionary
	if rect.is_empty():
		failures.append("Main city trade hotspot is missing its mobile touch rect.")
		return
	if _rect_contains(rect, Vector2(1000, 590)):
		failures.append("Trade hotspot still captures the southeast walkway tap probe.")
	if not _rect_contains(rect, Vector2(float(trade_point.get("x", 0.0)), float(trade_point.get("y", 0.0)))):
		failures.append("Trade hotspot no longer contains its configured interaction point.")
	if float(rect.get("width", 0.0)) > 340.0 or float(rect.get("height", 0.0)) > 140.0:
		failures.append("Trade hotspot mobile touch rect is too broad for tap-to-move.")

func _point_by_id(points: Array, target_id: String) -> Dictionary:
	for record in points:
		if typeof(record) == TYPE_DICTIONARY and str((record as Dictionary).get("id", "")) == target_id:
			return record as Dictionary
	return {}

func _rect_contains(rect: Dictionary, point: Vector2) -> bool:
	var x := float(rect.get("x", 0.0))
	var y := float(rect.get("y", 0.0))
	var width := float(rect.get("width", 0.0))
	var height := float(rect.get("height", 0.0))
	return point.x >= x and point.x <= x + width and point.y >= y and point.y <= y + height
