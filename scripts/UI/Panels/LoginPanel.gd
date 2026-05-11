class_name LoginPanel
extends PanelContainer

signal login_requested(display_name: String, character: Dictionary)

const CHARACTER_CONFIG := "player_animations"

@onready var title_label: Label = %TitleLabel
@onready var name_input: LineEdit = %NameInput
@onready var character_label: Label = %CharacterLabel
@onready var gender_picker: OptionButton = %GenderPicker
@onready var class_picker: OptionButton = %ClassPicker
@onready var play_button: Button = %PlayButton
@onready var character_preview_panel: PanelContainer = get_node_or_null("%CharacterPreviewPanel") as PanelContainer
@onready var avatar_preview: TextureRect = get_node_or_null("%AvatarPreview") as TextureRect
@onready var variant_name_label: Label = get_node_or_null("%VariantNameLabel") as Label
@onready var class_range_label: Label = get_node_or_null("%ClassRangeLabel") as Label
@onready var class_description_label: Label = get_node_or_null("%ClassDescriptionLabel") as Label

var _character_config := {}
var _preview_frames: Array[Texture2D] = []
var _preview_frame_index := 0
var _preview_elapsed := 0.0

func _ready() -> void:
	_character_config = ConfigLoader.load_config(CHARACTER_CONFIG)
	play_button.pressed.connect(_on_play_pressed)
	name_input.text_submitted.connect(func(_text: String) -> void: _on_play_pressed())
	name_input.gui_input.connect(_on_name_input_gui_input)
	gender_picker.item_selected.connect(_on_character_picker_changed)
	class_picker.item_selected.connect(_on_character_picker_changed)
	App.locale_changed.connect(_on_locale_changed)
	set_process(false)
	_refresh_text()

func _process(delta: float) -> void:
	if _preview_frames.size() <= 1 or avatar_preview == null:
		set_process(false)
		return
	_preview_elapsed += delta
	if _preview_elapsed < 0.18:
		return
	_preview_elapsed = 0.0
	_preview_frame_index = (_preview_frame_index + 1) % _preview_frames.size()
	avatar_preview.texture = _preview_frames[_preview_frame_index]

func _unhandled_key_input(event: InputEvent) -> void:
	if not name_input.has_focus() or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_on_play_pressed()

func _on_name_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		name_input.accept_event()
		_on_play_pressed()

func _on_play_pressed() -> void:
	var display_name: String = name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = App.t_key("login.default_name")
	_release_mobile_keyboard()
	login_requested.emit(display_name, _selected_character())

func _release_mobile_keyboard() -> void:
	if OS.get_name() not in ["Android", "iOS"]:
		return
	name_input.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()

func _on_character_picker_changed(_index: int) -> void:
	SaveSystem.set_profile_value("gender_id", _picker_id(gender_picker, "male"))
	SaveSystem.set_profile_value("class_id", _picker_id(class_picker, "melee"))
	_refresh_character_preview()

func _refresh_text() -> void:
	title_label.text = App.t_key("login.title")
	name_input.placeholder_text = App.t_key("login.name_placeholder")
	character_label.text = App.t_key("login.character_label")
	_refresh_picker(gender_picker, _character_config.get("genders", []), "male")
	_refresh_picker(class_picker, _character_config.get("classes", []), "melee")
	play_button.text = App.t_key("login.play_button")
	_refresh_character_preview()

func _refresh_picker(picker: OptionButton, records: Array, fallback_id: String) -> void:
	var profile_key := str(picker.name).to_snake_case().replace("_picker", "_id")
	var selected_id := _picker_id(picker, str(SaveSystem.get_profile_value(profile_key, fallback_id)))
	picker.clear()
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data := record as Dictionary
		picker.add_item(App.t_key(str(data.get("name_key", ""))))
		picker.set_item_metadata(picker.item_count - 1, str(data.get("id", "")))
	_select_picker_id(picker, selected_id)

func _selected_character() -> Dictionary:
	var gender_id := _picker_id(gender_picker, "male")
	var class_id := _picker_id(class_picker, "melee")
	var variant := _variant_for(gender_id, class_id)
	return {
		"gender_id": gender_id,
		"class_id": class_id,
		"avatar_id": str(variant.get("avatar_id", _character_config.get("default_avatar", ""))),
		"character_variant_id": str(variant.get("id", _character_config.get("default_character_variant", "")))
	}

