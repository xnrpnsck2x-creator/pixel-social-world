extends SceneTree

const DEFAULT_OUTPUT := "res://builds/android/pixel_social_world-debug.apk"

func _initialize() -> void:
	call_deferred("_export_android")

func _export_android() -> void:
	await create_timer(2.0).timeout
	var output_path := OS.get_environment("PSW_ANDROID_DEBUG_EXPORT_PATH")
	if output_path.is_empty():
		output_path = ProjectSettings.globalize_path(DEFAULT_OUTPUT)

	var platform := EditorExportPlatformAndroid.new()
	var preset := platform.create_preset()
	var load_error := _load_android_preset(preset)
	if load_error != OK:
		push_error("Failed to load Android export preset: %s" % load_error)
		quit(load_error)
		return

	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var export_error := platform.export_project(preset, true, output_path)
	for index in platform.get_message_count():
		var message := "%s | %s" % [
			platform.get_message_category(index),
			platform.get_message_text(index)
		]
		if platform.get_message_type(index) == EditorExportPlatform.EXPORT_MESSAGE_ERROR:
			push_error(message)
		else:
			print(message)
	if export_error == OK:
		print("Android debug APK exported: %s" % output_path)
	quit(export_error)

func _load_android_preset(preset: EditorExportPreset) -> int:
	var config := ConfigFile.new()
	var error := config.load("res://export_presets.cfg")
	if error != OK:
		return error

	var preset_section := _find_android_preset_section(config)
	if preset_section.is_empty():
		return ERR_DOES_NOT_EXIST

	for key in config.get_section_keys(preset_section):
		preset.set(key, config.get_value(preset_section, key))

	var options_section := "%s.options" % preset_section
	for key in config.get_section_keys(options_section):
		preset.set(key, config.get_value(options_section, key))
	return OK

func _find_android_preset_section(config: ConfigFile) -> String:
	for section in config.get_sections():
		if section.ends_with(".options"):
			continue
		if str(config.get_value(section, "platform", "")) == "Android":
			return section
	return ""
