extends Node

signal locale_changed(locale: String)
signal config_changed(config: Dictionary)
signal initialized

const DEFAULT_LOCALE := "en"
const LOCALIZATION_ROOT := "res://localization/"
const RuntimeConfigServiceScript := preload("res://scripts/Core/RuntimeConfigService.gd")

var app_config: Dictionary = {}
var current_locale := DEFAULT_LOCALE
var is_initialized := false
var supported_locales: PackedStringArray = PackedStringArray([DEFAULT_LOCALE])
var _strings: Dictionary = {}
var _runtime_config_service_fallback: Node

func _ready() -> void:
	app_config = await _load_resolved_app_config()
	supported_locales = PackedStringArray(app_config.get("supported_locales", [DEFAULT_LOCALE]))
	SaveSystem.load_profile()
	load_localization(SaveSystem.get_locale())
	config_changed.emit(app_config.duplicate(true))
	SceneRouter.initialize()
	is_initialized = true
	initialized.emit()

func refresh_runtime_config() -> Dictionary:
	app_config = await _load_resolved_app_config()
	config_changed.emit(app_config.duplicate(true))
	return app_config.duplicate(true)

func load_localization(locale: String) -> void:
	var safe_locale: String = locale if supported_locales.has(locale) else DEFAULT_LOCALE
	var path: String = LOCALIZATION_ROOT + safe_locale + ".json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing localization file: %s" % path)
		_strings = {}
		current_locale = DEFAULT_LOCALE
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Localization file is not a JSON object: %s" % path)
		_strings = {}
		current_locale = DEFAULT_LOCALE
		return

	_strings = parsed as Dictionary
	current_locale = safe_locale

func set_locale(locale: String) -> void:
	if locale == current_locale:
		return
	load_localization(locale)
	SaveSystem.set_locale(current_locale)
	locale_changed.emit(current_locale)

func t_key(key: String) -> String:
	return str(_strings.get(key, key))

func format_key(key: String, values: Dictionary) -> String:
	var text: String = t_key(key)
	for token in values.keys():
		text = text.replace("{" + str(token) + "}", str(values[token]))
	return text

func get_app_version() -> String:
	return str(app_config.get("version", "0.1.0"))

func get_runtime_gate() -> Dictionary:
	var maintenance: Dictionary = app_config.get("maintenance", {}) as Dictionary
	if bool(maintenance.get("enabled", false)):
		var message_key := str(maintenance.get("message_key", ""))
		if message_key.is_empty():
			message_key = "login.maintenance.detail"
		return {
			"blocked": true,
			"type": "maintenance",
			"title_key": "login.maintenance.title",
			"detail_key": message_key,
			"detail_values": {}
		}
	var minimum := str(app_config.get("min_client_version", ""))
	if not minimum.is_empty() and _compare_versions(get_app_version(), minimum) < 0:
		return {
			"blocked": true,
			"type": "version",
			"title_key": "login.version_blocked.title",
			"detail_key": "login.version_blocked.detail_format",
			"detail_values": {"current": get_app_version(), "minimum": minimum}
		}
	return {"blocked": false, "type": ""}

func _load_resolved_app_config() -> Dictionary:
	var config := ConfigLoader.load_config("app")
	var service := get_node_or_null("/root/RuntimeConfigService")
	if service == null:
		service = _get_runtime_config_service_fallback()
	if service != null:
		config = await service.call("resolve_app_config", config)
	return config

func _get_runtime_config_service_fallback() -> Node:
	if _runtime_config_service_fallback == null:
		_runtime_config_service_fallback = RuntimeConfigServiceScript.new()
		add_child(_runtime_config_service_fallback)
	return _runtime_config_service_fallback

func _compare_versions(left: String, right: String) -> int:
	var left_parts := left.split(".")
	var right_parts := right.split(".")
	var count: int = max(left_parts.size(), right_parts.size())
	for index in range(count):
		var left_value := _version_part_to_int(left_parts[index] if index < left_parts.size() else "0")
		var right_value := _version_part_to_int(right_parts[index] if index < right_parts.size() else "0")
		if left_value < right_value:
			return -1
		if left_value > right_value:
			return 1
	return 0

func _version_part_to_int(value: String) -> int:
	var digits := ""
	for character in value:
		if not character.is_valid_int():
			break
		digits += character
	return int(digits) if not digits.is_empty() else 0
