# Creator Minigame Spec

## Purpose

This document is written for both human creators and AI tools generating Godot minigames for the platform.

The platform accepts small GDScript minigames that implement `IMinigame` and run inside `MinigameSandbox`.

Automated review is provider-agnostic. Local policy, LM Studio, cloud LLMs, or Codex-assisted manual review can all read the same package contract, but production review must not require an interactive OAuth browser login.

## Supported Mode Contracts

Every package chooses one `mode_id`. The same `IMinigame` interface is used for all modes; the mode only declares camera, input, player cap, networking, and review expectations.

MVP mode IDs:

- `casual_activity`: fishing, matching, rhythm taps, festival booths.
- `side_scroller_2d`: 2D pixel action stages with platforms, enemies, hazards, and bounded cameras.
- `2d_fighting`: side-view duels or small team fights with hitboxes, hurtboxes, input buffers, combo rules, and round timers.
- `strategy_war`: grid or isometric unit command games with deterministic turns or locked ticks.
- `rpg_adventure`: top-down quests, dialogue, light combat, and co-op room moments.
- `tower_defense`: wave defense with path grids, tower placement, upgrades, and reward pacing.
- `battle_royale`: elimination sessions with shrinking zones, light loot, spectator state, and server authority.

## Required Folder

```text
my_game/
├── main.tscn
├── game.gd
├── assets/
├── meta.json
└── README.md
```

## Required Script Base

`game.gd` must inherit:

```gdscript
extends "res://scripts/minigame/IMinigame.gd"
```

The root node of `main.tscn` must use `game.gd`.

## Required Methods

```gdscript
func get_game_id() -> String
func get_game_name() -> Dictionary
func get_version() -> String
func get_author() -> String
func on_start(context: Dictionary) -> void
func on_end() -> Dictionary
func on_pause() -> void
func on_resume() -> void
```

Optional multiplayer hooks:

```gdscript
func on_player_join(player_id: String) -> void
func on_player_leave(player_id: String) -> void
func on_sync_state() -> Dictionary
```

Optional social emote hook:

```gdscript
func request_emote(player_id: String, emote_id: String) -> void
```

Use this when a minigame wants to show platform-standard overhead emotes. Starter IDs include `emote.happy`, `emote.sad`, `emote.cry`, `emote.surprise`, `emote.heart`, `emote.question`, `emote.exclamation`, `emote.yes`, `emote.no`, and `emote.go`.

## `meta.json`

```json
{
  "game_id": "my_fishing_plus",
  "version": "1.0.0",
  "author": "player_uid_12345",
  "mode_id": "casual_activity",
  "name": {
    "en": "Super Fishing",
    "ja": "超釣り",
    "zh": "超级钓鱼"
  },
  "min_players": 1,
  "max_players": 4,
  "tags": ["casual", "fishing"],
  "requires_network": false,
  "runtime_contract": {
    "camera": "contained",
    "input_profile": "tap_timing",
    "network_profile": "offline_optional",
    "supports_emotes": true
  },
  "entry_scene": "res://creator/my_fishing_plus/main.tscn",
  "main_script": "res://creator/my_fishing_plus/game.gd",
  "asset_budget_bytes": 5242880
}
```

## Safety Rules

- Assets must be pixel-art PNG/WebP and total under 5 MB for MVP.
- SVG, native binaries, C#, shell scripts, and unmanaged plugins are not accepted as formal creator package files.
- The selected `mode_id` must exist in `configs/creator_game_modes.json`.
- `max_players` must not exceed the selected mode cap.
- Do not access nodes outside the minigame root.
- Do not call OS, filesystem, networking, or external API methods.
- Do not store secrets or tokens.
- Do not hardcode visible UI text; use metadata or localization keys where platform integration is needed.
- Keep the root scene self-contained and avoid autoload dependencies except the official context passed to `on_start`.

## Submission Intake V1

The first online intake path is `POST /creator-submissions/package`. It accepts the same manifest fields plus a `files` inventory containing `meta.json`, `main.tscn`, `game.gd`, and `README.md`.

The backend stores accepted uploads as package artifacts, records a review job as `submitted`, runs the package scanner and AI review adapter asynchronously, and exposes progress through `GET /creator-submissions/:id/status`. The scanner checks path safety, duplicate files, required files, script text, forbidden API patterns, blocked file types, and asset budget before the AI review adapter writes structured notes. Clean packages enter `needs_review`; failed scans or AI review blocks are stored as `rejected` so creators can see why the package failed.

`POST /creator-submissions/package.zip` accepts the same package as a multipart zip upload. A single top-level folder is allowed, but after extraction the package must still contain `meta.json`, `main.tscn`, `game.gd`, and `README.md` at the package root.

Text files should use `content_text`; binary assets should use `content_base64` when submitted through JSON tooling. Multipart zip intake fills binary asset content automatically. Approved packages become visible to runtime only after admin publish installs the package into the runtime catalog; raw artifact URIs must never be loaded by the client.

## AI Prompt Template

```text
Create a Godot 4 GDScript minigame package that follows this platform contract.
The root script must extend res://scripts/minigame/IMinigame.gd.
Implement all required metadata and lifecycle methods.
Keep the game self-contained, safe for SubViewport sandbox loading, and under 300 lines per file.
Use pixel-art-friendly UI and no external network, filesystem, OS, or system API calls.
Return score, rewards, and stats from on_end().
Use request_emote(player_id, emote_id) for platform-standard overhead emotes.
Also create a valid meta.json with en, ja, and zh names.
Choose one mode_id from casual_activity, side_scroller_2d, 2d_fighting, strategy_war, rpg_adventure, tower_defense, or battle_royale.
Include a runtime_contract object that matches the selected mode's camera, input, and network expectations.
```

## Official Example

See:

- `res://scenes/minigames/fishing/main.tscn`
- `res://scenes/minigames/fishing/game.gd`
- `res://scenes/minigames/fishing/meta.json`
