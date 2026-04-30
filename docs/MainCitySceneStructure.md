# Main City Scene Structure

## Goal

The main city is the stable host for social play, chat, movement, housing entry, and minigame launches. It should stay lightweight because player-created minigames run in a sandbox scene.

## Current Scene

Current route:

- `main_city` -> `res://scenes/main_city/MainCity.tscn`
- Legacy `world` remains available for compatibility while the main city matures.

Current structure:

```text
MainCity (Node2D)
├── MapRoot (Node2D)
│   ├── TerrainPainter
│   ├── TownProps
│   ├── NPCRoot
│   ├── Entrances/HomeGateHotspot
│   └── InteractionPoints
│       ├── FishingPierHotspot
│       ├── GamesHallHotspot
│       └── ShopHotspot
├── PlayerRoot (Node2D)
│   ├── LocalPlayer
│   └── RemotePlayers
├── ServiceRoot (Node)
└── WorldHUD (CanvasLayer)
```

## Target MVP Structure

```text
MainCity (Node2D)
├── MapRoot (Node2D)
│   ├── GroundTiles (TileMapLayer)
│   ├── Collision (StaticBody2D)
│   ├── Entrances (Node2D)
│   └── InteractionPoints (Node2D)
├── PlayerRoot (Node2D)
│   ├── LocalPlayer (CharacterBody2D)
│   └── RemotePlayers (Node2D)
├── ServiceRoot (Node)
│   ├── ChatService
│   ├── HousingService
│   ├── MinigameRegistry
│   └── WorldStateSync
└── UI (CanvasLayer)
    ├── WorldHUD
    ├── MainCityNPCDialog
    ├── ChatDrawer
    └── InteractionPrompt
```

## Interface Points

- `InteractionPoints/FishingPierHotspot` launches `fishing`.
- `InteractionPoints/GamesHallHotspot` opens the online room/minigame panel.
- `InteractionPoints/ShopHotspot` emits a localized system chat notice until the shop loop exists.
- `Entrances/HomeGateHotspot` routes to `home_edit`.
- `TerrainPainter` instantiates Image 2 sliced PNG grass, dirt, stone, water, and decoration sprites as the current MVP map base while the final TileMapLayer is pending.
- `WorldHUD/ChannelPicker` selects the outgoing chat channel from `configs/chat_channels.json`.
- `WorldHUD/MainCityNPCDialog` opens compact NPC service menus without covering the center playfield.
- `NPCRoot` is populated from `configs/main_city_npcs.json`; NPCs use Image 2 sprites, localized names/dialogue, overhead emotes, and data-driven primary actions.
- Current NPC batch: fisher, merchant, mail courier, game host, home keeper, event guide.
- Minigames launch through `res://scenes/sandbox/MinigameSandbox.tscn`.

## Migration Rule

Keep the legacy `world` route until downstream docs/tests no longer reference it, but all new MVP social work should target `main_city`.
