class_name WorldUtilityPanel
extends PanelContainer
signal utility_action_requested(action_id: String)
const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")
const CreatorContractRowsScript := preload("res://scripts/UI/Panels/CreatorContractRows.gd")
const CreatorDraftRowsScript := preload("res://scripts/UI/Panels/CreatorDraftRows.gd")
const CreatorPackageRowsScript := preload("res://scripts/UI/Panels/CreatorPackageRows.gd")
const CreatorReviewerRowsScript := preload("res://scripts/UI/Panels/CreatorReviewerRows.gd")
const CreatorStatusRowsScript := preload("res://scripts/UI/Panels/CreatorStatusRows.gd")
const MapAtlasRowsScript := preload("res://scripts/UI/Panels/MapAtlasRows.gd")
const MapDirectoryRowsScript := preload("res://scripts/UI/Panels/MapDirectoryRows.gd")
const PanelListFrameScript := preload("res://scripts/UI/Panels/PanelListFrame.gd")
const PanelTextThemeScript := preload("res://scripts/UI/Panels/PanelTextTheme.gd")
const WorldUtilityInventoryRowsScript := preload("res://scripts/UI/Panels/WorldUtilityInventoryRows.gd")
const WorldUtilityPanelContentScript := preload("res://scripts/UI/Panels/WorldUtilityPanelContent.gd")
var active_panel_id := ""
var _compact_layout := false
var _creator_draft_rows
var _creator_package_rows
var _remote_utility_config := {}
var _online_inventory_items: Array = []
var _inventory_online_loaded := false
var _content := WorldUtilityPanelContentScript.new()
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var body_label: Label = %BodyLabel
@onready var detail_label: Label = %DetailLabel
@onready var items_scroll: ScrollContainer = %ItemsScroll
@onready var items_rows: VBoxContainer = %ItemsRows

func _ready() -> void:
	visible = false
	close_button.pressed.connect(hide_panel)
	App.locale_changed.connect(_on_locale_changed)
	_apply_image2_style()
	set_compact_layout(_compact_layout)

func show_panel(panel_id: String) -> void:
	active_panel_id = panel_id
	visible = true
	_refresh_text()
	if panel_id == "inventory":
		_inventory_online_loaded = false
		_online_inventory_items = []
		call_deferred("_refresh_online_inventory")
	if panel_id == "shop" or panel_id == "mail" or panel_id == "notice":
		call_deferred("_refresh_remote_utility_config", panel_id)

func hide_panel() -> void:
	visible = false
func set_compact_layout(enabled: bool) -> void:
	_compact_layout = enabled
	custom_minimum_size = Vector2(278, 176) if enabled else Vector2(316, 198)
	icon_rect.custom_minimum_size = Vector2(24, 24) if enabled else Vector2(34, 34)
	close_button.custom_minimum_size = Vector2(30, 30) if enabled else Vector2(38, 38)
	var margin := $Margin as MarginContainer
	margin.add_theme_constant_override("margin_left", 7 if enabled else 10)
	margin.add_theme_constant_override("margin_top", 5 if enabled else 8)
	margin.add_theme_constant_override("margin_right", 7 if enabled else 10)
	margin.add_theme_constant_override("margin_bottom", 5 if enabled else 8)
	($Margin/Rows as VBoxContainer).add_theme_constant_override("separation", 3 if enabled else 6)
	($Margin/Rows/HeaderRow as HBoxContainer).add_theme_constant_override("separation", 4 if enabled else 6)
	items_rows.add_theme_constant_override("separation", 3 if enabled else 5)
	body_label.custom_minimum_size = Vector2(0, 16) if enabled else Vector2(0, 34)
	body_label.max_lines_visible = 1 if enabled else -1
	detail_label.max_lines_visible = 1 if enabled else -1
	items_scroll.custom_minimum_size = Vector2(0, 116) if enabled else Vector2(0, 96)
	if visible:
		_refresh_text()
