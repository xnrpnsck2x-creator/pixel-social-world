class_name MapActivityRewardText
extends RefCounted

static func success_message(base_message: String, result: Dictionary) -> String:
	var parts := PackedStringArray()
	var skill_id := str(result.get("skill_id", ""))
	var skill_xp := int(result.get("skill_xp", 0))
	if not skill_id.is_empty() and skill_xp > 0:
		parts.append(App.format_key("map_activity.reward.skill_xp_format", {
			"skill": skill_name(skill_id),
			"xp": skill_xp
		}))
	for drop in result.get("drops", []):
		if typeof(drop) == TYPE_DICTIONARY:
			var drop_text := drop_summary(drop as Dictionary)
			if not drop_text.is_empty():
				parts.append(drop_text)
	var rare: Variant = result.get("rare_event", {})
	if typeof(rare) == TYPE_DICTIONARY and not (rare as Dictionary).is_empty():
		parts.append(App.format_key("map_activity.reward.rare_format", {
			"title": App.t_key(str((rare as Dictionary).get("title_key", "map_activity.rare.generic")))
		}))
	if parts.is_empty():
		return base_message
	return "%s %s" % [
		base_message,
			App.format_key("map_activity.reward.summary_format", {"rewards": ", ".join(parts)})
	]

static func drop_summary(drop: Dictionary) -> String:
	var item_id := str(drop.get("item_id", ""))
	var amount := int(drop.get("amount", 0))
	if item_id.is_empty() or amount <= 0:
		return ""
	return App.format_key("map_activity.reward.drop_format", {
		"item": item_name(item_id),
		"amount": amount
	})

static func skill_name(skill_id: String) -> String:
	return _translated_or_title("map_activity.skill.%s" % skill_id, skill_id)

static func item_name(item_id: String) -> String:
	return _translated_or_title("map_activity.item.%s" % item_id, item_id)

static func rarity_name(rarity_id: String) -> String:
	return _translated_or_title("map_activity.rarity.%s" % rarity_id, rarity_id)

static func _translated_or_title(key: String, fallback_id: String) -> String:
	var text := App.t_key(key)
	if text != key:
		return text
	return fallback_id.replace("_", " ").capitalize()
