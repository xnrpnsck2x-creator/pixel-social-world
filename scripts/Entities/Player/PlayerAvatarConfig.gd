class_name PlayerAvatarConfig
extends RefCounted

const ConfigLoaderScript := preload("res://scripts/Core/ConfigLoader.gd")
const CONFIG_NAME := "player_animations"

func avatar_config(explicit_variant_id: String = "") -> Dictionary:
	var data: Dictionary = _load_config()
	var variant := _variant_config(data, explicit_variant_id)
	if variant.is_empty() and not explicit_variant_id.is_empty():
		variant = _variant_config(data, "")
	var avatar_id := str(variant.get("avatar_id", _saved_value("avatar_id", data.get("default_avatar", ""))))
	var avatar := _avatar_for_id(data, avatar_id)
	if avatar.is_empty():
		return {}
	var role := _class_for_id(data, str(variant.get("class_id", "")))
	if role.has("attack_emote_id"):
		avatar["attack_emote_id"] = role["attack_emote_id"]
	var feedback: Variant = role.get("attack_feedback", {})
	if typeof(feedback) == TYPE_DICTIONARY:
		avatar["attack_feedback"] = (feedback as Dictionary).duplicate(true)
	for key in ["id", "gender_id", "class_id", "name_key", "sprite_modulate", "sprite_scale"]:
		if variant.has(key):
			avatar[key if key != "id" else "character_variant_id"] = variant[key]
	avatar["avatar_id"] = avatar_id
	return avatar

static func sprite_modulate(config: Dictionary) -> Color:
	var value: Variant = config.get("sprite_modulate", [1.0, 1.0, 1.0, 1.0])
	if typeof(value) != TYPE_ARRAY:
		return Color.WHITE
	var parts: Array = value as Array
	if parts.size() < 3:
		return Color.WHITE
	var alpha := float(parts[3]) if parts.size() > 3 else 1.0
	return Color(float(parts[0]), float(parts[1]), float(parts[2]), alpha)

func _variant_config(data: Dictionary, explicit_variant_id: String) -> Dictionary:
	var variant_id := explicit_variant_id
	if variant_id.is_empty():
		var default_id := str(data.get("default_character_variant", ""))
		variant_id = str(_saved_value("character_variant_id", default_id))
	for variant in data.get("character_variants", []):
		if typeof(variant) == TYPE_DICTIONARY and str((variant as Dictionary).get("id", "")) == variant_id:
			return (variant as Dictionary).duplicate(true)
	return {}

func _avatar_for_id(data: Dictionary, avatar_id: String) -> Dictionary:
	for avatar in data.get("avatars", []):
		if typeof(avatar) == TYPE_DICTIONARY and str((avatar as Dictionary).get("id", "")) == avatar_id:
			return (avatar as Dictionary).duplicate(true)
	return {}

func _class_for_id(data: Dictionary, class_id: String) -> Dictionary:
	for role in data.get("classes", []):
		if typeof(role) == TYPE_DICTIONARY and str((role as Dictionary).get("id", "")) == class_id:
			return role as Dictionary
	return {}

func _load_config() -> Dictionary:
	var autoload := _root_node("ConfigLoader")
	if autoload != null and autoload.has_method("load_config"):
		return autoload.call("load_config", CONFIG_NAME) as Dictionary
	var loader := ConfigLoaderScript.new()
	var data: Dictionary = loader.load_config(CONFIG_NAME)
	loader.free()
	return data

func _saved_value(key: String, fallback: Variant) -> Variant:
	var autoload := _root_node("SaveSystem")
	if autoload != null and autoload.has_method("get_profile_value"):
		return autoload.call("get_profile_value", key, fallback)
	return fallback

func _root_node(node_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)
