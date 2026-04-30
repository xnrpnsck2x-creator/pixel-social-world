# Cloudflare Free Launch Runbook

## Decision

Use `funyoru.com` on the Cloudflare Free plan for the MVP web launch.

Read-only account check on 2026-04-30:

- Zone: `funyoru.com`
- Status: active
- Plan: Free Website, USD 0
- Nameservers: `fonzie.ns.cloudflare.com`, `mckinley.ns.cloudflare.com`
- Current DNS records: none
- Current Pages projects: none

R2 is not enabled on the account yet. No Cloudflare account changes were made
during this check.

## Source Asset Policy

Image2 `_source.png` production masters are still kept in the repository under
`assets/**/generated/`:

- `assets/maps/generated/forest_main_city_tileset_v0_source.png`
- `assets/ui/generated/ui_kit_v0_source.png`
- `assets/ui/generated/overhead_emotes_v1_source.png`
- `assets/ui/generated/hud_icons_v0_source.png`
- `assets/sprites/generated/characters_npcs_v0_source.png`
- `assets/sprites/generated/player_adventurer_actions_v0_source.png`
- `assets/housing/generated/housing_fishing_props_v0_source.png`

They are excluded only from the Web export by `export_presets.cfg`, because H5
runtime should load the sliced PNG/WebP outputs rather than production master
sheets. To restore them into a local Web export for debugging, remove the
`assets/**/generated/*_source.png` patterns from the preset's `exclude_filter`
and export again. Do not delete these files from `assets/`; they preserve Image2
lineage, auditability, and future atlas reprocessing.

## Free Plan Fit

The free path is viable for MVP, but the first web deployment should not be
Pages-only.

- `funyoru.com` should route through Cloudflare Tunnel to an Ubuntu static web
  server for the first H5 smoke deploy.
- `www.funyoru.com` can point to the same static web server or redirect to the apex.
- `api.funyoru.com` should route through the same Cloudflare Tunnel to the Go backend.
- PostgreSQL and Redis stay private on the Ubuntu host.
- R2 can stay off until creator package artifacts or Pages-only static hosting is needed.

Why: Cloudflare Pages has a 25 MiB maximum single static asset size. After the
H5 export preset excluded Image2 `_source.png` production masters, the latest
local Web export produced:

- `builds/web/index.wasm`: about 36 MiB
- `builds/web/index.pck`: about 18 MiB

`index.wasm` is the Godot Web engine template, so it remains above the Pages
single-file limit. Cloudflare's normal CDN can cache files up to 512 MB on Free,
so serving the H5 export from Ubuntu behind Cloudflare keeps the launch free
without enabling R2.

Pages becomes attractive again if one of these happens:

- Cloudflare grants a Pages asset limit increase.
- We enable R2 and serve large Godot binaries from `assets.funyoru.com`.
- A future Godot export template reduces `index.wasm` below 25 MiB.

## Target Hostnames

| Hostname | Use | Free-plan route |
| --- | --- | --- |
| `funyoru.com` | Public H5 client | Tunnel to Ubuntu static web server |
| `www.funyoru.com` | Alias | Tunnel route or redirect |
| `api.funyoru.com` | Go REST + WebSocket | Cloudflare Tunnel public hostname |
| `assets.funyoru.com` | Future creator artifacts / large H5 binaries | R2 custom domain later |

## Backend Environment

Production CORS should start narrow:

```bash
PSW_CORS_ALLOWED_ORIGINS=https://funyoru.com,https://www.funyoru.com
```

Keep backend `PSW_ADDR=127.0.0.1:8787` bound on the origin host. The public hostname
should forward to `http://127.0.0.1:8787`.

Serve the H5 export from a local static server, for example:

```text
/opt/pixel-social-world/web/
├── index.html
├── index.js
├── index.wasm
├── index.pck
├── runtime_config.json
└── index.png
```

The `funyoru.com` tunnel hostname should forward to that static server, for
example `http://127.0.0.1:8080`.

This is intentionally localhost-only so it can coexist with another public
domain or download service already bound to the server's fixed IP on `80/443`.
Use a separate PostgreSQL database/user and keep Redis on a separate logical DB
at minimum. If the existing game uses Redis Pub/Sub, prefer a dedicated Redis
instance for this project to avoid channel-name overlap.

Example server and tunnel configs are checked in:

- `backend/deploy/Caddyfile.funyoru.example`
- `backend/deploy/cloudflared-funyoru.yml.example`

## First Deploy Sequence

1. Rebuild Godot Web export.
2. Build the Linux backend and package the deployable bundle:

   ```bash
   backend/scripts/package-cloudflare-free-launch.sh
   ```

   This creates:

   ```text
   .tools/releases/pixel-social-world-funyoru-free-launch/
   .tools/releases/pixel-social-world-funyoru-free-launch.tar.gz
   ```

