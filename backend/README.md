# Pixel Social World Backend

This directory is the main production codebase for Pixel Social World. The Godot client owns presentation and input, while the Go backend owns trust, concurrency, persistence, economy, creator review, LiveOps, and release readiness.

The backend is intentionally shaped like a small online game server that can start in memory mode for local development, then switch to PostgreSQL and Redis for public-alpha operations without changing the client contract.

## Product Role

- Server authority: movement context, room membership, rewards, spending, trade settlement, inventory reservation, housing mutations, minigame sessions, and creator catalog state are validated in Go.
- Realtime core: Gorilla WebSocket handles city rooms, player movement, chat, capacity policies, Redis fanout, and Redis rate limits.
- Durable platform layer: PostgreSQL mode migrates and backs chat, private messaging, economy, housing, minigames, social graph, player maps, utility panels, inventory, trade, and map activities.
- Creator safety: creator submissions go through package storage, zip intake, local policy review, optional OpenAI-compatible review, reviewer audit history, and publishable catalog output.
- Operations surface: admin roles, moderation actions, chat/player reports, reviewer dashboard, action audit, structured request logs, `/debug/ops`, `/healthz`, and `/readyz` are part of the server.
- Release path: the server builds as a Linux amd64 Go binary and is designed for systemd plus external PostgreSQL, Redis, and environment-file secrets.

## Runtime Surface

| Area | Routes and protocols | Main packages |
| --- | --- | --- |
| Health and operations | `GET /healthz`, `GET /readyz`, `GET /debug/ops`, `GET /debug/rooms` | `internal/gateway`, `internal/ops` |
| Auth and account upgrade | `POST /auth/guest`, `POST /auth/refresh`, `POST /auth/upgrade`, `GET /me` | `internal/auth`, `internal/player` |
| Realtime city | `GET /ws/city`, `POST /presence/heartbeat`, `GET /rooms/:room_id/members` | `internal/room`, `internal/presence` |
| Chat and messaging | `POST /chat/send`, `GET /chat/history/*`, private messages, mailbox, reports | `internal/chat`, `internal/messaging` |
| Economy, inventory, trade | rewards, spend, ledger, creator-share, inventory, listings, buy, cancel, history | `internal/economy`, `internal/inventory`, `internal/trade` |
| Housing and social | layout, invite, visit, place, move, remove, follow, block, social state, facilities | `internal/house`, `internal/social`, `internal/facility` |
| Creator minigames | package upload, zip upload, review, status, history, catalog, sessions, fishing rewards | `internal/minigame`, `pkg/ai` |
| Admin and LiveOps | reviewer dashboard, audits, moderation, admin utility panels, inventory/trade audits | `internal/gateway`, `internal/chat`, `internal/utility` |

## Local Toolchain

Use the project-local Go install from the repo root:

```bash
./.tools/go/bin/go version
```

Module and build caches should stay under `.tools/`.

## Linux Build

Build the production Linux amd64 binary from the repo root:

```bash
backend/scripts/build-linux-amd64.sh
```

The output binary is `backend/bin/pixel-social-world-server`.

## Memory Mode

Default local mode uses in-memory services:

```bash
cd backend
ROOT="$(cd .. && pwd)"
env GIN_MODE=release \
  GOMODCACHE="$ROOT/.tools/gomodcache" \
  GOCACHE="$ROOT/.tools/gocache" \
  "$ROOT/.tools/go/bin/go" run ./cmd/server
```

## PostgreSQL Mode

Start Postgres and Redis with `docker compose` when Docker is available:

```bash
cd backend
docker compose up -d postgres redis
```

Then run:

```bash
cd backend
ROOT="$(cd .. && pwd)"
env GIN_MODE=release \
  PSW_STORAGE=postgres \
  GOMODCACHE="$ROOT/.tools/gomodcache" \
  GOCACHE="$ROOT/.tools/gocache" \
  "$ROOT/.tools/go/bin/go" run ./cmd/server
```

PostgreSQL mode runs AutoMigrate for economy, housing, chat, private messages, minigame submissions, social graph, player maps, utility panels, inventory, trade, and map activity claims.

