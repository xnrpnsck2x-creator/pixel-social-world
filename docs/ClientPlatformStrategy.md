# Client Platform Strategy

## Goal

Keep iOS, Android, desktop, and H5 on one network/session contract.

## Session Storage

- Godot calls `SessionTokenStore` instead of writing session tokens directly.
- Desktop and current tests persist through `SaveSystem`.
- H5 uses browser `localStorage` when `OS.has_feature("web")` and `JavaScriptBridge` are available.
- Future iOS and Android secure storage should replace the `SessionTokenStore` native branch without changing `OnlineClient`.

Config key:

```json
{
  "network": {
    "web_session_storage_key": "pixel_social_world.session.v1"
  }
}
```

Stored session fields:

- `player_id`
- `session_id`
- `access_token`
- `refresh_token`

## Account Upgrade

`OnlineClient.upgrade_guest_account()` is the shared bridge from guest play to bound account play.

- H5 passes the trusted app-shell Web OAuth result to `POST /auth/upgrade` with `platform: "h5"`.
- iOS and Android use the same endpoint with `platform: "ios"` or `platform: "android"`.
- The backend keeps the existing `player_id` and returns fresh access/refresh tokens.
- The client replaces the stored session through `SessionTokenStore`, so H5 localStorage and native SaveSystem stay on the same contract.
- Creator minigames do not call Web OAuth or `JavaScriptBridge`; only the trusted shell may collect provider tokens.

## Lifecycle

`NetworkLifecycle` is the shared pause/resume controller.

- App pause/focus out calls `RealtimeClient.pause_realtime()`.
- App resume/focus in calls `RealtimeClient.resume_realtime()`.
- H5 listens to `document.visibilitychange` through `JavaScriptBridge`.
- `pause_realtime_on_hidden` controls H5 hidden-tab behavior.

Config keys:

```json
{
  "network": {
    "lifecycle_enabled": true,
    "pause_realtime_on_hidden": true
  }
}
```

## Runtime Config

`RuntimeConfigService` applies a narrow trusted-app-shell override during boot.
The bundled `configs/app.json` keeps local-dev defaults, then H5 can fetch
`/runtime_config.json` from the current origin. For `funyoru.com`, the release
bundle writes `backend/deploy/runtime_config.funyoru.json` to
`web/runtime_config.json`.

Allowed override scope is deliberately small:

- REST and WebSocket endpoints.
- Online/timeout/reconnect tuning.
- Boolean feature flags.
- Maintenance and minimum-version metadata.

The login route consumes that metadata through `App.get_runtime_gate()` before
creating a guest session. If maintenance is enabled or the bundled client
version is below `min_client_version`, the Image 2 skinned runtime gate panel
blocks entry and can request a fresh runtime config pull.
`Boot` waits for `App.initialized` before routing so localization and runtime
gate decisions are ready before the login scene is created.

Creator minigames cannot access this service or widen the override surface.
Runtime config does not change scene routes, content paths, session storage
keys, asset contracts, or creator package rules.

## H5 Notes

- Browser storage is convenient but not equivalent to mobile secure storage.
- H5 release should use HTTPS only so bearer tokens do not travel over plain HTTP.
- If browser storage is unavailable or blocked, the client falls back to `SaveSystem`.
- Creator minigames still cannot use `JavaScriptBridge`; it is reserved for trusted app shell code.
- Reviewer Console can run in the trusted H5 shell, but admin tokens are typed per session and must never be bundled into exported configs or creator packages.

## Cloudflare H5 Route

- Godot Web export is static output, but the current Godot `index.wasm` is larger than Cloudflare Pages' 25 MiB single-file limit.
- The selected Free-plan launch domain is `funyoru.com`.
- For the first free smoke deploy, serve the H5 export from Ubuntu behind Cloudflare Tunnel/CDN at `funyoru.com`.
- The H5 build should call the Go backend through `api.funyoru.com`.
- For MVP, keep the Go backend on Ubuntu 26.04 LTS behind Cloudflare Tunnel or proxied DNS instead of rewriting it as Workers.
- Cloudflare Pages preview deployments become useful once large Godot binaries are moved to R2 or under the Pages size limit.
- `export_presets.cfg` excludes Image2 `_source.png` production masters from H5; this reduced `index.pck` from about 29 MiB to about 18 MiB while keeping the source sheets in `assets/**/generated/`.
- If R2 is enabled later, `assets.funyoru.com` can carry large H5 binaries and creator package artifacts while the Go backend continues to own gameplay APIs.
- `/runtime_config.json` can later be served from a static file, Worker, or KV-backed Worker without changing the Godot package.
- See `docs/CloudflareDeploymentAssessment.md` for the full front-end, backend, database, and artifact-storage decision.

## Verified

- `tests/session_token_store_smoke.gd`
- `tests/network_lifecycle_smoke.gd`
- `tests/runtime_config_smoke.gd`
- `tests/runtime_gate_smoke.gd`
- `tests/h5_runtime_gate_smoke.mjs`
- `tests/online_client_smoke.gd`
- `tests/auth_upgrade_backend_e2e.gd`
- `tests/reviewer_console_backend_e2e.gd`
- `tests/room_lifecycle_smoke.gd`
