# UI Kit v0

## Direction

The baseline follows the user's reference board and the original Studio plan: cozy fantasy forest town, compact pixel windows, warm wood panels, moss green accents, readable chat/HUD controls, and expressive social emotes.

This is an original visual language inspired by classic cute fantasy MMO readability, not a copy of any existing game's UI or sprites.

Studio Mode rule: all final UI art must come from Image 2 generated PNG/WebP assets. SVGs are not accepted for production HUD, panel, icon, character, map, housing, or minigame UI.

## Current Contract Assets

Runtime configuration lives in:

- `configs/ui_assets.json`

Generated Image 2 sheets:

- `assets/ui/generated/ui_kit_v0_source.png`
- `assets/ui/generated/ui_kit_v0_alpha.png`
- `assets/ui/generated/overhead_emotes_v1_source.png`
- `assets/ui/generated/overhead_emotes_v1_alpha.png`
- `assets/ui/generated/hud_icons_v0_source.png`
- `assets/ui/generated/hud_icons_v0_alpha.png`

Former SVG placeholders have been removed from runtime paths. Use semantic Image 2 PNG bindings from `configs/ui_assets.json`.

## Image 2 Replacement Plan

Generated production PNG sheets now exist. Next step is cutting individual sprites and UI regions:

1. UI panel and button sheet: sliced and semantically bound.
2. HUD icon sheet: sliced and bound to primary HUD buttons.
3. Overhead emote sheet: generated, sliced, and bound to 30 expression IDs.
4. Inventory slot and item frame sheet: pending deeper inventory binding.
5. Minigame sandbox frame and reward badge sheet: fishing reward result panel is bound; deeper lobby/game-card binding is pending.

Each asset sheet should be exported into `assets/ui/` before scene references are changed.

## Slicing Rule

Do not wire the whole sheet directly to a button or panel. Use sliced PNGs or an atlas manifest generated from the Image 2 sheet.

Do not reference freshly sliced PNGs as scene `Texture2D` ext_resources before Godot has generated import metadata. Runtime UI binding should load semantic assets from `configs/ui_assets.json` with `ImageTexture`, then assign them to controls.

## Sliced Assets v0

`scripts/Tools/AssetSlicer/slice_generated_sheets.py` slices the Image 2 alpha sheets by connected alpha regions and writes:

- `assets/ui/sliced/ui_kit_v0/`
- `assets/ui/sliced/overhead_emotes_v1/`
- `assets/ui/sliced/hud_icons_v0/`
- `configs/generated_asset_slices.json`

Current counts:

- UI Kit: 61 slices
- Overhead Emotes: 30 slices
- HUD Icons: 40 slices

## Semantic Bindings v0

HUD icons selected from `hud_icons_v0_contact.png`:

- `ui.panel.pixel` -> `ui_kit_v0_013.png`
- `ui.button.pixel` -> `ui_kit_v0_033.png`

- `icon.chat` -> `hud_icons_v0_005.png`
- `icon.home` -> `hud_icons_v0_002.png`
- `icon.fishing` -> `hud_icons_v0_015.png`
- `icon.games` -> `hud_icons_v0_007.png`
- `icon.settings` -> `hud_icons_v0_008.png`
- `icon.backpack` -> `hud_icons_v0_001.png`
- `icon.friends` -> `hud_icons_v0_003.png`
- `icon.mail` -> `hud_icons_v0_004.png`
- `icon.map` -> `hud_icons_v0_018.png`
- `icon.coin` -> `hud_icons_v0_019.png`
- `icon.gift` -> `hud_icons_v0_020.png`
- `icon.shop` -> `hud_icons_v0_021.png`
- `icon.quest` -> `hud_icons_v0_022.png`
- `icon.shield` -> `hud_icons_v0_023.png`
- `icon.close` -> `hud_icons_v0_024.png`
- `icon.check` -> `hud_icons_v0_033.png`
- `icon.send` -> `hud_icons_v0_034.png`
- `icon.warning` -> `hud_icons_v0_035.png`
- `icon.heart` -> `hud_icons_v0_036.png`

