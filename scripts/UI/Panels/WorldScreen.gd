extends Node2D

@onready var player: CharacterBody2D = %Player
@onready var hud: CanvasLayer = %WorldHUD
@onready var chat_service: Node = %ChatService
@onready var housing_service: Node = %HousingService
@onready var minigame_registry: Node = %MinigameRegistry
@onready var emote_sync: Node = %EmoteSync

func _ready() -> void:
	var display_name: String = SaveSystem.get_display_name()
	if display_name.is_empty():
		display_name = App.t_key("login.default_name")

	chat_service.initialize()
	housing_service.initialize()
	minigame_registry.initialize()
	hud.bind_services(chat_service, housing_service, minigame_registry)
	hud.set_player_name(display_name)
	hud.emote_requested.connect(_on_emote_requested)
	emote_sync.emote_received.connect(_on_emote_received)
	player.display_name = display_name
	if has_node("/root/RoomLifecycle"):
		get_node("/root/RoomLifecycle").call("enter_main_city", display_name)

func _on_emote_requested(emote_id: String) -> void:
	emote_sync.send_emote(SaveSystem.get_player_id(), emote_id)

func _on_emote_received(player_id: String, emote_id: String) -> void:
	if player_id != SaveSystem.get_player_id():
		return
	if player.has_method("show_emote"):
		player.show_emote(emote_id)
