extends SceneTree

const RouterScript := preload("res://scripts/Systems/Chat/ChatActionRouter.gd")

class FakeSessionService:
	extends Node

	var joined_session_id := ""
	var launched_game_id := ""

	func join_session(session_id: String) -> Dictionary:
		joined_session_id = session_id
		return {"ok": true, "data": {"game_id": "fishing"}}

	func launch_game(game_id: String) -> void:
		launched_game_id = game_id

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var router := RouterScript.new()
	var fake_service := FakeSessionService.new()
	root.add_child(fake_service)
	router.bind_minigame_session_service(fake_service)
	var handled: bool = await router.handle_action({
		"type": "join_minigame",
		"game_id": "fishing",
		"session_id": "session_router"
	})
	if not handled:
		failures.append("ChatActionRouter did not handle join_minigame.")
	if fake_service.joined_session_id != "session_router":
		failures.append("ChatActionRouter did not join the requested session.")
	if fake_service.launched_game_id != "fishing":
		failures.append("ChatActionRouter did not launch the joined game.")
	fake_service.queue_free()
	if failures.is_empty():
		print("chat action router smoke passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
