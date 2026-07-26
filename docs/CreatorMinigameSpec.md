# Creator Minigame Spec

## Purpose

This document is written for both human creators and AI tools generating Godot minigames for the platform.

The platform has one public creator path and one reserved internal contract:

- Manifest V2 declarative packages are the automatic integration path. They
  contain data and approved asset references, but no executable GDScript.
- `IMinigame` code packages are reserved for platform-owned releases. Public
  endpoints do not accept them. A future trusted-publisher path must add
  cryptographic signature and publisher authorization checks before it can be
  enabled.

`SubViewport` isolates rendering and lifecycle only. It is not a security
sandbox, so the client must never automatically load player-supplied scripts.

Automated review is provider-agnostic. Local policy, LM Studio, cloud LLMs, or Codex-assisted manual review can all read the same package contract, but production review must not require an interactive OAuth browser login.

## Supported Mode Contracts

Every package chooses one `mode_id`. The same `IMinigame` interface is used for all modes; the mode only declares camera, input, player cap, networking, and review expectations.

The registry is intentionally broader than the MVP public runtime. Only
`casual_activity` currently has `public_runtime_enabled: true`; its automatic
runtime is the bounded `tap_timing` interpreter. The remaining contracts are
reserved for future signed or server-authoritative implementations and cannot
be selected, uploaded, published, hosted, or launched through the public
automatic path yet.

MVP mode IDs:

| mode_id | camera | input_profile | network_profile | Public auto runtime | Use |
| --- | --- | --- | --- | --- | --- |
| `casual_activity` | `contained` | `tap_timing` | `offline_optional` | Yes | fishing, matching, rhythm taps, festival booths |
| `side_scroller_2d` | `side_view` | `action_platformer` | `session_sync` | No | future pixel action stages with bounded cameras |
| `2d_fighting` | `side_view` | `fighting_action` | `authoritative_realtime` | No | future server-authoritative duels or small team fights |
| `strategy_war` | `isometric` | `strategy_pointer` | `turn_or_lockstep` | No | future deterministic turn or locked-tick games |
| `rpg_adventure` | `top_down` | `rpg_move_confirm` | `session_sync` | No | future top-down quests and co-op room moments |
| `tower_defense` | `lane_grid` | `tower_place_upgrade` | `session_sync` | No | future wave defense with bounded path grids |
| `battle_royale` | `top_down` | `survival_action` | `authoritative_realtime` | No | future authoritative elimination sessions |

The backend and client validator reject packages where `runtime_contract` does
not match the chosen `mode_id`.

## Automatic Package: Manifest V2

Creators and AI tools discover stable entries through:

- `GET /creator-registry`
- `GET /creator-registry/:id`
- `POST /creator-discovery/keywords`
- `POST /creator-manifests/resolve`

The server resolves keyword, capability, interface, and official asset-pack
references against `configs/creator_registry.json`. A successful resolution
adds dependency capabilities, narrows permissions to the selected mode, locks
official asset SHA-256 values, and returns `resolved_manifest.lock_digest`.

Automatic packages contain:

```text
my_game/
├── meta.json
├── creator_manifest.json
├── content/
│   └── game.json
└── README.md
```

`creator_manifest.json` must exactly match the server-resolved manifest sent in
the upload request. `content/game.json` must use schema version 1 and repeat the
same `game_id` and `mode_id`. The backend bounds its size, nesting depth, and
structural complexity. `.gd`, `.tscn`, `.tres`, `.res`, and `.gdshader` files
are rejected on this path.

The MVP public definition shape is:

```json
{
  "schema_version": 1,
  "game_id": "my_river_timing",
  "mode_id": "casual_activity",
  "type": "tap_timing",
  "settings": {
    "duration_seconds": 60,
    "target_score": 12
  }
}
```

## Reserved Internal Code Package

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
  "entry_scene": "",
  "main_script": "",
  "asset_budget_bytes": 5242880
}
```

## Safety Rules

- Assets must be pixel-art PNG/WebP and total under 5 MB for MVP.
- SVG, native binaries, C#, shell scripts, and unmanaged plugins are not accepted as formal creator package files.
- The selected `mode_id` must exist in `configs/creator_game_modes.json`.
- Public automatic packages require `public_runtime_enabled: true`; for MVP
  that means `casual_activity` with a `tap_timing` definition.
- `max_players` must not exceed the selected mode cap.
- Do not store secrets or tokens.
- Do not hardcode visible UI text; use metadata or localization keys where platform integration is needed.
- Public packages must contain declarative JSON only; executable Godot files are rejected even if their source appears harmless.

## Submission Intake

The online intake path is `POST /creator-submissions/package`. It requires the
server-issued `resolved_manifest` plus `meta.json`, `creator_manifest.json`,
the resolved declarative entry JSON, and `README.md`.

The backend stores accepted uploads as package artifacts, records a review job
as `submitted`, runs the package scanner and AI review adapter asynchronously,
and exposes progress through `GET /creator-submissions/:id/status`. Review work
uses 4 fixed workers and a 128-job bounded queue. The scanner derives byte
counts and SHA-256 values from the received content instead of trusting client
declarations.

Clean packages enter `needs_review`; failed scans or AI review blocks are
stored as `rejected` so creators can see why the package failed. A `game_id` is
owned by its first creator, and content for an existing `game_id` plus
`version` is immutable.

Human approval is accepted only after the automated review job is complete and
its policy result approves the package. Published installs are addressed by
`game_id/version/source_sha256`; rollback changes only the current pointer and
never rewrites historical package files.

`POST /creator-submissions/package.zip` accepts the same package as a multipart zip upload. A single top-level folder is allowed, but after extraction the package must still contain `meta.json`, `creator_manifest.json`, the resolved declarative entry JSON, and `README.md`.

Text files should use `content_text`; binary assets should use
`content_base64` when submitted through JSON tooling. Multipart zip intake
fills binary asset content automatically. Approved packages become visible to
runtime only after scan completion, AI approval, human approval, and admin
publish. Raw artifact URIs must never be loaded by the client.

The player client discovers published entries through
`GET /minigames/catalog`, then fetches one revalidated declarative payload from
`GET /minigames/:id/runtime`. The catalog contains no server filesystem paths
or artifact keys. The generic Godot runtime interprets bounded JSON settings;
it never downloads or executes creator GDScript, scenes, resources, shaders, or
native code. Client results do not grant coins or items directly. Session
creation and joining revalidate the same current catalog; unpublishing removes
the game from player selection, hides existing sessions, and makes later joins
fail with `410 game_unavailable`.

## AI Prompt Template

```text
Create a Manifest V2 declarative minigame package for this platform.
First choose registry keyword and capability IDs, then request a resolved manifest.
Generate strict meta.json with en, ja, and zh names.
Generate creator_manifest.json exactly from the server response.
Generate the resolved declarative entry JSON with schema_version, game_id, and mode_id.
Do not generate GDScript, scenes, resources, shaders, plugins, native files, or network/system calls.
For the MVP public path choose mode_id casual_activity only.
Use type tap_timing and include a contained/tap_timing/offline_optional runtime_contract.
Treat side_scroller_2d, 2d_fighting, strategy_war, rpg_adventure, tower_defense, and battle_royale as reserved contracts, not publishable public runtimes.
```

## Official Example

See:

- `res://scenes/minigames/fishing/main.tscn`
- `res://scenes/minigames/fishing/game.gd`
- `res://scenes/minigames/fishing/meta.json`
