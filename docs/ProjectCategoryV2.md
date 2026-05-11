# Project Category v2 Gate

Date: 2026-05-12

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
The mobile native category now requires iOS release readiness, Android export,
APK asset budget, Android release readiness, native release handoff, stability
probe, runtime budget, and device regression scripts.
The iOS release contract is executed by
`ios_release_readiness_contract_pass`, which verifies no signing or
provisioning values are stored in `export_presets.cfg` and that local Xcode
release tooling is ready before real signing values are introduced.
The Android release contract is executed by
`android_release_readiness_contract_pass`, which verifies no signing secrets are
stored in `export_presets.cfg` and that the local release tooling contract is
ready before real keystore values are introduced.
The native release handoff contract is executed by
`native_release_handoff_contract_pass`, which verifies
`docs/NativeReleaseHandoffRunbook.md`, required signing env names, local release
commands, evidence locations, and strict-mode fail-closed behavior when signing
env is absent.
The runtime budget gate is validated against the current 240-second Android
render-throttle report and the 600-second Android soak report. This validation
is executed by the `android_runtime_budget_reports_pass` category check, not
only documented as a manual step.

## Notes

This is a local-plus-Android-device v2 gate. iOS true-device checks, release
signing, store auth providers, and production monitoring remain outside the
local gate until device and deployment credentials are available.
Use `PSW_PROJECT_CATEGORY_V2_SKIP_ANDROID_RUNTIME=1` only for environments that
intentionally lack Android stability report artifacts.
