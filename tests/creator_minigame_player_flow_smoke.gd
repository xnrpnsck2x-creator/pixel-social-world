extends SceneTree

class FakeRegistry:
	extends Node
	signal catalog_updated
	var games: Array[Dictionary] = [
		{
			"id": "fishing",
			"name_key": "minigame.fishing.name",
			"enabled": true,
			"max_players": 4
		},
		{
			"id": "creator_player_flow",
			"name": {
				"en": "Creator Player Flow",
				"ja": "Creator Player Flow",
				"zh-Hans": "Creator Player Flow"
			},
			"enabled": true,
			"max_players": 4,
			"source": "creator"
		}
	]

	func get_enabled_minigames() -> Array[Dictionary]:
		return games.duplicate(true)

	func get_minigame(game_id: String) -> Dictionary:
		for game in games:
			if str(game.get("id", "")) == game_id:
				return game.duplicate(true)
		return {}

class FakeSessions:
	extends Node
	signal sessions_updated(sessions: Array[Dictionary])
	var created_game_id := ""
	var launched_game_id := ""

	func get_sessions() -> Array[Dictionary]:
		return []

	func create_session(game_id: String) -> Dictionary:
		created_game_id = game_id
		return {
			"ok": true,
			"data": {
				"id": "session_%s" % game_id,
				"game_id": game_id,
				"players": ["player"],
				"max_players": 4
			}
		}

	func launch_game(game_id: String) -> void:
		launched_game_id = game_id

	func refresh_sessions() -> void:
		sessions_updated.emit([])

	func get_game(_game_id: String) -> Dictionary:
		return {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var scene: PackedScene = load("res://scenes/ui/OnlineRoomPanel.tscn")
	var panel: Node = scene.instantiate()
	root.add_child(panel)
	var registry := FakeRegistry.new()
	var sessions := FakeSessions.new()
	root.add_child(registry)
	root.add_child(sessions)
	panel.call("bind_services", null, null, registry, sessions)
	await process_frame

	var picker := panel.get_node("%GamePicker") as OptionButton
	var creator_index := -1
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == "creator_player_flow":
			creator_index = index
			break
	if creator_index < 0:
		failures.append("Published creator game was not selectable in the room panel.")
	else:
		picker.select(creator_index)
		(panel.get_node("%HostFishingButton") as Button).pressed.emit()
		await process_frame
		if sessions.created_game_id != "creator_player_flow":
			failures.append("Room creation ignored the selected creator game.")
		if sessions.launched_game_id != "creator_player_flow":
			failures.append("Player launch ignored the selected creator game.")

	panel.queue_free()
	registry.queue_free()
	sessions.queue_free()
	await process_frame
	if failures.is_empty():
		print("creator minigame player flow smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
