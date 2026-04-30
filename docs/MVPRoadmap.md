# MVP Roadmap

## Strategic Source

The current product strategy is tracked in `docs/StrategicPlan.md`.
The accelerated content route is tracked in `docs/AcceleratedContentRoute.md`.

This roadmap remains the narrow playable-slice checklist. When it conflicts with
`AGENTS.md`, `game_design_bible.md`, or `docs/StrategicPlan.md`, follow the
stricter strategic constraint.

Current MVP direction:

- Keep the existing warm forest town as the first main city base.
- Treat port-city content as a later fishing/harbor expansion candidate.
- Ship the official fishing minigame as the first complete `IMinigame` example.
- Keep creator games to interface, validation, review, and whitelist alpha during the accelerated MVP window.
- Compress the first content expansion into 4-6 weeks, then use weeks 8-12 for small real-player tests.

## Day 1 Foundation

- Create the Godot project shell and route the boot flow through `configs/scene_routes.json`.
- Load English, Japanese, and Simplified Chinese localization files.
- Show the town square with a controllable player avatar.
- Open a chat panel backed by configured channel metadata.
- Stub home entry while the housing catalog is loaded from `configs/housing_items.json`.
- Stub minigame entry while the enabled minigame catalog is loaded from `configs/minigames.json`.

## MVP Loop

- Players enter the world, move around, and see other online players.
- Players chat in nearby, global, house, and party scopes.
- Players visit their home, arrange starter furniture, and save a simple layout.
- Players fish at the town pier and receive coin rewards.
- Coins pay for room layout placement and style changes.

## Current Studio Mode Focus

The first playable slice is intentionally narrow:

1. Login to the town square.
2. Move the avatar.
3. Send messages in configured chat channels.
4. Catch fish from the town pier.
5. Earn coins from catches.
6. Spend coins on starter housing items.
7. Save a basic home layout.

`tile_dash` and `sprite_match` remain post-MVP content until the fishing and housing loop is stable.
Mining v0 is the preferred second official minigame candidate because it reuses the life-skill/economy loop with lower implementation risk.

## Content Milestones

- Add starter avatar options.
- Add a first-pass moderation profile per channel.
- Add a small housing catalog with floor, wall, furniture, decor, and activity items.
- Add fishing as the first minigame, with post-MVP definitions kept disabled until scope allows.
- Add mining v0 after fishing/housing reach v1 stability.
- Add the first daily task set around chat, fishing, and house visits.
- Add localization keys for every visible label, error, and status.

## Technical Milestones

- JSON loader with clear error output.
- Scene routing by route ID.
- Locale switching without changing content IDs.
- Save format for home layouts.
- Minimal server contract for presence, chat, and minigame results.
- Creator manifest validation aligned with `AGENTS.md`.
- Server-authoritative economy mutations for rewards and spends.
- Ubuntu 26.04 LTS deployment docs for the Go backend.
- H5 runtime config and pre-login maintenance/minimum-version gate.

## Completion Check

Status as of 2026-04-30:

- P0 playable loop is locally testable: guest login, main city route, avatar movement, online presence plumbing, and chat contracts are in place.
- P1 local/online loop is alpha-ready: housing placement/spend, fishing rewards, coin sinks, and `IMinigame` sandbox contracts are implemented with smoke coverage.
- Creator platform is architecture-ready but not public-launch ready: validation, review, install catalog, and mode contracts exist; public creator UX and operations remain gated.
- H5 launch path is technically viable on `funyoru.com` through Ubuntu + Cloudflare Free CDN/Tunnel, with runtime config and login gate now reducing first-deploy operations risk.
- Store/platform launch is not complete: Apple/Google login, mobile exports, TestFlight/Google Play review setup, and production monitoring are still pending.

## Acceptance Criteria

- No player-facing text is hardcoded in scripts or scene-owned UI.
- `python3 tests/validate_content.py` passes.
- `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path . --script tests/godot_smoke.gd` passes.
- All configured scene routes include `id`, `path`, `type`, and `title_key`.
- English, Japanese, and Simplified Chinese localization files expose the same key set.
- MVP content can be extended by editing JSON without changing scene code.
- Runtime maintenance/minimum-version gates are covered by `tests/runtime_gate_smoke.gd`.
- H5 maintenance gate is screenshot-smoked by `tests/h5_runtime_gate_smoke.mjs`.
