# Architecture

## MVP Shape

This project is a 2D pixel online social world with three Day 1 pillars:

- World: a shared town scene where players can spawn, move, chat, and discover routes.
- Housing: instanced homes with placeable items driven by JSON content.
- Minigames: lightweight sessions launched from the lobby or interactive housing items.

The Go backend owns the online authority layer for auth, realtime rooms,
economy, trade, housing, creator review, LiveOps, and production operations.
See `docs/BackendArchitecture.md` for the backend topology, data flows,
storage modes, and release gates.

The repository should keep player-facing text out of scripts and scenes. Runtime code reads stable English IDs from JSON and resolves display text through localization keys.

## Ownership Boundaries

Data and documentation live in:

- `configs/`
- `localization/`
- `docs/`
- `templates/`
- `tests/`

Scene and script implementation live outside this scope and should treat the JSON files as read-only contracts.

## Runtime Flow

1. Load `configs/app.json`.
2. Apply trusted runtime config overrides through `RuntimeConfigService`.
2. Load the configured localization file from `localization/`.
3. Load content registries from `configs/scene_routes.json`, `configs/chat_channels.json`, `configs/housing_items.json`, and `configs/minigames.json`.
4. Boot into `scenes/boot/Boot.tscn`, then route to the login scene by route ID.
5. Route scene changes by route ID, not by hardcoded scene path.
6. Render UI labels by localization key, not by literal strings.

## Data Principles

- Code-facing names use English snake_case IDs.
- Player-facing strings use localization keys.
- JSON files remain small and directly readable.
- Missing content should fail loudly in development and degrade gracefully in player builds.
- Scene routes must point to files that exist in the repository.

## Suggested Godot Services

- `ConfigLoader`: loads and validates JSON registries.
- `App`: loads locale JSON and resolves keys.
- `SceneRouter`: maps route IDs to scene paths and handles transitions.
- `ChatChannelRegistry`: exposes channel metadata and moderation profile names.
- `HousingCatalog`: exposes placeable item definitions.
- `MinigameCatalog`: exposes game session definitions.

These services can be autoloads or regular nodes depending on the main thread's project structure.
