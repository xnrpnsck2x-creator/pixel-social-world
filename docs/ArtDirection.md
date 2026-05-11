# Art Direction

## Target Style

Warm forest town, cozy social MMO, retro 16-bit pixel UI. The attached reference image is the style target: dense but readable town layout, small avatar scale, warm wood panels, soft forest greens, compact UI windows, readable item icons, and expressive social emotes.

The emotional target is classic cute fantasy MMORPG energy: charming chibi avatars, busy town life, cozy shops, readable silhouettes, expressive emote bubbles, and ornate but compact UI. Assets must be original and should not copy any existing game's sprites, UI frames, logos, monster designs, or exact palette.

## Pixel Rules

- Tiles: 16x16.
- Characters and NPCs: MVP sprites with front, back, side, idle, walk, attack, and sit frames.
- UI icons: 16x16 and 32x32.
- Furniture: 16x16, 32x32, and 48x48 footprints.
- UI panels: 2px dark outer border, 1px warm highlight, NinePatch-ready.
- Emotes: 16x16 icons and 24x24 speech bubbles, readable at mobile scale.

## Palette

- Deep outline: `#263445`
- Moss green: `#4f7d45`
- Leaf highlight: `#83bf61`
- Warm panel: `#f0ddb7`
- Wood base: `#8a5a35`
- Coin gold: `#f0c85a`
- Accent red: `#e86a62`
- Water blue: `#2e7890`

## Image 2 Generation Batches

Use the built-in image generation path for previews. Project-bound assets must be copied into `assets/` before any scene or config references them.

Studio Mode rule: official UI and art production assets must be generated with Image 2. SVG files are not accepted as final UI, character, map, housing, or minigame art.

### UI Kit v0

```text
original pixel art UI kit for a cute fantasy forest-town social MMORPG, inspired by classic cozy 2000s MMO readability but not copying any existing game, warm moss green and wood palette, ornate compact 16-bit windows, 9-slice panels, buttons, tabs, chat bubble, input field, inventory slots, close button, coin badge, crisp edges, transparent/chroma-key background, no text, consistent scale
```

### Forest Town Tileset v0

```text
top-down pixel art forest town tileset, 16x16 seamless tiles, grass, dirt path, stone plaza, flower patches, wooden signs, trees, bushes, pond edge, cozy MMO town square, crisp edges, transparent/chroma-key background, no text
```

### Whole-Map Motherboard v1

```text
original top-down 2D pixel art whole-map background for a cozy fantasy forest social MMO, warm dawn forest town, circular stone plaza and fountain, guild hall, item shop, inn, mail hut, housing gate, minigame hall, wooden pier, market stalls, flower beds, lamps, benches, broad readable walking paths, dense but readable composition matching the approved forest-town reference board, small-avatar scale, no UI, no text, no labels, no logos, no watermark, game-ready map background
```

### Character and NPC Sheet v0

```text
original 32x32 chibi pixel art character sprites for a cute fantasy forest social world, classic MMORPG readability, front side back idle and walking frames, expressive face, readable silhouette, customizable hair and outfit colors, transparent/chroma-key background, sprite sheet, no text, do not copy any existing game character
```

### Player Action Sheet v0

```text
original chibi pixel art player avatar action sheet for a cute forest-town social MMORPG, readable early-2000s MMO motion structure without copying any existing game, idle walk attack sit, four directions, three walk frames, three attack frames, consistent character proportions, transparent/chroma-key background, no text, no logos
```

### Social Emotes v0

```text
original pixel art social emote sheet for a cute fantasy MMORPG, 16x16 icons and 24x24 speech bubbles, happy, heart, surprise, question, exclamation, sweat, sleep, music, coin, fishing bite, angry, thanks, crisp readable mobile scale, warm forest-town palette, transparent/chroma-key background, no text, do not copy any existing game icons
```

### Starter Housing v0

