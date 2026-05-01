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
| WebSocket movement + emotes | 86% | Authenticated WS join, room fanout, movement interpolation, RO-style overhead emotes, repeatable 24/50/100-client load smoke, Redis cross-gateway movement/chat smoke, Redis multi-client two-gateway load profile, slow/failed write metrics, failed-write close policy, dense-room move interval backoff, and distance-based movement culling. | Interest-radius playtest calibration and OS/socket tuning on the Ubuntu target. |
| Room chat | 79% | Ephemeral room chat, channel picker, chat invite actions, report path, moderation console, explicit zero-day room-history retention policy. | Abuse tuning, mute UX, and live operator workflow hardening. |
| Private messages + mail | 88% | Durable private conversations, unread summaries, read markers, report endpoint, mailbox base, block enforcement, paged conversation/inbox APIs, retention windows, cleanup dry-run command, and daily systemd cleanup timer. | Notification UX and production retention dry-run review. |
| Player profile / social actions | 76% | Member and remote-avatar profile card, private/visit/emote/report/follow/block actions wired; backend follow/block state persists in memory/PostgreSQL and blocks private sends. | Richer profile identity fields and friend-list UI. |
| Housing | 82% | Server-authoritative catalog, spend/refund, owner/visitor modes, realtime layout-update broadcasts to home rooms, and H5 screenshots. | Richer build catalog and decoration UX depth. |
| Economy | 90% | Wallet, ledger, trusted spends, trusted fishing reward grants, idempotent reward claims, creator revenue share policy, owner-only idempotent creator settlement endpoint, daily reward soft cap, and Debug Ops cap/creator-payout counters. | Per-game payout drilldowns and production alert thresholds. |
| Fishing official minigame | 74% | IMinigame sandbox launch, online session create/join/end, server rewards, H5 host flow. | More interaction depth and mobile input feel. |
| Creator minigame platform | 75% | Interface contracts, mode/runtime compatibility validation, package intake, async scan/review, publish/unpublish, H5 sandbox, and creator payout settlement contract. | Creator-facing upload UX, moderation operations, and compatibility fixtures for more content packs. |
| LiveOps / moderation | 84% | Admin roles, chat reports, profile reports, moderation audit, debug ops, per-room realtime WS counters, retention/economy policy visibility, creator payout/cap-hit counters, cleanup-plan metadata, cleanup runner, timer packaging, CSV exports. | Real operator auth, alerting, dashboards beyond local H5 tooling. |
| H5 mobile landscape | 60% | Web export, orientation guard, keyboard fallback, key UI screenshot matrix. | Real device input/keyboard QA and asset download budget pass. |
| iOS / Android export | 35% | Architecture is compatible with Godot export constraints. | Signing, store auth providers, real device QA, push/notification decisions. |

Overall MVP implementation forecast: 94-96%.
Local code-verifiable MVP closure: 100% for the current automated smoke gate.
Public alpha readiness forecast: 74-78%.

## Performance Forecast

