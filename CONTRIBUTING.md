# Contributing

Thanks for taking a look at Pixel Social World. The project is in public alpha preparation, so the best contributions are small, testable changes that make the platform safer, clearer, easier to run, or easier to review.

## Project Direction

Pixel Social World is a Godot 4.x + Go project for a 2D pixel online social world and creator minigame platform. Keep changes aligned with these constraints:

- Client code uses GDScript only.
- Backend services are written in Go.
- Creator games must follow the `IMinigame` contract.
- Public-facing text should be localizable in English, Japanese, and Simplified Chinese.
- Production secrets, signing keys, service accounts, DSNs, and API tokens must never be committed.
- Official UI and art assets should be PNG/WebP assets under `assets/`, with generated assets registered in the relevant config files.

## Getting Started

Clone the repository and run the backend tests:

```bash
cd backend
go test ./...
```

Run the backend locally in memory mode:

```bash
cd backend
GIN_MODE=release go run ./cmd/server
```

Open the client with Godot 4.x:

```bash
godot --path .
```

Local development may use project-local toolchains under `.tools/`. That directory is intentionally ignored and should not be committed.

## Workflow

Use a small branch for each change:

```bash
git checkout -b codex/short-change-name
```

Before opening a pull request, run the checks that match your change. At minimum:

```bash
python3 scripts/check_secret_hygiene.py
python3 tests/validate_content.py
cd backend && go test ./...
```

For release-facing or store-facing changes, also run the handoff checks:

```bash
scripts/check_store_auth_provider_handoff.sh
scripts/check_production_monitoring_handoff.sh
scripts/check_production_data_backup_handoff.sh
scripts/check_native_release_handoff.sh
scripts/check_store_publish_handoff.sh
```

For full local H5/Godot smoke coverage:

```bash
scripts/run_mvp_100_gate.sh
```

## Pull Request Guidelines

- Keep the scope narrow and describe the user or platform impact.
- Include the commands you ran and whether any checks were skipped.
- Avoid unrelated refactors in feature or bug-fix PRs.
- Do not include generated build products, `.tools/`, `.godot/`, local exports, signing assets, or cache folders.
- If the change touches auth, player data, uploads, moderation, creator packages, economy, or release signing, call that out explicitly.

The `main` branch is protected by the `Release Readiness` workflow. Required jobs are:

- `Backend tests`
- `Content, localization, and repo hygiene`
- `Release handoff contracts`
- `iOS and Android store handoff`

## Code Guidelines

Godot:

- Use GDScript, not C#.
- Keep GDScript files under 300 lines.
- Keep runtime-loaded creator minigames behind the `IMinigame` and sandbox flow.
- Keep visible UI text localizable.
- Preserve the 960x540 landscape mobile baseline and compact 375px-width pressure cases.

Go backend:

- Keep packages modular and avoid direct cross-module coupling when an interface boundary is clearer.
- Use environment variables or deployment env files for all secrets.
- Validate external input at the gateway boundary.
- Keep upload, creator package, auth, economy, and moderation changes covered by focused tests.

Assets and UI:

- Keep official generated assets in `assets/`.
- Register formal UI/art assets in config files when the runtime depends on them.
- Do not promote SVG placeholders into final HUD, main city, housing, or minigame UI.
- Keep visual changes testable with screenshot or semantic smoke checks when they affect player-facing flows.

## Security Rules

Never commit:

- `PSW_ADMIN_TOKEN`
- App Store Connect keys
- Google Play service account JSON
- Android release keystores
- PostgreSQL or Redis production credentials
- LiveOps alert tokens
- OpenAI-compatible reviewer API keys

Run:

```bash
python3 scripts/check_secret_hygiene.py
```

If a secret is accidentally committed, do not only delete it in a later commit. Rotate the secret and clean the repository history before publishing further.

## Licensing

By contributing, you agree that your contribution is provided under the Apache License 2.0, the same license as this repository, unless a separate written agreement says otherwise.