`WorldHUDAssets` is the shared runtime skinning entry point for `ui.panel.pixel` and `ui.button.pixel`. It applies Image 2 `StyleBoxTexture` frames to HUD bars, the emote palette, chat input, channel picker, `OnlineRoomPanel`, `HousingRoomScreen`, `HousingRoomSocialPanel`, and `MainCityNPCDialog`. NPC primary action icons are configured per NPC through `configs/main_city_npcs.json`.

`WorldHUDAssets.create_panel()` and `WorldHUDAssets.add_margin_child()` should be used for new framed Godot UI surfaces before adding local panel helpers. This keeps shop, inventory, housing, and minigame lobby panels on the same Image 2 skin contract.

The official fishing reward panel also uses `WorldHUDAssets` for Image 2 panel/button frames. Fish reward icons are Image 2 slices from `housing_fishing_props_v0` and are mapped in `configs/fishing.json` plus semantically registered in `configs/art_assets.json`.

Housing room art uses the same `housing_fishing_props_v0` Image 2 slice set. `configs/housing_items.json` owns gameplay catalog data and `configs/art_assets.json` owns semantic `housing.item.*.icon` registrations. `HousingRoomArt` is the runtime drawing helper for wall/floor surfaces, catalog icons, placed furniture sprites, and placement previews.

Emotes selected from `overhead_emotes_v1_contact.png`:

- `emote.exclamation` -> `overhead_emotes_v1_001.png`
- `emote.question` -> `overhead_emotes_v1_002.png`
- `emote.music` -> `overhead_emotes_v1_003.png`
- `emote.heart` -> `overhead_emotes_v1_004.png`
- `emote.big_heart` -> `overhead_emotes_v1_005.png`
- `emote.sweat` -> `overhead_emotes_v1_006.png`
- `emote.idea` -> `overhead_emotes_v1_007.png`
- `emote.angry` -> `overhead_emotes_v1_008.png`
- `emote.gloom` -> `overhead_emotes_v1_009.png`
- `emote.coin` -> `overhead_emotes_v1_010.png`
- `emote.thanks` -> `overhead_emotes_v1_011.png`
- `emote.silence` -> `overhead_emotes_v1_012.png`
- `emote.nervous_sweat` -> `overhead_emotes_v1_013.png`
- `emote.sad` -> `overhead_emotes_v1_014.png`
- `emote.sorry` -> `overhead_emotes_v1_015.png`
- `emote.laugh` -> `overhead_emotes_v1_016.png`
- `emote.happy` -> `overhead_emotes_v1_016.png` compatibility alias
- `emote.confused` -> `overhead_emotes_v1_017.png`
- `emote.thumbs_up` -> `overhead_emotes_v1_018.png`
- `emote.search` -> `overhead_emotes_v1_019.png`
- `emote.surprise` -> `overhead_emotes_v1_020.png`
- `emote.no` -> `overhead_emotes_v1_021.png`
- `emote.help` -> `overhead_emotes_v1_022.png`
- `emote.yes` -> `overhead_emotes_v1_023.png`
- `emote.go` -> `overhead_emotes_v1_024.png`
- `emote.cry` -> `overhead_emotes_v1_025.png`
- `emote.sly` -> `overhead_emotes_v1_026.png`
- `emote.kiss` -> `overhead_emotes_v1_027.png`
- `emote.pat` -> `overhead_emotes_v1_028.png`
- `emote.puff` -> `overhead_emotes_v1_029.png`
- `emote.nod` -> `overhead_emotes_v1_030.png`
- `emote.fishing_bite` -> `overhead_emotes_v1_001.png`

## Overhead Emote Rule

Emotes should appear above the avatar's head as a short bubble animation. Use `OverheadEmoteBubble.play(emote_id)` or `PlayerAvatar.show_emote(emote_id)` instead of sending emotes as plain chat text.

HUD palette order and tooltip localization are configured in `configs/emotes.json`.

Minigames should use the inherited `IMinigame.request_emote(player_id, emote_id)` hook when they want to trigger platform-standard emotes.