Creator package artifacts are stored under `PSW_PACKAGE_ARTIFACT_DIR` or `storage.package_artifacts_dir`; local default is `backend/var/creator_packages`.
Published creator packages are installed under `PSW_PACKAGE_INSTALL_DIR` or `storage.package_install_dir`; local default is `backend/var/creator_runtime`.
Main-city shop, mail, and notice rows are loaded from `PSW_UTILITY_PANELS_CONFIG_PATH` or `utility.panels_config_path`; local default is `configs/utility_panels.json`.

## Redis Realtime Mode

Presence and minigame sessions can use Redis TTLs:

```bash
cd backend
ROOT="$(cd .. && pwd)"
env GIN_MODE=release \
  PSW_REALTIME=redis \
  GOMODCACHE="$ROOT/.tools/gomodcache" \
  GOCACHE="$ROOT/.tools/gocache" \
  "$ROOT/.tools/go/bin/go" run ./cmd/server
```

Useful settings:

- `PSW_CONFIG`
- `PSW_HTTP_READ_HEADER_TIMEOUT_SECONDS`
- `PSW_HTTP_READ_TIMEOUT_SECONDS`
- `PSW_HTTP_WRITE_TIMEOUT_SECONDS`
- `PSW_HTTP_IDLE_TIMEOUT_SECONDS`
- `PSW_HTTP_SHUTDOWN_TIMEOUT_SECONDS`
- `PSW_HOUSING_CONFIG_PATH`
- `PSW_HOUSING_SELL_REFUND_RATE`
- `PSW_FISHING_CONFIG_PATH`
- `PSW_UTILITY_PANELS_CONFIG_PATH`
- `PSW_PACKAGE_ARTIFACT_DIR`
- `PSW_PACKAGE_INSTALL_DIR`
- `PSW_AI_REVIEWER_MODE`
- `PSW_AI_REVIEWER_BASE_URL`
- `PSW_AI_REVIEWER_MODEL`
- `PSW_AI_REVIEWER_TIMEOUT_SECONDS`
- `PSW_POSTGRES_DSN`
- `PSW_POSTGRES_MAX_OPEN_CONNS`
- `PSW_POSTGRES_MAX_IDLE_CONNS`
- `PSW_POSTGRES_CONN_MAX_LIFETIME_SECONDS`
- `PSW_POSTGRES_CONN_MAX_IDLE_TIME_SECONDS`
- `PSW_PRESENCE_TTL_SECONDS`
- `PSW_SESSION_TTL_SECONDS`
- `PSW_REDIS_ADDR`
- `PSW_REDIS_PASSWORD`
- `PSW_REDIS_DB`
- `PSW_REDIS_POOL_SIZE`
- `PSW_REDIS_MIN_IDLE_CONNS`
- `PSW_REDIS_DIAL_TIMEOUT_SECONDS`
- `PSW_REDIS_READ_TIMEOUT_SECONDS`
- `PSW_REDIS_WRITE_TIMEOUT_SECONDS`

## Verification

```bash
cd backend
ROOT="$(cd .. && pwd)"
env GOMODCACHE="$ROOT/.tools/gomodcache" \
  GOCACHE="$ROOT/.tools/gocache" \
  "$ROOT/.tools/go/bin/go" test ./...
```

Reviewer golden-set tests run against the local policy adapter by default. To run the same suite against LM Studio or another OpenAI-compatible endpoint, start/load the model yourself, then run:

```bash
cd backend
ROOT="$(cd .. && pwd)"
env PSW_RUN_LLM_GOLDEN=1 \
  PSW_AI_REVIEWER_BASE_URL=http://127.0.0.1:1234/v1 \
  PSW_AI_REVIEWER_MODEL=qwen/qwen3-coder-next \
  GOMODCACHE="$ROOT/.tools/gomodcache" \
  GOCACHE="$ROOT/.tools/gocache" \
  "$ROOT/.tools/go/bin/go" test ./pkg/ai -run TestOpenAICompatibleReviewerGoldenSet
```

For Godot-to-backend E2E, start the backend on `:18787`, then run from repo root:

```bash
/Applications/Godot_mono.app/Contents/MacOS/Godot \
  --headless --path . --script tests/online_backend_e2e.gd
```
