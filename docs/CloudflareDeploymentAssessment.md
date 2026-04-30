# Cloudflare Deployment Assessment

## Decision

Use Cloudflare in front of the project, but do not rewrite the MVP backend onto
Workers yet.

Recommended MVP shape:

```text
Players
  -> Cloudflare DNS / WAF / CDN
  -> H5: funyoru.com to Ubuntu static web server via Cloudflare Tunnel/CDN
  -> API + WebSocket: api.funyoru.com to Go backend on Ubuntu 26.04 via Cloudflare Tunnel
  -> PostgreSQL + Redis: stay on the backend host or managed origin
  -> Creator package files: local filesystem now, R2 later
```

This keeps the current Godot + Go architecture intact while gaining Cloudflare
edge TLS, caching, WAF, DDoS protection, Pages preview deploys, and optional
origin hiding.

## Fit Matrix

| Layer | Current project | Cloudflare fit | Recommendation |
| --- | --- | --- | --- |
| H5 client | Godot Web export in `builds/web` | Good through Cloudflare CDN/Tunnel. Pages-only is blocked while `index.wasm` exceeds 25 MiB. | Serve from Ubuntu behind Cloudflare Free first; use Pages after R2 or size reduction. |
| Go REST API | Gin + Go binary | Not a direct Worker fit. Workers are JS/Web API runtime, not a lift-and-shift Go server. | Keep Go on Ubuntu for MVP. Put Cloudflare in front. |
| WebSocket realtime | Gorilla WS + Redis fanout | Possible on Workers, but multi-client rooms need Durable Objects. | Keep Go realtime now; consider DO later for room shards. |
| PostgreSQL | GORM/Postgres | D1 is SQLite semantics, not a drop-in Postgres replacement. Hyperdrive helps Workers reach Postgres, not the current Go service. | Keep Postgres. Do not migrate to D1 for MVP. |
| Redis | auth/session/presence/rate/session TTL | No direct Redis product replacement. KV is not a Redis TTL/pubsub replacement. | Keep Redis for MVP. |
| Creator package artifacts | local file store | R2 is a strong fit for zip/assets/object artifacts. | Add R2-backed `PackageArtifactStore` after local flow stabilizes or earlier if Pages needs large binary offload. |
| AI review | local policy / OpenAI-compatible LM Studio | Workers AI / AI Gateway may fit later. | Keep adapter boundary; add provider later if useful. |
| Player-created games | Godot GDScript packages | Workers for Platforms is for Worker JS code, not Godot scene packages. | Keep Godot sandbox pipeline. Revisit for web-only creator code later. |
| Full Go server on Cloudflare | Go binary + filesystem + Redis/Postgres | Containers can run arbitrary runtimes, but are beta/Paid and add Worker orchestration. | Not MVP path. Reassess after core loop is stable. |

## Why Not Full Cloudflare Workers Now

The current backend is intentionally a Go service:

- Gin HTTP handlers.
- Gorilla WebSocket server.
- GORM with PostgreSQL.
- Redis pub/sub, TTL, rate limiting, and sessions.
- Local/file package artifact and install staging.

Moving this to Workers would be a rewrite, not deployment. Durable Objects are
the right Cloudflare primitive for room coordination and persistent WebSockets,
but adopting them would mean replacing the current room hub, Redis fanout, and
parts of the minigame-session logic with a TypeScript edge service.

That may become attractive later, but it is not the fastest path to MVP.

## Recommended Phases

### Phase 1: Cloudflare Front Door

Ship without changing backend code.

- Use the active Cloudflare Free zone `funyoru.com`.
- Serve the H5 Web export from Ubuntu static hosting as `funyoru.com`.
- Expose the Ubuntu Go backend as `api.funyoru.com` through Cloudflare Tunnel.
- Keep PostgreSQL and Redis private to the Ubuntu host.
- Configure CORS for the public H5 domain.
- Keep Cloudflare Pages as an option after large Godot binaries move to R2 or
  every Pages static asset is at or below 25 MiB.

This is the lowest-risk Cloudflare adoption path.

### Phase 2: R2 Artifact Store

Move creator upload artifacts off local disk.

