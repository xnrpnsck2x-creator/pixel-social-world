extends SceneTree

const WorldHUDAssets := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	if not WorldHUDAssets.should_hide_action_tooltip_for("Android", false, Vector2(2400, 1080)):
		failures.append("Android action tooltips should be hidden even on high-density landscape screens.")
	if not WorldHUDAssets.should_hide_action_tooltip_for("iOS", false, Vector2(844, 390)):
		failures.append("iOS action tooltips should be hidden.")
	if not WorldHUDAssets.should_hide_action_tooltip_for("Web", true, Vector2(844, 390)):
		failures.append("Touch Web compact action tooltips should be hidden.")
	if WorldHUDAssets.should_hide_action_tooltip_for("Web", true, Vector2(1440, 900)):
		failures.append("Desktop-sized Web action tooltips should remain available.")
	if WorldHUDAssets.should_hide_action_tooltip_for("macOS", false, Vector2(1440, 900)):
		failures.append("Desktop mouse action tooltips should remain available.")

	if failures.is_empty():
		print("hud tooltip policy smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
