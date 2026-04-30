extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var manifest := _load_manifest("res://scenes/minigames/fishing/meta.json")
	var errors := MinigameManifestValidator.validate(manifest)
	if not errors.is_empty():
		failures.append("Official fishing manifest failed: %s" % ", ".join(errors))

	var bad_manifest := manifest.duplicate(true)
	bad_manifest.erase("mode_id")
	errors = MinigameManifestValidator.validate(bad_manifest)
	if errors.is_empty():
		failures.append("Manifest validator accepted a missing mode_id.")

	bad_manifest = manifest.duplicate(true)
	bad_manifest["mode_id"] = "battle_royale"
	bad_manifest["max_players"] = 20
	errors = MinigameManifestValidator.validate(bad_manifest)
	if errors.is_empty():
		failures.append("Manifest validator accepted a battle royale player cap overflow.")

	var fighting_manifest := manifest.duplicate(true)
	fighting_manifest["mode_id"] = "2d_fighting"
	fighting_manifest["max_players"] = 4
	errors = MinigameManifestValidator.validate(fighting_manifest)
	if not errors.is_empty():
		failures.append("Manifest validator rejected a valid 2D fighting player cap: %s" % ", ".join(errors))

	fighting_manifest["max_players"] = 5
	errors = MinigameManifestValidator.validate(fighting_manifest)
	if errors.is_empty():
		failures.append("Manifest validator accepted a 2D fighting player cap overflow.")

	if failures.is_empty():
		print("minigame contract smoke passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)

func _load_manifest(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