| Chain | Concurrency | CPU | Memory | Notes |
| --- | ---: | ---: | ---: | --- |
| Auth / profile REST | 4.0 | 4.0 | 4.0 | Mostly short JSON requests; PostgreSQL token/profile writes are ordinary MVP load. |
| Presence heartbeat | 4.0 | 4.0 | 4.5 | Redis TTL mode keeps online state cheap; heartbeat frequency is the main tuning knob. |
| WebSocket city hub | 3.8 | 3.6 | 3.9 | One connection per client is fine; same-room broadcast cost grows with room population, now capped per room type, tracked globally/per room, and verified across two Redis-backed gateway instances including a configurable multi-client profile. |
| Movement sync | 3.9 | 3.7 | 4.0 | Current 0.12s client send interval is playable; server now raises dense-room move limiting to 120ms, culls distant move recipients at 50 joined players, and has cross-gateway Redis fanout plus multi-client smoke coverage. |
| Room chat | 3.8 | 4.0 | 4.2 | Room chat is ephemeral and capped; report snapshots are small. |
| Private messages / mail | 4.1 | 4.0 | 4.1 | Durable rows are manageable; retention windows now have a dry-run/execute cleanup command plus a daily systemd timer, and conversation/mailbox reads are paged. |
| Housing | 3.7 | 3.8 | 3.8 | Catalog validation is light; mutation-triggered room broadcasts avoid polling, while layout size and sync frequency remain the future pressure points. |
| Fishing rewards | 4.2 | 4.4 | 4.2 | Server reward logic is tiny and idempotent; Redis request keys add predictable TTL memory. |
| Creator package review | 3.1 | 3.2 | 3.1 | Async path avoids blocking uploads; payout settlement, mode runtime compatibility, and artifact staging windows are now contracted, while queue/backpressure is still needed. |
| LiveOps/admin | 4.0 | 4.0 | 4.0 | Low user count path; Debug Ops now includes creator payout and reward cap-hit counters, while CSV export should stay paged for production. |
| H5 client runtime | 3.0 | 3.0 | 3.2 | Server is not the bottleneck; browser canvas/GPU, asset size, and mobile keyboard behavior are. |

## Single-host Forecast

Expected safe alpha envelope before dedicated load tests:
- 300-800 concurrent users spread across rooms: likely safe with current design.
- 50-100 users in one visible room: plausible, but movement fanout and client readability become the limit.
- 1,000-2,000 concurrent users across many rooms: possible on the target host after Redis-mode load profiles, OS limits, WS buffers, and Postgres pooling are tuned.
- Creator package review throughput depends on the AI reviewer adapter; keep it asynchronous and queue-limited.

Most likely backend bottlenecks:
- Same-room movement fanout, because every move can broadcast to many clients; dense rooms now back off movement accepts and cull distant recipients, while Redis cross-gateway fanout has smoke coverage but still needs larger stress testing.
- WebSocket write backpressure from slow clients; failed writes now close the socket, while slow-write thresholds still need production alert tuning.
- PostgreSQL growth from private messages, mail, ledgers, reports, and creator audit history; paged reads and daily retention cleanup now control the first growth risks, but production dry-runs should be reviewed before first execution.
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
- Debug Ops UI now exposes economy ledger totals, creator reward counts, creator revenue coins, and reward cap hits.
- Durable private conversation, private message detail, and mailbox inbox endpoints now support `limit` + `offset` pagination.
- Housing mutations broadcast `housing.layout.updated` to `home:<owner_id>` so owner/visitor rooms refresh without polling.
- Creator package validation now rejects `runtime_contract` values that do not match the selected `mode_id`.
- Deterministic unit coverage now verifies slow-write metrics, failed-write closure, and room-capacity denial payloads.
- Dense-room unit coverage verifies 50-player rooms use a 120ms server-side movement interval.
- Dense-room culling coverage verifies far movement recipients are skipped and `movement_culled` appears in realtime room metrics.
- Redis gateway smoke starts two independent gateway instances against one Redis backend and verifies cross-instance `player.move`, `chat.message`, fanout counters, and zero write failures.
- Redis multi-client smoke spreads clients across two gateway instances in one room, sends movement and chat, and asserts combined online count, fanout publish/receive, zero write failures, and zero fanout publish failures. Use `PSW_WS_REDIS_LOAD_SMOKE_CLIENTS` to scale the profile up to 80 clients.
- Current H5 UI matrix with backend ops enabled passes with 35 screenshots, 0 console messages, and ports clear.

## Next Performance Tasks

1. Run a real-device H5/mobile keyboard and FPS pass after the next UI slice.
2. Calibrate movement interest radius from H5/desktop playtests.
3. Add per-game creator payout drilldowns and alert thresholds.
4. Run a production-like retention cleanup dry-run against PostgreSQL seed data.