3. Transfer the archive to the Ubuntu host and expand it. From the expanded
   release directory, install the origin layout:

   ```bash
   sudo deploy/install-funyoru-origin.sh
   ```

   The installer lays out:

   ```text
   web/* -> /opt/pixel-social-world/web/
   backend/bin/pixel-social-world-server -> /opt/pixel-social-world/backend/bin/
   backend/configs/production.yaml -> /opt/pixel-social-world/backend/configs/
   configs/*.json -> /opt/pixel-social-world/configs/
   ```

4. Review and edit service files:

   ```text
   /etc/systemd/system/pixel-social-world.service
   /etc/pixel-social-world/backend.env
   /etc/caddy/Caddyfile.funyoru.example
   /etc/cloudflared/config.funyoru.yml.example
   ```

   Replace every `CHANGE_ME` value before starting production services.

5. After review, merge the local server and tunnel configs. If the server
   already has Caddy/nginx/cloudflared for another game, do not overwrite its
   active config. Add this site block and ingress rules alongside the existing
   ones:

   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   ```

6. Enable services:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now pixel-social-world
   sudo systemctl reload caddy
   sudo systemctl restart cloudflared
   ```

7. Serve `/opt/pixel-social-world/web/` through nginx or Caddy on
   `127.0.0.1:8080`.
8. Set cache headers for immutable Godot assets:

   ```bash
   Cache-Control: public, max-age=31536000, immutable
   ```

   Keep `index.html` and `runtime_config.json` on a short TTL while iterating.

9. Create Cloudflare Tunnel public hostnames:
   - Hostname: `funyoru.com`
   - Service: `http://127.0.0.1:8080`
   - Hostname: `www.funyoru.com`
   - Service: redirect to `https://funyoru.com` or the same static server
   - Hostname: `api.funyoru.com`
   - Service: `http://127.0.0.1:8787`
10. Set backend env:

   ```bash
   PSW_CORS_ALLOWED_ORIGINS=https://funyoru.com,https://www.funyoru.com
   ```

11. Smoke test:
   - `https://funyoru.com` loads the H5 shell.
   - `https://funyoru.com/runtime_config.json` returns the expected production endpoints.
   - `https://api.funyoru.com/healthz` returns OK.
   - H5 login, chat, presence, and room WebSocket connect through `api.funyoru.com`.

   Basic public smoke:

   ```bash
   backend/scripts/smoke-funyoru-public.sh
   ```

   Browser smoke:

   ```bash
   RUN_BROWSER_SMOKE=1 backend/scripts/smoke-funyoru-public.sh
   ```

## Free Plan Guardrails

- Avoid Pages Functions and Workers for MVP. They add limits we do not need yet.
- Avoid Pages-only hosting for the current Godot export because `index.wasm`
  exceeds 25 MiB.
- Do not use Workers as the API gateway yet. The Go backend already owns auth,
  rooms, chat, economy, housing, and creator review.
- Do not move PostgreSQL to D1. D1 is a different SQLite-backed product.
- Do not replace Redis with KV. Presence TTL and realtime coordination need
  Redis semantics for the current backend.
- Use R2 Standard storage only when creator artifacts or Pages-only large binary
  hosting need object storage. R2 has a free monthly tier, but it must be
  enabled through the dashboard first.

## R2 And Developer Plan Decision

R2 is usable for this project once it is enabled in the Cloudflare dashboard.
It does not replace the Go backend, PostgreSQL, or Redis. Treat it as object
storage for large/static files:

- creator upload packages and review artifacts
- approved minigame bundles
- Image2 generated asset archives
- optional large H5 binaries if we later want Pages for `index.html`/`index.js`

Recommended decision:

| Option | Use now? | Notes |
| --- | --- | --- |
| Strict free/no billing surface | Yes | Keep R2 disabled and serve H5 from Ubuntu through Tunnel/CDN. |
| R2 Standard with guardrails | Soon | Enable when creator package storage or Pages + R2 split hosting becomes useful. Use Standard storage so the free tier applies. |
| Workers/Developer paid plan | Later | Useful for Durable Objects, Queues, Workers API gateway, or edge review jobs. Not required for the current Go backend. |

If R2 is enabled, start with one bucket such as
`pixel-social-world-artifacts`, attach `assets.funyoru.com` only when public
delivery is needed, and keep creator review uploads private until approved.
Prefer custom domain delivery for production because Cloudflare Cache and WAF
controls apply there; `r2.dev` public URLs are for development only.

## Sources

- Cloudflare Pages limits:
  https://developers.cloudflare.com/pages/platform/limits/
- Cloudflare Tunnel:
  https://developers.cloudflare.com/tunnel/
- Cloudflare cache default behavior and size limits:
  https://developers.cloudflare.com/cache/concepts/default-cache-behavior/
- Cloudflare R2 pricing:
  https://developers.cloudflare.com/r2/pricing/
- Cloudflare R2 public buckets:
  https://developers.cloudflare.com/r2/data-access/public-buckets/
