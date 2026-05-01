# Backend Deployment

## Target

Early production target:

- Linux amd64
- Intel i9-13900KF
- 64GB RAM
- Ubuntu 26.04 LTS
- Go backend as one systemd service
- PostgreSQL and Redis on the same host for MVP

The deployment baseline targets Ubuntu 26.04 LTS. The service files avoid distro-specific shell behavior so they can stay portable across later LTS upgrades.

Cloudflare can sit in front of this service through proxied DNS or Cloudflare
Tunnel, but the MVP backend remains the Go binary on Ubuntu. The selected
launch zone is `funyoru.com` on Cloudflare Free. Full assessment:
`docs/CloudflareDeploymentAssessment.md`.

## Build

From the repo root:

```bash
backend/scripts/build-linux-amd64.sh
```

The binary is written to:

```text
backend/bin/pixel-social-world-server
backend/bin/pixel-social-world-preflight
backend/bin/pixel-social-world-retention-cleanup
```

## Install Layout

Recommended server layout:

```text
/opt/pixel-social-world/backend/
├── bin/pixel-social-world-server
├── bin/pixel-social-world-preflight
├── bin/pixel-social-world-retention-cleanup
├── configs/production.yaml
└── deploy/
/opt/pixel-social-world/configs/
└── fishing.json

/etc/pixel-social-world/backend.env
```

Create a non-login service user:

```bash
sudo useradd --system --home /opt/pixel-social-world --shell /usr/sbin/nologin pixelsocial
```

## Environment

Start from:

```text
backend/deploy/pixel-social-world.env.example
```

Production must set at least:

```bash
PSW_CONFIG=/opt/pixel-social-world/backend/configs/production.yaml
PSW_STORAGE=postgres
PSW_REALTIME=redis
PSW_STARTING_COINS=25
PSW_CREATOR_SHARE_BPS=1000
PSW_DAILY_SOFT_CAP=400
PSW_POSTGRES_DSN=postgres://pixel:CHANGE_ME@127.0.0.1:5432/pixel_social_world?sslmode=disable
PSW_POSTGRES_MAX_OPEN_CONNS=40
PSW_POSTGRES_MAX_IDLE_CONNS=20
PSW_REDIS_ADDR=127.0.0.1:6379
PSW_REDIS_POOL_SIZE=128
PSW_REDIS_MIN_IDLE_CONNS=16
PSW_HOUSING_CONFIG_PATH=/opt/pixel-social-world/configs/housing_items.json
PSW_FISHING_CONFIG_PATH=/opt/pixel-social-world/configs/fishing.json
PSW_PACKAGE_ARTIFACT_DIR=/var/lib/pixel-social-world/creator_packages
PSW_PACKAGE_INSTALL_DIR=/var/lib/pixel-social-world/creator_runtime
PSW_AI_REVIEWER_MODE=local_policy
PSW_CORS_ALLOWED_ORIGINS=https://funyoru.com,https://www.funyoru.com
```

Keep the real file at:

```text
/etc/pixel-social-world/backend.env
```

Do not commit that file.

## systemd

Install:

```bash
sudo cp backend/deploy/pixel-social-world.service /etc/systemd/system/pixel-social-world.service
sudo cp backend/deploy/pixel-social-world-retention-cleanup.service /etc/systemd/system/pixel-social-world-retention-cleanup.service
sudo cp backend/deploy/pixel-social-world-retention-cleanup.timer /etc/systemd/system/pixel-social-world-retention-cleanup.timer
sudo systemctl daemon-reload
sudo -u pixelsocial /opt/pixel-social-world/backend/bin/pixel-social-world-preflight -env-file /etc/pixel-social-world/backend.env -strict
sudo -u pixelsocial /opt/pixel-social-world/backend/bin/pixel-social-world-retention-cleanup -env-file /etc/pixel-social-world/backend.env
sudo systemctl enable --now pixel-social-world
sudo systemctl enable --now pixel-social-world-retention-cleanup.timer
```

Check:

```bash
systemctl status pixel-social-world
journalctl -u pixel-social-world -f
curl http://127.0.0.1:8787/healthz
curl http://127.0.0.1:8787/readyz
```

The service runs `pixel-social-world-preflight -strict` as `ExecStartPre`, then sends SIGTERM on stop and the Go server performs graceful shutdown.

## Logs And Preflight

The backend writes one JSON access log row per HTTP request. Each row includes `event=http_request`, `request_id`, method, path, status, latency, client IP, user agent, and response bytes. Send `X-Request-ID` from Cloudflare/nginx/support tools to correlate browser reports, backend logs, and admin audit rows.

Run the preflight command before starting or after editing `/etc/pixel-social-world/backend.env`:

```bash
/opt/pixel-social-world/backend/bin/pixel-social-world-preflight \
  -env-file /etc/pixel-social-world/backend.env \
  -strict
```

It validates config shape, production secrets/placeholders, shared JSON contracts, and writable package artifact/install directories. It does not print raw secrets.
With `-strict`, production auth must use `auth.provider_verification=oidc_jwt`
and must provide both Apple and Google client ID lists through
`PSW_APPLE_CLIENT_IDS` and `PSW_GOOGLE_CLIENT_IDS`.

The retention cleanup command defaults to dry-run and prints matched row counts:

```bash
/opt/pixel-social-world/backend/bin/pixel-social-world-retention-cleanup \
  -env-file /etc/pixel-social-world/backend.env
```

The systemd timer runs the same command with `-execute` once daily. Room chat is
not touched by this job because it remains live-only memory/Redis state; the job
only prunes durable PostgreSQL tables declared by the retention plan.

