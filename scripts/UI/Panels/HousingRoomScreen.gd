extends Node2D

const HousingServiceScript := preload("res://scripts/Systems/Housing/HousingService.gd")
const HousingRoomArtScript := preload("res://scripts/UI/Panels/HousingRoomArt.gd")
const HousingRoomCatalogBarScript := preload("res://scripts/UI/Panels/HousingRoomCatalogBar.gd")
const HousingRoomEditControllerScript := preload("res://scripts/UI/Panels/HousingRoomEditController.gd")
const HousingRoomRendererScript := preload("res://scripts/UI/Panels/HousingRoomRenderer.gd")
const HousingRoomResponsiveLayoutScript := preload("res://scripts/UI/Panels/HousingRoomResponsiveLayout.gd")
const HousingRoomSocialControllerScript := preload("res://scripts/UI/Panels/HousingRoomSocialController.gd")
const HousingRoomSocialPanelScript := preload("res://scripts/UI/Panels/HousingRoomSocialPanel.gd")
const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")

var housing_service: HousingService
var art: HousingRoomArt
var renderer
var responsive_layout
var social_controller
var catalog_bar
var edit_controller
var hovered_tile := Vector2i(-1, -1)
var owner_id := ""
var room_id := ""
var is_visit_mode := false
var coin_label: Label
var top_panel: PanelContainer
var owner_label: Label
var invite_button: Button
var rotate_button: Button
var sell_button: Button
var undo_button: Button
var social_panel: PanelContainer
func _ready() -> void:
	owner_id = str(SaveSystem.get_profile_value("active_home_owner_id", SaveSystem.get_player_id()))
	if owner_id.is_empty():
		owner_id = SaveSystem.get_player_id()
	room_id = "home:%s" % owner_id
	is_visit_mode = bool(SaveSystem.get_profile_value("active_home_visit_mode", owner_id != SaveSystem.get_player_id()))
	_enter_room_lifecycle()
	_setup_services()
	_build_ui()
	_select_first_placeable()
	responsive_layout = HousingRoomResponsiveLayoutScript.new()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	queue_redraw()

