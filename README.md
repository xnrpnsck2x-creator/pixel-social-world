# Pixel Social World

[![Release Readiness](https://github.com/xnrpnsck2x-creator/pixel-social-world/actions/workflows/release-readiness.yml/badge.svg)](https://github.com/xnrpnsck2x-creator/pixel-social-world/actions/workflows/release-readiness.yml)

Pixel Social World is a 2D pixel online social world built around a warm forest main city, housing, chat, live operations, economy systems, and a creator minigame platform. The long-term goal is a social MMO-like space where players can publish AI-assisted minigames through a stable `IMinigame` contract.

Current status: public alpha preparation. The repository is being opened for project visibility and release readiness review; production credentials, signing keys, and deployment secrets are intentionally not committed.

## Stack

- Client: Godot 4.x, GDScript only
- Backend: Go, Gin, Gorilla WebSocket, GORM
- Runtime data: PostgreSQL for durable storage, Redis for realtime/session TTLs
- Target platforms: iOS, Android, H5/Web, later PC
- Languages: English, Japanese, Simplified Chinese

## What Is In The MVP

- Main city scene with movement, NPCs, map points, chat, inventory, mail, trade, guild, creator, and LiveOps panels
- Official fishing minigame and creator minigame contract examples
- Guest auth and Apple/Google upgrade contracts
- Economy ledger, inventory, housing, social facility, moderation, and audit flows
- Image 2 generated map, UI, character, branding, and store artwork assets under `assets/`
- Store handoff runbooks for iOS, Android, production monitoring, auth providers, and data backup

## Quick Start

Backend tests:

```bash
cd backend
go test ./...
```

Run the backend locally in memory mode:

```bash
cd backend
GIN_MODE=release go run ./cmd/server
```

Open the Godot client with Godot 4.x:

```bash
godot --path .
```

This workspace also supports project-local toolchains under `.tools/` during local development, but `.tools/` is intentionally ignored and not part of the public repository.

## Verification

The GitHub Actions release-readiness workflow runs:

- Go format and backend unit tests
- Content and localization contract validation
- Secret hygiene and tracked file size guards
- GDScript 300-line budget
- Release handoff contracts for store auth, monitoring, backup, iOS, and Android

The deeper local gate is still available for full H5/Godot screenshot and semantic smoke coverage:

```bash
scripts/run_mvp_100_gate.sh
```

## Repository Map

- `assets/` - official generated pixel art, UI, branding, and map assets
- `backend/` - Go API, realtime, economy, house, inventory, trade, moderation, and deployment code
- `configs/` - client/runtime JSON configuration
- `docs/` - architecture, contracts, roadmap, store handoff, and production runbooks
- `localization/` - English, Japanese, and Simplified Chinese strings
- `scenes/` - Godot scenes
- `scripts/` - local gates, export helpers, and release readiness checks
- `tests/` - content validators, Godot smoke tests, H5 semantic tests, and backend E2E scripts

## Security And Secrets

Do not commit production secrets. Use environment variables or `/etc/pixel-social-world/backend.env` for deployment configuration. The repository intentionally keeps these external:

- App Store Connect keys and provisioning profiles
- Google Play service account JSON and Android release keystores
- `PSW_ADMIN_TOKEN`, PostgreSQL DSNs, Redis passwords, and LiveOps alert tokens
- OpenAI-compatible reviewer API keys

Run the local secret check before publishing changes:

```bash
python3 scripts/check_secret_hygiene.py
```

## Creator Minigame Contract

Creator games must inherit the Godot `IMinigame` interface and provide localized metadata. Runtime-loaded games are isolated through the minigame sandbox flow, and creator submissions are reviewed before listing.

See:

- `docs/CreatorMinigameSpec.md`
- `docs/BackendContract.md`
- `scripts/minigame/IMinigame.gd`

## License

Apache License 2.0. See `LICENSE`.

SPDX-License-Identifier: Apache-2.0

Project copyright: Copyright 2026 xnrpnsck2x-creator. Third-party dependencies remain under their own licenses.
