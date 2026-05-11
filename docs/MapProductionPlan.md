# Map Production Plan

## Goal

Replace the temporary-feeling main city layout with a coherent Image 2 generated map system. The visual target is the approved reference board: warm forest town, compact social MMO density, clear plaza roads, readable buildings, cozy pixel props, small characters, overhead emotes, and vintage UI harmony.

## Non-Negotiables

- Official map art must be generated with Image 2 and stored under `assets/maps/` before runtime use.
- SVG and hand-drawn placeholder maps are not valid production map assets.
- Whole-map Image 2 outputs are allowed for MVP backgrounds, but gameplay metadata must stay structured in JSON.
- No text, labels, logos, or UI may be baked into map images.
- Every map must reserve clear walking lanes, gathering space, spawn points, NPC points, portals, camera bounds, and life-skill nodes.
- Godot collision and interaction data must be authored separately from the bitmap.

## Production Layers

### 1. Layout Contract

Each map starts as a contract before image generation:

- `map_id`
- category and MVP priority
- intended player flow
- plaza or gathering area
- roads and chokepoints
- NPC, portal, and life-skill placements
- camera zoom target
- mobile HUD-safe areas

### 2. Image 2 Motherboard

Image 2 generates a whole-map visual motherboard from the contract. This establishes:

- composition
- color harmony
- prop density
- building silhouette language
- biome identity
- mood and lighting

### 3. Runtime Metadata

Godot receives the map as:

- one background image for MVP, later atlas/tile slices when needed
- runtime movement validation generated from the map metadata
- collision polygons or blocked rectangles
- walkable rectangles
- gathering zones with expected capacity
- spawn points
- hotspots
- NPC anchor points
- life-skill nodes
- portal targets
- camera bounds
- camera regions keyed by spawn ids for indoor, square, or irregular-feeling maps
- QA gates for HUD-safe viewports and avatar-width road checks

## MVP Integration Path

1. Generate 4-5 candidate main-city motherboards with Image 2.
2. Select 1 as the new main city base after a quick H5 screenshot pass.
3. Store source and processed output:
   - `assets/maps/generated/city_forest_dawn_v1_source.png`
   - `assets/maps/generated/city_forest_dawn_v1.webp`
4. Register the selected asset in `configs/art_assets.json`.
5. Register gameplay metadata in `configs/map_catalog.json` and `configs/map_points.json`.
6. Replace the temporary main city background while keeping existing HUD, player, emotes, chat, room, and minigame routing intact.
7. Run H5 screenshot QA at 960x540, 375x240, desktop world view, and `node tests/h5_map_patrol.mjs` for the generated map batch.

## First 32 Map Batch

The first batch is not 32 shipped maps. It is 32 Image 2 layout motherboards. The selection funnel is:

- 32 prompt-ready concepts
- 8 art-director selects
- 4 playable MVP candidates
- 1 replacement main city

## Current Main-City Decision

- Candidate A remains the art-density reference.
- Candidate D remains the road-structure reference.
- Candidate E is the active playtest background because it combines a planned town layout, cleaner functional entrances, and stronger cozy forest density.
- `configs/map_points.json` is now the source of truth for main-city spawn, NPC, interaction, portal, walkable, gathering, and blocked areas.
- `MainCityMapMetadata.gd` projects image-pixel points into Godot world coordinates, so future map swaps should update metadata first and scene nodes second only when new hotspot types are introduced.
- `PlayerAvatar` asks the active map metadata before accepting local movement, which prevents walking outside the generated map canvas or into blocked buildings without baking collision into the bitmap.
- `MainCityMapRuntime.gd` now swaps Image 2 backgrounds, map metadata, player spawn, NPC anchors, hotspot visibility, HUD title, and camera zoom as one runtime contract.
- `camera_regions` now let each map bind camera limits by spawn id, so future interiors and square Image 2 maps do not expose empty canvas edges while reusing the same runtime.

## First-Batch Generated Maps

- Port Market: second-main-city motherboard candidate, reachable from the Forest Dawn shop route.
- Fishing Riverbend: playtest map for the fishing life-skill loop.
- Housing District: playtest map for home access and neighborhood social flow.
- Minigame Arcade Hall: playtest map for minigame lobby access.
- Spring Workshop Town: crafting and upgrade-economy hub candidate.
- Crystal Mine: first mining loop candidate.
- Trade Market: social economy motherboard candidate; route exposure is held until trade UI contracts land.
- Guild Garden: guild/social retention motherboard candidate.

## Categories

### Main Cities