func _variant_for(gender_id: String, class_id: String) -> Dictionary:
	for variant in _character_config.get("character_variants", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var data := variant as Dictionary
		if str(data.get("gender_id", "")) == gender_id and str(data.get("class_id", "")) == class_id:
			return data
	return {}

func _refresh_character_preview() -> void:
	var gender_id := _picker_id(gender_picker, "male")
	var class_id := _picker_id(class_picker, "melee")
	var variant := _variant_for(gender_id, class_id)
	var avatar := _avatar_for_id(str(variant.get("avatar_id", "")))
	var class_record := _class_for_id(class_id)
	var compact := _screen_width() < 960.0
	_apply_preview_layout(compact)
	if variant_name_label != null:
		variant_name_label.text = App.t_key(str(variant.get("name_key", "")))
	if class_range_label != null:
		class_range_label.text = App.t_key("character.range.%s" % str(class_record.get("range", "")))
	if class_description_label != null:
		class_description_label.visible = not compact
		class_description_label.text = App.t_key(str(class_record.get("description_key", "")))
	_load_preview_frames(avatar)

func _load_preview_frames(avatar: Dictionary) -> void:
	_preview_frames.clear()
	_preview_frame_index = 0
	_preview_elapsed = 0.0
	var animation: Dictionary = (avatar.get("animations", {}) as Dictionary).get("walk_down", {}) as Dictionary
	for frame_path in animation.get("frames", []):
		var texture := ResourceLoader.load(str(frame_path))
		if texture is Texture2D:
			_preview_frames.append(texture as Texture2D)
	if _preview_frames.is_empty():
		var idle: Dictionary = (avatar.get("animations", {}) as Dictionary).get("idle_down", {}) as Dictionary
		for frame_path in idle.get("frames", []):
			var texture := ResourceLoader.load(str(frame_path))
			if texture is Texture2D:
				_preview_frames.append(texture as Texture2D)
	if avatar_preview != null:
		avatar_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		avatar_preview.texture = _preview_frames[0] if not _preview_frames.is_empty() else null
	set_process(_preview_frames.size() > 1)

func _avatar_for_id(avatar_id: String) -> Dictionary:
	for avatar in _character_config.get("avatars", []):
		if typeof(avatar) != TYPE_DICTIONARY:
			continue
		var data := avatar as Dictionary
		if str(data.get("id", "")) == avatar_id:
			return data
	return {}

func _class_for_id(class_id: String) -> Dictionary:
	for record in _character_config.get("classes", []):
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data := record as Dictionary
		if str(data.get("id", "")) == class_id:
			return data
	return {}

func _apply_preview_layout(compact: bool) -> void:
	if character_preview_panel != null:
		character_preview_panel.offset_top = -104.0 if compact else -132.0
		character_preview_panel.offset_bottom = 104.0 if compact else 132.0
	if avatar_preview != null:
		avatar_preview.custom_minimum_size = Vector2(96, 96) if compact else Vector2(112, 112)

func _screen_width() -> float:
	var browser_width := _browser_inner_width()
	if browser_width > 0.0:
		return browser_width
	if get_viewport() == null:
		return 960.0
	return get_viewport_rect().size.x

func _browser_inner_width() -> float:
	if not Engine.has_singleton("JavaScriptBridge"):
		return 0.0
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if bridge == null or not bridge.has_method("eval"):
		return 0.0
	var width_value: Variant = bridge.call("eval", "window.innerWidth", true)
	if typeof(width_value) == TYPE_INT or typeof(width_value) == TYPE_FLOAT:
		return float(width_value)
	return 0.0

func _picker_id(picker: OptionButton, fallback_id: String) -> String:
	if picker.item_count == 0 or picker.selected < 0:
		return fallback_id
	return str(picker.get_item_metadata(picker.selected))

func _select_picker_id(picker: OptionButton, selected_id: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == selected_id:
			picker.select(index)
			return
	if picker.item_count > 0:
		picker.select(0)
