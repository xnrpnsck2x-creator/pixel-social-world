# Project Category v2 Gate

Date: 2026-05-08

This document defines the project-level v2 category gate. It is the umbrella
contract above the existing MVP 100 gate and H5 screenshot patrols.

## Scope

The v2 gate covers 14 project categories:

- Auth/profile
- Main city maps
- NPC roles
- Player avatars
- UI/HUD/mobile
- Social chat/messaging
- Economy/inventory/trade
- Housing
- Creator minigame platform
- Official fishing minigame
- LiveOps/moderation
- Realtime presence/sync
- Localization
- Mobile H5/native readiness

Each category must declare:

- `version: "v2"`
- responsible agents
- MVP chain
- required docs/configs/tests/scripts
- automatic checks that prove the category has concrete coverage

The source of truth is `configs/project_categories_v2.json`.

## Commands

Run the project category gate:

```bash
./scripts/run_project_category_v2_gate.sh
```

Run the visual H5 category gate:

```bash
PSW_H5_EXPORT_WEB=1 ./scripts/run_h5_category_v2_gate.sh
```

The project gate automatically includes the latest local H5 category summary
from `.tools/h5-category-v2-gate-current/category-v2-summary.json` when it
exists.

## Current Result

The local project category v2 gate passes with 14 categories and no failures.
The current local H5 category v2 summary also passes, covering maps, NPC
ambience, avatar variants, and avatar actions.

## Notes

This is a pre-device v2 gate. True-device iOS/Android input, keyboard, signing,
store auth providers, and production monitoring remain outside the local gate
until device and deployment credentials are available.