- 森林晨曦镇 / Forest Dawn Town
- 港口市场 / Port Market
- 山泉工坊镇 / Spring Workshop Town
- 雪境村 / Snowbell Village
- 学园广场 / Academy Plaza
- 节庆夜市 / Festival Night Market

### Life-Skill Maps

- 钓鱼河湾 / Fishing Riverbend
- 矿洞 / Crystal Mine
- 采药林 / Herb Forest
- 伐木场 / Lumber Grove
- 农场 / Starter Farm
- 昆虫草地 / Insect Meadow
- 遗迹考古 / Ruin Dig Site
- 料理集市 / Cooking Market

### Random Exploration Maps

- 花谷 / Flower Valley
- 湿地 / Mist Wetland
- 废墟 / Old Ruins
- 秋林路 / Autumn Road
- 海岛岸边 / Island Coast
- 夜灯森林 / Lantern Forest
- 山崖栈道 / Cliff Boardwalk
- 古树迷宫 / Ancient Tree Maze

### Social Function Maps

- 公会区 / Guild Garden
- 房屋街区 / Housing District
- 小游戏大厅 / Minigame Arcade Hall
- 交易集市 / Trade Market
- 邮件广场 / Mail Plaza
- 创作者展厅 / Creator Gallery

### Seasonal Maps

- 樱花节 / Cherry Blossom Fair
- 雪祭 / Snow Festival
- 夏夜烟火 / Summer Fireworks Pier
- 万圣灯会 / Pumpkin Lantern Square

## QA Gate

A map is not usable until it passes:

- Main road supports at least 3 avatars side by side.
- Central gathering area supports 20 avatars without visual clutter.
- Player scale reads clearly at the shared `camera_zoom` target of 0.88, with 0.85-1.25 as the allowed whole-map range. Square social maps may use `1.0` when needed to avoid edge exposure.
- Runtime movement rejects points outside the map canvas and inside `blocked_rects`.
- H5 map patrol screenshot pass rejects obvious bottom-edge fallback bands or dark void exposure.
- Overhead emotes fit above characters without blocking key roads.
- HUD does not cover the default spawn or primary interaction point at 960x540.
- 375x240 emergency viewport still shows a clear player location.
- Portal locations are visually obvious but not labeled in the art.
- No baked text.
- No copied recognizable third-party designs.

## Risk Controls

- Avoid over-detailed maps that look good in isolation but fail pathing.
- Keep Image 2 outputs original and style-aligned, not copied from any existing game.
- Keep collision outside the image so later balance changes do not require regenerating art.
- Promote maps gradually; do not replace every map system at once.

## Batch 2 Integration Target

Batch 2 should fill the biggest MVP world-loop gaps before decorative variety:

- Spring Workshop Town: crafting and future upgrade economy hub.
- Crystal Mine: first mining loop and ore reward source.
- Trade Market: social economy and player-to-player trading lobby.
- Guild Garden: guild/social retention space and group-photo hub.

All four must use Image 2 motherboards, register final PNG/WebP assets under `assets/maps/generated/`, then receive `map_points` metadata before runtime exposure. Do not expose a route from Forest Dawn until the map passes content validation and `node tests/h5_map_patrol.mjs`.

Current Batch 2 status:

- Spring Workshop Town: Image 2 PNG registered, `playtest_metadata` authored, H5 map patrol included.
- Crystal Mine: Image 2 PNG registered, `playtest_metadata` authored, H5 map patrol included.
- Trade Market: Image 2 PNG registered, `playtest_metadata` authored, H5 map patrol included. The market board is metadata-only for now; do not bind it to the existing shop route because the current shop action still owns the Port Market travel path.
- Guild Garden: first generated pass was rejected because it included character-like baked figures; the clean regenerated Image 2 PNG is registered, `playtest_metadata` authored, H5 map patrol included.

Route exposure update:

- Spring Workshop Town is now reachable from Forest Dawn via the workshop hotspot and can return through the shared city portal.
- Crystal Mine is now reachable from Forest Dawn via the mine hotspot and can return through the shared city portal.
- Both maps keep gameplay nodes as status-only hooks until crafting/mining reward services land.

## Batch 3 Main-City Queue

Batch 3 completes the six-main-city foundation before the remaining life-skill, random exploration, social, and seasonal maps expand outward.

Source of truth:

- `configs/map_generation_queue.json`

Current active batch:

- `main_city_batch_3` is complete.
- `seasonal_activity_batch_9` is the latest completed Image2 batch in `configs/map_generation_queue.json`.