```text
pixel art cozy starter house assets, wooden cottage, wallpaper, wooden floor, simple chair, tiny table, potted plant, arcade cabinet, top-down/isometric-lite game asset style, crisp edges, transparent/chroma-key background, no text
```

### Fishing Minigame v0

```text
pixel art fishing minigame asset sheet, rod, bobber, pond fish, rare koi, pier sign, reward coin, timer badge, compact UI icons, cozy forest town palette, crisp edges, transparent/chroma-key background, no text
```

## Runtime Asset Contract

Runtime UI and art paths should point to Image 2 PNG/WebP assets. Former SVG placeholders have been removed from `assets/`; keep future prototypes outside runtime configs until generated art is approved.

## Generated Image 2 Assets

Current generated sheets:

- `assets/ui/generated/ui_kit_v0_alpha.png`
- `assets/ui/generated/overhead_emotes_v1_alpha.png`
- `assets/ui/generated/hud_icons_v0_alpha.png`
- `assets/maps/generated/forest_main_city_tileset_v0_alpha.png`
- `assets/sprites/generated/characters_npcs_v0_alpha.png`
- `assets/sprites/generated/player_adventurer_actions_v0_alpha.png`
- `assets/housing/generated/housing_fishing_props_v0_alpha.png`

Planned whole-map Image 2 motherboards are tracked in:

- `docs/MapProductionPlan.md`
- `docs/Image2MapPromptBook.md`
- `configs/map_catalog.json`
- `configs/map_points.json`
- Runtime map point contracts must include spawn points, NPC points, interaction points, portals, walkable rectangles, gathering zones, blocked rectangles, camera bounds, and QA gates before a map can move beyond `prompt_ready`.
- Playtest maps must bind those contracts to runtime movement validation before promotion; bitmap-only maps may remain prompt candidates but cannot become playable.

Source images are kept next to each alpha output with `_source.png` filenames for audit and re-processing.

Generated sheets must be sliced or packed into atlases before direct scene integration. Whole sheets remain registered as source assets.

Current sliced outputs:

- `assets/maps/sliced/forest_main_city_tileset_v0/` - 100 main city map props.
- `assets/maps/sliced/forest_main_city_tileset_v0_contact.png` - numbered map prop picker sheet.
- `assets/sprites/sliced/characters_npcs_v0/` - 38 character/NPC sprites.
- `assets/sprites/sliced/characters_npcs_v0_contact.png` - numbered NPC picker sheet.
- `assets/ui/sliced/ui_kit_v0/`
- `assets/ui/sliced/hud_icons_v0/`
- `assets/ui/sliced/overhead_emotes_v1/`
- `assets/housing/sliced/housing_fishing_props_v0/`

Main city hotspot bindings currently use:

- Fishing Pier: `forest_main_city_tileset_v0_071.png`
- Home Gate: `forest_main_city_tileset_v0_084.png`
- Games Hall: `forest_main_city_tileset_v0_098.png`
- Item Shop: `forest_main_city_tileset_v0_076.png`

First-screen plaza ambience currently uses:

- Central Fountain: `forest_main_city_tileset_v0_086.png`
- Notice Sign: `forest_main_city_tileset_v0_057.png`
- Flower Stand: `forest_main_city_tileset_v0_097.png`
- Town Lamp: `forest_main_city_tileset_v0_055.png`

Main city NPC bindings currently use:

- Fisher: `characters_npcs_v0_031.png`
- Merchant: `characters_npcs_v0_028.png`
- Mail Courier: `characters_npcs_v0_034.png`
- Game Host: `characters_npcs_v0_036.png`
- Home Keeper: `characters_npcs_v0_030.png`
- Event Guide: `characters_npcs_v0_029.png`

## Creator Asset Rules

- Keep each submitted theme at or below 32 colors.
- Use the same tile grid within one tileset.
- Avoid text baked into images; localization must handle readable labels.
- Official UI and art continue to follow the original Studio visual plan even as the platform architecture moves to `IMinigame`.