func _refresh_text() -> void:
	close_button.text = ""
	close_button.tooltip_text = App.t_key("ui.action.close")
	var record := _content.panel_record(active_panel_id)
	title_label.text = App.t_key(str(record.get("title_key", "world.panel.inventory.title")))
	body_label.text = _content.panel_body(active_panel_id)
	detail_label.text = _content.panel_detail(active_panel_id)
	detail_label.visible = not detail_label.text.is_empty()
	icon_rect.texture = WorldHUDAssetsScript.load_ui_texture(str(record.get("icon_id", "icon.backpack")))
	_rebuild_rows(active_panel_id)

func _rebuild_rows(panel_id: String) -> void:
	for child in items_rows.get_children():
		child.queue_free()
	match panel_id:
		"shop":
			_render_shop_rows()
		"mail":
			_render_message_rows("mail", "messages", "world.panel.mail.empty")
		"notice":
			_render_message_rows("notice", "notices", "world.panel.notice.empty")
		"creator":
			CreatorContractRowsScript.new().render(items_rows, _compact_layout)
			_creator_draft_rows = CreatorDraftRowsScript.new()
			_creator_draft_rows.render(items_rows, _compact_layout)
			_creator_package_rows = CreatorPackageRowsScript.new()
			_creator_package_rows.render(items_rows, _compact_layout)
			CreatorReviewerRowsScript.new().render(items_rows, _compact_layout)
			CreatorStatusRowsScript.new().render(items_rows, _compact_layout)
		"map":
			MapDirectoryRowsScript.new().render(
				items_rows,
				_compact_layout,
				Callable(self, "_request_map_travel"),
				Callable(self, "_request_map_atlas")
			)
		"map_atlas":
			MapAtlasRowsScript.new().render(items_rows, _compact_layout, Callable(self, "_request_map_travel"))
		_:
			_render_inventory_rows()

func _render_shop_rows() -> void:
	var config := _utility_config()
	var shop: Dictionary = config.get("shop", {})
	var housing_config := ConfigLoader.load_config("housing_items")
	for offer in shop.get("items", []):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var offer_data := offer as Dictionary
		var item := _housing_item(housing_config, str(offer_data.get("item_id", "")))
		if item.is_empty():
			continue
		_add_row(
			_load_texture_path(str(item.get("icon_path", ""))),
			App.t_key(str(item.get("name_key", ""))),
			App.format_key("world.panel.shop.item_detail_format", {
				"description": App.t_key(str(item.get("description_key", ""))),
				"price": int(item.get("price", 0))
			}),
			str(offer_data.get("action_key", "")),
			str(offer_data.get("action_id", ""))
		)
	if items_rows.get_child_count() == 0:
		_add_row(WorldHUDAssetsScript.load_ui_texture("icon.shop"), App.t_key("world.panel.shop.empty"), "")

func _render_inventory_rows() -> void:
	WorldUtilityInventoryRowsScript.new().render(
		items_rows,
		_compact_layout,
		_online_inventory_items,
		_inventory_online_loaded
	)
	if items_rows.get_child_count() == 0:
		_add_row(WorldHUDAssetsScript.load_ui_texture("icon.backpack"), App.t_key("world.panel.inventory.empty"), "")