## Single-Host Sizing

For the MVP, keep PostgreSQL and Redis local:

- PostgreSQL stores account, wallet, ledger, housing, chat/report moderation records, long-term content metadata, and creator review job state.
- The filesystem stores raw creator package artifacts under `/var/lib/pixel-social-world/creator_packages` and runtime installed packages under `/var/lib/pixel-social-world/creator_runtime`; back both up with PostgreSQL until S3-compatible storage is added.
- Redis stores online presence, room membership, session TTLs, and future fanout state.
- Start with one Go process; the 13900KF has enough CPU headroom for early realtime traffic.
- Realtime room caps start at 100 players in the main city, 20 in homes, 16 in minigames, and 50 in custom rooms. Raise them only after same-room movement fanout is benchmarked on the target host.

Initial conservative process targets:

- Go backend: 1 process, all CPU cores available.
- HTTP server: 5s read-header timeout, 15s read timeout, 20s write timeout, 75s idle timeout, and 10s graceful shutdown timeout.
- PostgreSQL: start with 40 max open connections, 20 idle connections, 30 minute max lifetime, and 5 minute idle lifetime; raise only after observing DB wait time.
- Redis: start with a 128 connection pool, 16 min-idle connections, 5s dial timeout, and 3s read/write timeouts; use a separate Redis instance if another game also uses Pub/Sub heavily.
- PostgreSQL memory should still be capped deliberately instead of competing with the OS.
- Redis persistence stays optional until reconnect recovery requires it.

## Open Ports

Expose only:

- `22/tcp` for SSH, locked down by key and firewall.
- `80/tcp` and `443/tcp` when nginx/TLS is added.
- Backend `8787/tcp` should stay private behind nginx or a firewall rule.

PostgreSQL and Redis should bind locally for MVP.

## Web Client

The H5 build calls the backend from the browser, so production must set `PSW_CORS_ALLOWED_ORIGINS` to the exact public web origin served by nginx/CDN. Local development keeps `http://127.0.0.1:18888` and `http://localhost:18888` enabled for static Web export testing.

For the first Cloudflare Free launch, serve the Godot Web export from the same
Ubuntu host instead of Pages-only hosting. Bind the H5 static server to
`127.0.0.1:8080` and the Go backend to `127.0.0.1:8787` so an existing public
game download domain on the fixed IP can keep owning `80/443`. The current
Godot `index.wasm` is larger than Cloudflare Pages' 25 MiB single-asset limit,
but Cloudflare CDN can cache origin files up to 512 MB on the Free plan. Route
`funyoru.com` to the local static web server through Cloudflare Tunnel, and
route `api.funyoru.com` to the Go backend.

Reference configs:

- `backend/deploy/Caddyfile.funyoru.example` serves `/opt/pixel-social-world/web` on `127.0.0.1:8080`.
- `backend/deploy/cloudflared-funyoru.yml.example` maps `funyoru.com`, `www.funyoru.com`, and `api.funyoru.com` to local services.
- `backend/deploy/install-funyoru-origin.sh` installs an expanded release bundle into `/opt/pixel-social-world`, `/etc/pixel-social-world`, and systemd without auto-starting services.
- `backend/scripts/package-cloudflare-free-launch.sh` builds the Linux amd64 backend and packages the current H5 export, backend config, shared JSON configs, and deploy samples.
- `backend/scripts/smoke-funyoru-public.sh` verifies the public H5 shell and `api.funyoru.com/healthz`; set `RUN_BROWSER_SMOKE=1` for the Playwright viewport smoke.

If the same Ubuntu host already runs another game, keep this service isolated:

- Do not bind this project to public `80/443`; keep H5 on `127.0.0.1:8080` and API on `127.0.0.1:8787`.
- Do not overwrite existing nginx/Caddy/cloudflared files. Merge the site block and Tunnel ingress rules.
- Use a separate PostgreSQL database and user, for example `pixel_social_world` / `pixel`.
- Use a separate Redis DB at minimum. The production example uses `PSW_REDIS_DB=5`.
- If the existing game also uses Redis Pub/Sub heavily, prefer a separate Redis instance such as `127.0.0.1:6380`, because Pub/Sub channel names are not isolated by logical DB.
- Keep filesystem state under `/opt/pixel-social-world`, `/etc/pixel-social-world`, and `/var/lib/pixel-social-world`.

Image2 `_source.png` files remain in `assets/**/generated/` for audit and
atlas reprocessing. They are excluded from the Web export only; remove the
`*_source.png` patterns from `export_presets.cfg` and re-export if a debugging
build needs the production masters in `index.pck`.

## Minigame Rewards

Fishing reward rules are loaded from `PSW_FISHING_CONFIG_PATH`. In Redis realtime mode, fishing reward counters and `request_id` replay data are stored in Redis with the session TTL, so multi-process deployments share the same catch cap.

## Utility Panels

Main-city shop, mail, and notice rows are loaded from `PSW_UTILITY_PANELS_CONFIG_PATH` and exposed through authenticated `/utility/*` endpoints. In memory mode, admin updates are temporary process state. In `PSW_STORAGE=postgres`, the server auto-migrates `utility_panel_records`; the first boot seeds from `configs/utility_panels.json`, and later admin updates survive process restarts.

## Housing Catalog

Housing item prices, sizes, categories, rotation flags, and surface/furniture types are loaded from the shared `configs/housing_items.json` file through `PSW_HOUSING_CONFIG_PATH`. The backend treats this file as authoritative for online spend and placement validation, so deploy the same file used by the Godot client build.