- Add `storage.package_artifacts_backend=r2`.
- Implement an R2-compatible `PackageArtifactStore`.
- Keep package scan, AI review, approval, publish, rollback, and audit logic in Go.
- Later, use presigned uploads for larger creator packages.
- Optionally serve large H5 binaries from `assets.funyoru.com` so Pages can
  host the small shell files while R2 carries `index.wasm` and `index.pck`.

R2 fits the creator platform because package zips, generated assets, and
installed bundles are object data rather than relational data.

### Phase 3: Edge Admin / API Shield

Add a small Worker in front of sensitive admin routes only if needed.

- Rate-limit admin endpoints.
- Add Cloudflare Access for Reviewer Console if using a private admin hostname.
- Keep raw admin tokens out of exported client configs.
- Forward valid traffic to the Go backend.

Do not duplicate business logic in the Worker.

### Phase 4: Durable Object Realtime Prototype

Prototype one room shard, not the whole backend.

- One Durable Object per room or minigame session.
- WebSocket coordination, room member state, and heartbeat TTL live inside that DO.
- PostgreSQL remains the long-term source of account/economy/house data.
- Compare latency, operational complexity, and cost against current Go + Redis.

Only expand this path if it clearly beats the current architecture.

### Phase 5: Cloudflare Native Platform Option

Reassess after MVP.

Possible future architecture:

```text
Pages H5
  -> Worker API gateway
  -> Durable Objects for rooms / sessions
  -> R2 for creator packages
  -> D1 per creator/tenant or Postgres via Hyperdrive for central data
  -> Queues for async review jobs
```

This is a platform rewrite. It is interesting long term, but too costly before
the main city, chat, housing, fishing, creator intake, and review loop are live.

## Product Notes

- Cloudflare Free CDN/Tunnel is appropriate for the current Godot Web export.
  Pages is useful later, but the current `index.wasm` is larger than Pages'
  single-file limit.
- Workers WebSockets are supported, but Cloudflare's own docs call out Durable
  Objects as the coordination point for chat rooms and game matches.
- D1 uses SQLite semantics and is designed around many smaller databases, so it
  is not a drop-in replacement for the current PostgreSQL/GORM data model.
- Hyperdrive is useful when Workers need to talk to Postgres. It is not needed
  while the Go backend connects directly to Postgres.
- R2 is a strong match for creator package archives, Image2/generated asset
  storage, and optional large H5 binary delivery through `assets.funyoru.com`.
- Cloudflare Tunnel is the clean MVP bridge because it can expose the Go origin
  without opening inbound ports on the server.

## Immediate Action

Keep the backend deployment target as Ubuntu 26.04 LTS + systemd + PostgreSQL +
Redis. Add Cloudflare as the outer delivery/security layer:

1. H5 on Ubuntu static hosting behind Cloudflare Tunnel/CDN.
2. API/WS behind Tunnel or proxied DNS.
3. R2 adapter after the local creator review flow stays green, or earlier if
   Pages plus large-binary offload becomes important.
4. Durable Objects only as a measured realtime experiment.

## Sources

- Cloudflare Pages static HTML deployment:
  https://developers.cloudflare.com/pages/framework-guides/deploy-anything/
- Cloudflare Pages limits:
  https://developers.cloudflare.com/pages/platform/limits/
- Cloudflare cache default behavior:
  https://developers.cloudflare.com/cache/concepts/default-cache-behavior/
- Cloudflare Workers WebSockets and Durable Objects coordination note:
  https://developers.cloudflare.com/workers/runtime-apis/websockets/
- Cloudflare real-time architecture use case:
  https://developers.cloudflare.com/use-cases/web-apps/real-time/
- Cloudflare D1 overview:
  https://developers.cloudflare.com/d1/
- Cloudflare Hyperdrive connection pooling:
  https://developers.cloudflare.com/hyperdrive/concepts/connection-pooling/
- Cloudflare R2 object upload docs:
  https://developers.cloudflare.com/r2/objects/upload-objects/
- Cloudflare Tunnel docs:
  https://developers.cloudflare.com/tunnel/
- Cloudflare Containers overview:
  https://developers.cloudflare.com/containers/