func _render_message_rows(section_id: String, list_key: String, empty_key: String) -> void:
	var config := _utility_config()
	var section: Dictionary = config.get(section_id, {})
	for record in section.get(list_key, []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var message := record as Dictionary
		var title := _message_title(message)
		_add_row(
			WorldHUDAssetsScript.load_ui_texture(str(message.get("icon_id", "icon.mail"))),
			title,
			App.t_key(str(message.get("body_key", ""))),
			str(message.get("action_key", "")),
			str(message.get("action_id", ""))
		)
	if items_rows.get_child_count() == 0:
		_add_row(icon_rect.texture, App.t_key(empty_key), "")

func _message_title(message: Dictionary) -> String:
	var subject := App.t_key(str(message.get("subject_key", "")))
	var sender_key := str(message.get("sender_key", ""))
	if sender_key.is_empty():
		return subject
	return App.format_key("world.panel.mail.row_title_format", {
		"sender": App.t_key(sender_key),
		"subject": subject
	})

func _add_row(
	texture: Texture2D,
	title: String,
	detail: String,
	action_key: String = "",
	action_id: String = ""
) -> void:
	var row := PanelListFrameScript.new().add_hbox(items_rows, _compact_layout)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26) if _compact_layout else Vector2(32, 32)
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	var title_label_row := Label.new()
	title_label_row.text = title
	title_label_row.modulate = PanelTextThemeScript.PRIMARY
	title_label_row.add_theme_font_size_override("font_size", 12 if _compact_layout else 16)
	title_label_row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label_row.clip_text = true
	labels.add_child(title_label_row)
	var detail_label_row := Label.new()
	detail_label_row.text = detail
	detail_label_row.modulate = PanelTextThemeScript.MUTED
	detail_label_row.add_theme_font_size_override("font_size", 8 if _compact_layout else 13)
	detail_label_row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label_row.clip_text = true
	labels.add_child(detail_label_row)

	if action_key.is_empty() or action_id.is_empty():
		return
	var action_button := Button.new()
	action_button.text = App.t_key(action_key)
	action_button.custom_minimum_size = Vector2(56, 26) if _compact_layout else Vector2(72, 32)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_button.add_theme_font_size_override("font_size", 12 if _compact_layout else 14)
	WorldHUDAssetsScript.configure_button_frame(action_button)
	var target_action := action_id
	action_button.pressed.connect(func() -> void:
		utility_action_requested.emit(target_action)
	)
	row.add_child(action_button)

func _request_map_travel(map_id: String) -> void:
	utility_action_requested.emit("map:%s" % map_id)

func _request_map_atlas() -> void:
	utility_action_requested.emit("map_atlas")

func _housing_item(config: Dictionary, item_id: String) -> Dictionary:
	for item in config.get("items", []):
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("id", "")) == item_id:
			return item as Dictionary
	return {}

func _load_texture_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	return null

func _utility_config() -> Dictionary:
	if not _remote_utility_config.is_empty():
		return _remote_utility_config.duplicate(true)
	return ConfigLoader.load_config("utility_panels")

func _refresh_remote_utility_config(panel_id: String) -> void:
	if not visible or active_panel_id != panel_id:
		return
	if not has_node("/root/OnlineClient"):
		return
	var client := get_node("/root/OnlineClient")
	if client == null or not bool(client.get("online_enabled")):
		return
	var response: Dictionary = await client.call("fetch_utility_panels")
	if not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	if data.is_empty() or not data.has("schema_version"):
		return
	_remote_utility_config = data
	if visible and active_panel_id == panel_id:
		_refresh_text()

func _refresh_online_inventory() -> void:
	if not visible or active_panel_id != "inventory":
		return
	if not has_node("/root/OnlineClient"):
		return
	var client := get_node("/root/OnlineClient")
	if client == null or not bool(client.get("online_enabled")) or not client.has_method("fetch_inventory"):
		return
	var response: Dictionary = await client.call("fetch_inventory")
	if not visible or active_panel_id != "inventory":
		return
	if not bool(response.get("ok", false)):
		return
	var data: Dictionary = response.get("data", {}) as Dictionary
	_online_inventory_items = data.get("items", []) as Array
	_inventory_online_loaded = true
	_refresh_text()

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_button_frame(close_button)
	close_button.icon = WorldHUDAssetsScript.load_ui_texture("icon.close")
	close_button.expand_icon = true
	close_button.custom_minimum_size = Vector2(38, 38)
	PanelTextThemeScript.apply_primary([title_label])
	PanelTextThemeScript.apply_muted([body_label, detail_label])

func _on_locale_changed(_locale: String) -> void:
	if visible:
		_refresh_text()
