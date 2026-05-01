# MVP Progress and Performance Forecast

Date: 2026-05-01

Scope: current Godot 4 + Go backend MVP on the planned single Linux amd64 host
(Ubuntu 26.04 LTS, i9-13900KF, 64GB RAM), before production load testing.

Scoring:
- MVP progress: 0-100%, based on implemented and verified slices.
- Performance scores: 1-5, where 5 means strong headroom for MVP scale and 1
  means the path is likely to block alpha without redesign.
- These are architecture forecasts, not benchmark results.

## Chain Progress

| Chain | MVP progress | Current state | Main blocker to v1 |
| --- | ---: | --- | --- |
| Guest auth + session refresh | 82% | Guest login, token refresh, H5 session restore, REST/WS auth gates verified. | Apple/Google provider production setup and store review data handling. |
| Main city walking + HUD | 78% | Main scene, Image2 HUD, action buttons, NPC/hotspot entry, name reveal, H5 landscape guard verified. | Final map collision polish and mobile/touch movement ergonomics. |
| Presence + room members | 79% | Heartbeat, room member list, remote avatars, profile card entry, stale state visible, per-room caps visible in debug state. | True disconnect edge cases and room-shard load tests. |
| WebSocket movement + emotes | 80% | Authenticated WS join, room fanout, movement interpolation, RO-style overhead emotes, repeatable 24/50/100-client load smoke, slow/failed write metrics, failed-write close policy, and dense-room move interval backoff. | Distance-based interest management and Redis-mode load tuning. |
| Room chat | 74% | Ephemeral room chat, channel picker, chat invite actions, report path, moderation console. | Abuse tuning, mute UX, and live operator workflow hardening. |
| Private messages + mail | 68% | Durable private conversations, unread summaries, read markers, report endpoint, mailbox base. | End-to-end persistence policy, notification UX, inbox pagination polish. |
| Player profile / social actions | 62% | Member and remote-avatar profile card, private/visit/emote/report actions wired. | Friend/block/follow model and richer profile identity fields. |
| Housing | 70% | Server-authoritative catalog, spend/refund, owner/visitor modes, H5 screenshots. | Multiplayer room decoration sync and richer build catalog. |
| Economy | 64% | Wallet, ledger, trusted spends, trusted fishing reward grants, idempotent reward claims. | Daily caps, creator revenue share, anti-inflation dashboards. |
| Fishing official minigame | 74% | IMinigame sandbox launch, online session create/join/end, server rewards, H5 host flow. | More interaction depth and mobile input feel. |
| Creator minigame platform | 63% | Interface contracts, package intake, async scan/review, publish/unpublish, H5 sandbox. | Creator-facing upload UX, moderation operations, version compatibility tests. |
| LiveOps / moderation | 68% | Admin roles, chat reports, profile reports, moderation audit, debug ops, per-room realtime WS counters, CSV exports. | Real operator auth, alerting, dashboards beyond local H5 tooling. |
| H5 mobile landscape | 60% | Web export, orientation guard, keyboard fallback, key UI screenshot matrix. | Real device input/keyboard QA and asset download budget pass. |
| iOS / Android export | 35% | Architecture is compatible with Godot export constraints. | Signing, store auth providers, real device QA, push/notification decisions. |

Overall MVP implementation forecast: 68-72%.
Public alpha readiness forecast: 58-64%.

## Performance Forecast

| Chain | Concurrency | CPU | Memory | Notes |
| --- | ---: | ---: | ---: | --- |
| Auth / profile REST | 4.0 | 4.0 | 4.0 | Mostly short JSON requests; PostgreSQL token/profile writes are ordinary MVP load. |
| Presence heartbeat | 4.0 | 4.0 | 4.5 | Redis TTL mode keeps online state cheap; heartbeat frequency is the main tuning knob. |
| WebSocket city hub | 3.6 | 3.4 | 3.8 | One connection per client is fine; same-room broadcast cost grows with room population, now capped per room type and tracked globally/per room. |
| Movement sync | 3.5 | 3.3 | 4.0 | Current 0.12s client send interval is playable; server now raises dense-room move limiting to 120ms at 50 joined players, but dense rooms still need distance-based culling. |
| Room chat | 3.8 | 4.0 | 4.2 | Room chat is ephemeral and capped; report snapshots are small. |
| Private messages / mail | 3.5 | 3.7 | 3.8 | Durable rows are manageable; pagination and retention policies decide long-term storage cost. |
| Housing | 3.6 | 3.8 | 3.7 | Catalog validation is light; layout size and sync frequency are the future pressure points. |
| Fishing rewards | 4.2 | 4.4 | 4.2 | Server reward logic is tiny and idempotent; Redis request keys add predictable TTL memory. |
| Creator package review | 2.8 | 3.0 | 3.0 | Async path avoids blocking uploads, but LLM review and package artifacts need queue/backpressure. |
| LiveOps/admin | 3.8 | 4.0 | 4.0 | Low user count path; CSV export should stay paged for production. |
| H5 client runtime | 3.0 | 3.0 | 3.2 | Server is not the bottleneck; browser canvas/GPU, asset size, and mobile keyboard behavior are. |

## Single-host Forecast

Expected safe alpha envelope before dedicated load tests:
- 300-800 concurrent users spread across rooms: likely safe with current design.
- 50-100 users in one visible room: plausible, but movement fanout and client readability become the limit.
- 1,000-2,000 concurrent users across many rooms: possible on the target host after Redis mode, OS limits, WS buffers, and Postgres pooling are tuned.
- Creator package review throughput depends on the AI reviewer adapter; keep it asynchronous and queue-limited.

Most likely backend bottlenecks:
- Same-room movement fanout, because every move can broadcast to many clients; dense rooms now back off movement accepts but still need culling for bigger public plazas.
- WebSocket write backpressure from slow clients; failed writes now close the socket, while slow-write thresholds still need production alert tuning.
- PostgreSQL growth from private messages, mail, ledgers, reports, and creator audit history.
- Creator artifact storage if left on local disk without lifecycle policy.

Most likely client bottlenecks:
- H5/mobile asset memory and texture upload cost.
- Dense HUD overlays on 844x390 landscape.
- Godot Web virtual keyboard differences across mobile browsers.

## Measured Smoke Baseline

Current baseline is a functional smoke, not a capacity benchmark:
- Default CI-sized profile: 24 authenticated WebSocket clients join one room through the gateway test server.
- Developer stress profiles: `PSW_WS_LOAD_SMOKE_CLIENTS=50` and `PSW_WS_LOAD_SMOKE_CLIENTS=100` both pass locally.
- Each client sends movement updates; one client intentionally trips movement rate limiting.
- A room chat message is sent through HTTP and fanned out through the room hub.
- `/debug/ops` must show matching online count, opened WS connections, local broadcast count,
  delivery targets, delivered messages, rate-limit hits, and zero write failures.
- Debug Ops UI now exposes WS opened, delivery target, slow write, and failed write counters, plus per-room delivered/target/slow/failed values.
- Deterministic unit coverage now verifies slow-write metrics, failed-write closure, and room-capacity denial payloads.
- Dense-room unit coverage verifies 50-player rooms use a 120ms server-side movement interval.

## Next Performance Tasks

1. Define retention rules for private messages, mail, reports, and ledgers before public alpha.
2. Run a real-device H5/mobile keyboard and FPS pass after the next UI slice.
3. Add distance-based interest culling for 100-player public rooms.
4. Start a Redis-mode WS fanout smoke once local Redis is part of the regular dev loop.
