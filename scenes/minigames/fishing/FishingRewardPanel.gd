extends PanelContainer

signal cast_again_requested

const WorldHUDAssetsScript := preload("res://scripts/UI/HUD/WorldHUDAssets.gd")

var _fish_name_key := ""
var _rarity_name_key := ""
var _rarity_color := Color(0.85, 0.79, 0.65)
var _coin_amount := 0

@onready var title_label: Label = %RewardTitleLabel
@onready var fish_icon: TextureRect = %RewardFishIcon
@onready var fish_label: Label = %RewardFishLabel
@onready var rarity_label: Label = %RewardRarityLabel
@onready var coin_label: Label = %RewardCoinLabel
@onready var hint_label: Label = %RewardHintLabel
@onready var cast_again_button: Button = %CastAgainButton
@onready var reward_margin: MarginContainer = $RewardMargin
@onready var reward_rows: VBoxContainer = $RewardMargin/RewardRows

func _ready() -> void:
	visible = false
	cast_again_button.pressed.connect(cast_again_requested.emit)
	App.locale_changed.connect(_on_locale_changed)
	_apply_image2_style()
	_refresh_text()

func show_reward(
	fish_name_key: String,
	coin_amount: int,
	icon_path: String,
	rarity_name_key: String,
	rarity_color: Color
) -> void:
	_fish_name_key = fish_name_key
	_rarity_name_key = rarity_name_key
	_rarity_color = rarity_color
	_coin_amount = coin_amount
	fish_icon.texture = _load_texture(icon_path)
	visible = true
	set_busy(false)
	_refresh_text()

func hide_reward() -> void:
	visible = false

func set_busy(is_busy: bool) -> void:
	cast_again_button.disabled = is_busy

func set_compact_layout(enabled: bool) -> void:
	custom_minimum_size = Vector2(0, 78) if enabled else Vector2(0, 108)
	fish_icon.custom_minimum_size = Vector2(40, 30) if enabled else Vector2(54, 40)
	cast_again_button.custom_minimum_size = Vector2(0, 28) if enabled else Vector2(0, 36)
	hint_label.visible = not enabled
	var margin := 6 if enabled else 10
	for key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		reward_margin.add_theme_constant_override(key, margin)
	reward_rows.add_theme_constant_override("separation", 1 if enabled else 4)

func _refresh_text() -> void:
	title_label.text = App.t_key("fishing.reward_title")
	fish_label.text = App.t_key(_fish_name_key) if not _fish_name_key.is_empty() else ""
	rarity_label.text = App.t_key(_rarity_name_key) if not _rarity_name_key.is_empty() else ""
	rarity_label.modulate = _rarity_color
	coin_label.text = App.format_key("fishing.reward_coin_format", {
		"coins": _coin_amount
	})
	hint_label.text = App.t_key("fishing.reward_hint")
	cast_again_button.text = App.t_key("fishing.cast_again_button")

func _apply_image2_style() -> void:
	WorldHUDAssetsScript.configure_panel_frame(self)
	WorldHUDAssetsScript.configure_button_frame(cast_again_button)
	title_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1.0))
	fish_label.add_theme_color_override("font_color", Color(0.24, 0.16, 0.09, 1.0))
	coin_label.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 1.0))
	hint_label.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 1.0))

func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource as Texture2D
	push_warning("Fishing reward icon failed to load: %s" % path)
	return null

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
