class_name MapActivityProgress
extends RefCounted

const INVENTORY_KEY := "map_activity_inventory"
const SKILL_XP_KEY := "map_activity_skill_xp"

static func apply_result(result: Dictionary) -> void:
	var changed := false
	for drop in result.get("drops", []):
		if typeof(drop) == TYPE_DICTIONARY:
			changed = _grant_drop(drop as Dictionary) or changed
	var skill_id: String = str(result.get("skill_id", ""))
	var skill_xp: int = int(result.get("skill_xp", 0))
	if not skill_id.is_empty() and skill_xp > 0:
		changed = _grant_skill_xp(skill_id, skill_xp) or changed
	if changed:
		SaveSystem.save_profile()

static func sync_inventory_items(items: Array, item_ids: Array) -> void:
	var wanted := {}
	for item_id in item_ids:
		wanted[str(item_id)] = true
	if wanted.is_empty():
		return
	var changed := false
	for raw in items:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw as Dictionary
		var item_id := str(item.get("item_id", ""))
		if not wanted.has(item_id):
			continue
		changed = _set_drop_quantity(item_id, int(item.get("owned", 0))) or changed
	if changed:
		SaveSystem.save_profile()

static func inventory() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(INVENTORY_KEY, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	var empty: Dictionary = {}
	SaveSystem.set_profile_value(INVENTORY_KEY, empty)
	return empty

static func skill_xp() -> Dictionary:
	var value: Variant = SaveSystem.get_profile_value(SKILL_XP_KEY, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	var empty: Dictionary = {}
	SaveSystem.set_profile_value(SKILL_XP_KEY, empty)
	return empty

static func _grant_drop(drop: Dictionary) -> bool:
	var item_id: String = str(drop.get("item_id", ""))
	var amount: int = max(0, int(drop.get("amount", 0)))
	if item_id.is_empty() or amount <= 0:
		return false
	var items: Dictionary = inventory()
	var record: Dictionary = items.get(item_id, {
		"item_id": item_id,
		"quantity": 0,
		"rarity": str(drop.get("rarity", "common"))
	}) as Dictionary
	record["quantity"] = int(record.get("quantity", 0)) + amount
	record["rarity"] = str(drop.get("rarity", record.get("rarity", "common")))
	items[item_id] = record
	return true

static func _set_drop_quantity(item_id: String, quantity: int) -> bool:
	if item_id.is_empty():
		return false
	var items: Dictionary = inventory()
	var record: Dictionary = items.get(item_id, {
		"item_id": item_id,
		"quantity": 0,
		"rarity": "common"
	}) as Dictionary
	var normalized_quantity: int = max(0, quantity)
	if int(record.get("quantity", 0)) == normalized_quantity:
		return false
	record["quantity"] = normalized_quantity
	items[item_id] = record
	return true

static func _grant_skill_xp(skill_id: String, amount: int) -> bool:
	var skills: Dictionary = skill_xp()
	skills[skill_id] = int(skills.get(skill_id, 0)) + amount
	return true
