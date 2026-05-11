extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/login/Login.tscn")
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame

	var panel := instance.get_node("%LoginPanel")
	var gender_picker := panel.get_node("%GenderPicker") as OptionButton
	var class_picker := panel.get_node("%ClassPicker") as OptionButton
	if gender_picker.item_count != 2:
		failures.append("Login character picker must expose male and female choices.")
	if class_picker.item_count != 3:
		failures.append("Login character picker must expose melee, ranged, and magic choices.")
	await _assert_name_input_submission(panel, failures)
	_assert_all_character_variants(panel, gender_picker, class_picker, instance, failures)

	instance.queue_free()
	if failures.is_empty():
		print("login character selection smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _select_by_metadata(picker: OptionButton, value: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			picker.select(index)
			return

func _assert_name_input_submission(panel: Node, failures: Array[String]) -> void:
	var name_input := panel.get_node("%NameInput") as LineEdit
	var submitted := {"count": 0, "name": ""}
	panel.connect("login_requested", func(display_name: String, _character: Dictionary) -> void:
		submitted["count"] = int(submitted["count"]) + 1
		submitted["name"] = display_name
	)
	name_input.text = "Mobile Done"
	name_input.emit_signal("text_submitted", name_input.text)
	await process_frame
	if int(submitted.get("count", 0)) != 1:
		failures.append("Login name input Done/Enter did not submit the login form.")
	if str(submitted.get("name", "")) != "Mobile Done":
		failures.append("Login name input submitted the wrong display name.")
	name_input.text = "Hardware Enter"
	name_input.grab_focus()
	var enter_event := InputEventKey.new()
	enter_event.keycode = KEY_ENTER
	enter_event.pressed = true
	panel.call("_unhandled_key_input", enter_event)
	await process_frame
	if int(submitted.get("count", 0)) != 2:
		failures.append("Login hardware Enter fallback did not submit the login form.")
	if str(submitted.get("name", "")) != "Hardware Enter":
		failures.append("Login hardware Enter fallback submitted the wrong display name.")
	name_input.text = "Input Enter"
	name_input.emit_signal("gui_input", enter_event)
	await process_frame
	if int(submitted.get("count", 0)) != 3:
		failures.append("Login input-level Enter fallback did not submit the login form.")
	if str(submitted.get("name", "")) != "Input Enter":
		failures.append("Login input-level Enter fallback submitted the wrong display name.")

func _assert_all_character_variants(
	panel: Node,
	gender_picker: OptionButton,
	class_picker: OptionButton,
	instance: Node,
	failures: Array[String]
) -> void:
	var expected := [
		{"gender": "male", "class": "melee", "variant": "male_melee_v0", "avatar": "male_melee_v1", "range": "near"},
		{"gender": "male", "class": "ranged", "variant": "male_ranged_v0", "avatar": "male_ranged_v1", "range": "far"},
		{"gender": "male", "class": "magic", "variant": "male_magic_v0", "avatar": "male_magic_v1", "range": "magic"},
		{"gender": "female", "class": "melee", "variant": "female_melee_v0", "avatar": "female_melee_v1", "range": "near"},
		{"gender": "female", "class": "ranged", "variant": "female_ranged_v0", "avatar": "female_ranged_v1", "range": "far"},
		{"gender": "female", "class": "magic", "variant": "female_magic_v0", "avatar": "female_magic_v1", "range": "magic"}
	]
	var preview := instance.get_node_or_null("%AvatarPreview") as TextureRect
	var variant_label := instance.get_node_or_null("%VariantNameLabel") as Label
	var range_label := instance.get_node_or_null("%ClassRangeLabel") as Label
	if preview == null:
		failures.append("Login character picker is missing the formal action-sheet preview.")
	if variant_label == null:
		failures.append("Login character preview is missing the selected variant label.")
	if range_label == null:
		failures.append("Login character preview is missing the class range label.")
	for record in expected:
		_select_by_metadata(gender_picker, str(record.get("gender", "")))
		_select_by_metadata(class_picker, str(record.get("class", "")))
		panel.call("_refresh_character_preview")
		var character: Dictionary = panel.call("_selected_character")
		if str(character.get("character_variant_id", "")) != str(record.get("variant", "")):
			failures.append("Login character picker did not resolve %s." % record.get("variant", ""))
		if str(character.get("avatar_id", "")) != str(record.get("avatar", "")):
			failures.append("Login character picker did not resolve avatar %s." % record.get("avatar", ""))
		var expected_path := "player_%s_actions_v1" % str(record.get("avatar", "")).replace("_v1", "")
		if preview != null and (preview.texture == null or not preview.texture.resource_path.contains(expected_path)):
			failures.append("Login character preview did not load %s." % record.get("avatar", ""))
		if variant_label != null and variant_label.text.strip_edges().is_empty():
			failures.append("Login character preview did not refresh label for %s." % record.get("variant", ""))
		var expected_range := str(root.get_node("App").call("t_key", "character.range.%s" % record.get("range", "")))
		if range_label != null and range_label.text != expected_range:
			failures.append("Login character preview did not show range %s." % record.get("range", ""))