Generation order:

Completed:

- Snowbell Village: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Academy Plaza: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Festival Night Market: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Pending:

- None. Six main-city motherboards are now generated and registered.

Tooling:

```bash
python3 scripts/Tools/MapPipeline/print_image2_queue.py --batch main_city_batch_3
```

After Image 2 selection, use the printed registration command, then replace scaffold metadata with authored `map_points` before route exposure.

Batch 3 gates:

- The catalog entry must stay `prompt_ready` until Image2 art is actually registered.
- The queue prompt must forbid baked text, UI, foreground characters, logos, and copied map designs.
- Each queued map must include render size, target camera zoom, output/source paths, integration plan, portal plan, HUD-safe viewports, and required metadata sections.
- `tests/map_generation_queue_smoke.py` must pass before generating or registering assets.

## Batch 4 Life-Skill Intake

Batch 4 moves the life-skill foundation beyond fishing and mining by adding gathering, woodcutting, and farming spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Herb Forest: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Lumber Grove: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Starter Farm: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- All three maps currently expose metadata hooks for future economy-backed life-skill actions; reward services are not wired yet.
- All three maps return to `city_forest_dawn_v1` and keep the first-session guide hidden while outside the starter city.

## Batch 5 Life-Skill Completion

Batch 5 completes the MVP life-skill map foundation by adding the remaining insect catching, archaeology, and cooking spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Insect Meadow: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Ruin Dig Site: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Cooking Market: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- MVP life-skill map foundation is now 8/8: fishing, mining, herb gathering, woodcutting, farming, insect catching, archaeology, and cooking.
- All three Batch 5 maps currently expose metadata hooks for future economy-backed life-skill actions; reward services are not wired yet.
- All three Batch 5 maps return to `city_forest_dawn_v1` and keep starter-only guide copy hidden outside the starter city.

## Batch 6 Social-Function Completion

Batch 6 completes the MVP social-function map foundation by adding the remaining mail and creator-gallery spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Mail Plaza: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Creator Gallery: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- MVP social-function map foundation is now 6/6: guild, housing, minigame hall, trade market, mail plaza, and creator gallery.
- Mail Plaza currently opens the local messages/mail panel; persistent private-mail backend remains a later social backend task.
- Creator Gallery currently opens the creator utility panel and uses the creator submission/review contracts already present in the client.

## Batch 7 Random-Exploration Intake

Batch 7 starts the random-exploration foundation by adding the first four non-town exploration spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Flower Valley: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Mist Wetland: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Old Ruins: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Autumn Road: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- Random exploration foundation is now 4/8: flower valley, mist wetland, old ruins, and autumn road.
- These maps use `life_skill_nodes` as temporary exploration hooks with `action: "explore"` until the dedicated exploration reward/service contract lands.
- All four Batch 7 maps return to `city_forest_dawn_v1` and keep starter-only guide copy hidden outside the starter city.

## Batch 8 Random-Exploration Completion

Batch 8 completes the MVP random-exploration foundation by adding the remaining island, lantern forest, cliff boardwalk, and ancient tree maze spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Island Coast: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Lantern Forest: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Cliff Boardwalk: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Ancient Tree Maze: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- Random exploration foundation is now 8/8: flower valley, mist wetland, old ruins, autumn road, island coast, lantern forest, cliff boardwalk, and ancient tree maze.
- All eight random-exploration maps use `life_skill_nodes` as temporary exploration hooks with `action: "explore"` until the dedicated exploration reward/service contract lands.
- All four Batch 8 maps return to `city_forest_dawn_v1` and keep starter-only guide copy hidden outside the starter city.

## Batch 9 Seasonal-Activity Completion

Batch 9 completes the MVP 32-map motherboard foundation by adding the seasonal/activity spaces as a single validated map set.

Source of truth:

- `configs/map_generation_queue.json`

Completed:

- Cherry Blossom Fair: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Snow Festival: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Summer Fireworks Pier: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.
- Pumpkin Lantern Square: Image2 PNG registered, source PNG preserved, `playtest_metadata` authored, desktop/mobile H5 screenshot pass complete.

Runtime notes:

- First 32 Image2 map motherboards are now 32/32 generated, registered, metadata-authored, and route-ready.
- Seasonal maps currently expose `seasonal_event` interaction hooks; event calendar, reward claims, and temporary shop rotations remain the next gameplayization layer.
- All four Batch 9 maps return to `city_forest_dawn_v1` and keep starter-only guide copy hidden outside the starter city.