func _draw() -> void:
	renderer.draw(
		self,
		edit_controller.selected_item_id,
		edit_controller.selected_placed_item,
		hovered_tile,
		is_visit_mode
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneRouter.route_to("main_city")
		get_viewport().set_input_as_handled()
		return
	if is_visit_mode:
		return
	if event is InputEventMouseMotion:
		_set_hovered_tile(renderer.tile_from_position(self, get_global_mouse_position()))
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and edit_controller.cancel_selection():
			queue_redraw()
		return
	var tile: Vector2i = renderer.tile_from_position(self, get_global_mouse_position())
	if tile.x < 0:
		return
	if edit_controller.handle_tile(tile):
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SceneRouter.route_to("main_city")

func _enter_room_lifecycle() -> void:
	if not has_node("/root/RoomLifecycle"):
		return
	get_node("/root/RoomLifecycle").call("enter_housing", owner_id, SaveSystem.get_display_name())

func _setup_services() -> void:
	housing_service = HousingServiceScript.new()
	add_child(housing_service)
	housing_service.initialize(owner_id, is_visit_mode)
	housing_service.layout_loaded.connect(_on_layout_loaded)
	housing_service.item_placed.connect(_on_layout_changed)
	housing_service.item_moved.connect(_on_layout_changed)
	housing_service.item_removed.connect(_on_item_removed)
	housing_service.style_changed.connect(_on_style_changed)
	housing_service.placement_failed.connect(_on_placement_failed)
	art = HousingRoomArtScript.new()
	renderer = HousingRoomRendererScript.new()
	renderer.configure(housing_service, art)
	edit_controller = HousingRoomEditControllerScript.new()
	edit_controller.name = "EditController"
	add_child(edit_controller)
	edit_controller.bind(housing_service)
	edit_controller.selection_changed.connect(_on_edit_selection_changed)
	edit_controller.coin_changed.connect(_refresh_coin)
	edit_controller.status_key_requested.connect(_on_placement_failed)
	edit_controller.status_text_requested.connect(_set_catalog_status_text)
	social_controller = HousingRoomSocialControllerScript.new()
	social_controller.name = "SocialController"
	add_child(social_controller)
	social_controller.initialize(owner_id, room_id)
	social_controller.bind_layout_service(housing_service)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_top_bar(layer)
	_build_social_panel(layer)
	_build_catalog_bar(layer)
	_refresh_coin()

func _build_top_bar(layer: CanvasLayer) -> void:
	top_panel = WorldHUDAssetsScript.create_panel(Control.PRESET_TOP_WIDE, Vector4(14, 10, -14, 58))
	top_panel.name = "TopPanel"
	layer.add_child(top_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	WorldHUDAssetsScript.add_margin_child(top_panel, top, Vector4(34, 8, 34, 8))
	var title := Label.new()
	title.text = App.t_key("scene.home.visit.title" if is_visit_mode else "scene.home.edit.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	owner_label = Label.new()
	owner_label.text = App.format_key("housing.owner_format", {"owner": owner_id})
	top.add_child(owner_label)
	coin_label = Label.new()
	top.add_child(coin_label)
	for label in [title, owner_label, coin_label]:
		label.modulate = PanelTextThemeScript.PRIMARY

	invite_button = Button.new()
	invite_button.text = App.t_key("housing.invite_button")
	invite_button.visible = not is_visit_mode
	invite_button.pressed.connect(_invite_home)
	WorldHUDAssetsScript.configure_button_frame(invite_button)
	top.add_child(invite_button)

	rotate_button = Button.new()
	rotate_button.text = App.t_key("housing.rotate_button")
	rotate_button.visible = not is_visit_mode
	rotate_button.disabled = true
	rotate_button.pressed.connect(_rotate_selected)
	WorldHUDAssetsScript.configure_button_frame(rotate_button)
	top.add_child(rotate_button)

	sell_button = Button.new()
	sell_button.text = App.t_key("housing.sell_button")
	sell_button.visible = not is_visit_mode
	sell_button.disabled = true
	sell_button.pressed.connect(_sell_selected)
	WorldHUDAssetsScript.configure_button_frame(sell_button)
	top.add_child(sell_button)

	undo_button = Button.new()
	undo_button.text = App.t_key("housing.undo_button")
	undo_button.visible = not is_visit_mode
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_last_edit)
	WorldHUDAssetsScript.configure_button_frame(undo_button)
	top.add_child(undo_button)

	var back := Button.new()
	back.text = App.t_key("ui.action.leave_home")
	back.pressed.connect(func() -> void: SceneRouter.route_to("main_city"))
	WorldHUDAssetsScript.configure_button_frame(back)
	top.add_child(back)

func _build_social_panel(layer: CanvasLayer) -> void:
	social_panel = HousingRoomSocialPanelScript.new()
	social_panel.name = "SocialPanel"
	social_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	social_panel.offset_left = -276.0 - 14.0
	social_panel.offset_top = 72.0
	social_panel.offset_right = -14.0
	social_panel.offset_bottom = 244.0
	layer.add_child(social_panel)
	social_controller.bind_panel(social_panel)

func _build_catalog_bar(layer: CanvasLayer) -> void:
	catalog_bar = HousingRoomCatalogBarScript.new()
	catalog_bar.name = "BottomPanel"
	catalog_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	catalog_bar.offset_left = 14.0
	catalog_bar.offset_top = -118.0
	catalog_bar.offset_right = -14.0
	catalog_bar.offset_bottom = -10.0
	catalog_bar.item_pressed.connect(_on_catalog_pressed)
	layer.add_child(catalog_bar)
	catalog_bar.bind_catalog(housing_service, art, is_visit_mode)
	_apply_responsive_layout()

func _on_catalog_pressed(item_id: String) -> void:
	if is_visit_mode:
		return
	edit_controller.handle_catalog_item(item_id)
	_set_hovered_tile(renderer.tile_from_position(self, get_global_mouse_position()))

func _rotate_selected() -> void:
	if edit_controller.rotate_selected():
		queue_redraw()

func _sell_selected() -> void:
	if edit_controller.sell_selected():
		queue_redraw()

func _undo_last_edit() -> void:
	if edit_controller.undo_last_transform():
		queue_redraw()

func _select_first_placeable() -> void:
	if catalog_bar != null:
		catalog_bar.select_first_placeable()

func _set_hovered_tile(tile: Vector2i) -> void:
	if hovered_tile == tile:
		return
	hovered_tile = tile
	queue_redraw()

func _on_layout_changed(_item: Variant) -> void:
	_refresh_coin()
	queue_redraw()

func _on_item_removed(item: Variant) -> void:
	_refresh_coin()
	var removed: Dictionary = item if typeof(item) == TYPE_DICTIONARY else {}
	var catalog_item: Dictionary = housing_service.get_item(str(removed.get("item_id", "")))
	var refund := housing_service.sell_refund_amount(str(removed.get("item_id", "")))
	catalog_bar.set_status_text(App.format_key("housing.sell_refund_format", {
		"item": App.t_key(str(catalog_item.get("name_key", ""))),
		"coins": refund
	}))
	queue_redraw()

func _on_style_changed(_category: String, _item_id: String) -> void:
	queue_redraw()

func _on_layout_loaded() -> void:
	_refresh_coin()
	edit_controller.reset_selection()
	_refresh_edit_buttons()
	queue_redraw()

func _on_placement_failed(reason_key: String) -> void:
	if catalog_bar != null:
		catalog_bar.set_status_key(reason_key)

func _refresh_coin() -> void:
	coin_label.text = App.format_key("world.coin_format", {
		"coins": SaveSystem.get_coin_balance()
	})

func _refresh_edit_buttons() -> void:
	var has_selection: bool = edit_controller.has_selection()
	if rotate_button != null:
		rotate_button.disabled = not has_selection
	if sell_button != null:
		sell_button.disabled = not has_selection
	if undo_button != null:
		undo_button.disabled = not edit_controller.can_undo()

func _on_edit_selection_changed() -> void:
	_refresh_edit_buttons()
	queue_redraw()

func _set_catalog_status_text(text: String) -> void:
	if catalog_bar != null:
		catalog_bar.set_status_text(text)

func _apply_responsive_layout() -> void:
	if responsive_layout == null or top_panel == null or social_panel == null or catalog_bar == null:
		return
	responsive_layout.apply(self, top_panel, owner_label, invite_button, social_panel, catalog_bar, renderer, art, is_visit_mode)
	queue_redraw()

func _invite_home() -> void:
	var response: Dictionary = {}
	if has_node("/root/OnlineClient") and bool(get_node("/root/OnlineClient").get("is_connected")):
		response = await get_node("/root/OnlineClient").call("create_housing_invite", owner_id)
	if response.is_empty() or bool(response.get("ok", false)):
		catalog_bar.set_status_text(App.format_key("housing.invite_ready_format", {"owner": owner_id}))
	else:
		catalog_bar.set_status_key("error.network")
