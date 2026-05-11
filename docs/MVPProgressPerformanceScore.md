# MVP Progress and Performance Forecast

Date: 2026-05-11

Scope: current Godot 4 + Go backend MVP on the planned single Linux amd64 host
(Ubuntu 26.04 LTS, i9-13900KF, 64GB RAM), before production load testing.

Scoring:
- MVP progress: 0-100%, based on implemented and verified slices. The local
  MVP closure gate is separate from public alpha readiness because store
  signing, real-device QA, and production credentials cannot be honestly
  completed on the local machine alone.
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
| Housing | 85% | Server-authoritative catalog, spend/refund, owner/visitor modes, realtime layout-update broadcasts to home rooms, H5 screenshots, and Android low-wallet catalog rejection are verified. | Richer build catalog, clearer owned-vs-purchasable catalog affordances, and decoration UX depth. |
| Economy | 100% pre-device | Wallet, ledger, trusted spends, trusted fishing reward grants, idempotent reward claims, real dual-player trade purchase E2E, server trade event history, creator revenue share policy, owner-only idempotent creator settlement endpoint, daily reward soft cap, Debug Ops cap counters, per-creator/per-game payout drilldowns, ledger tamper smoke, inventory audit smoke, and backend E2E wallet/ledger coverage. | Production threshold calibration now moves to live-data tuning after true-device/prod-like testing. |
| Fishing official minigame | 74% | IMinigame sandbox launch, online session create/join/end, server rewards, H5 host flow. | More interaction depth and mobile input feel. |
| Creator minigame platform | 100% pre-device | Interface contracts, mode/runtime compatibility validation, package intake, async scan/review, publish/unpublish, H5 sandbox, creator payout settlement contract, operator payout drilldown by creator/game, reviewer console smoke, backend reviewer E2E, package publish/unpublish E2E, catalog verification, audit CSV verification, and fixture coverage for supported creator modes. | Real creator upload UX usability and more content fixtures move to post-device polish, not MVP gate blockers. |
| LiveOps / moderation | 100% pre-device | Admin roles, chat reports, profile reports, moderation audit, unified high-risk admin action audit, trade history audit with CSV handoff, debug ops, per-room realtime WS counters, retention/economy policy visibility, creator payout/cap-hit counters, creator payout drilldowns, cleanup-plan metadata, cleanup runner, timer packaging, CSV exports, initial alpha alert thresholds, `/debug/ops.alerts` wiring, trade risk alerting, lightweight alert forwarding, Ubuntu systemd alert probe packaging, LiveOps smoke, chat reports smoke, chat moderation audit smoke, reviewer backend E2E, and H5 small-screen semantic coverage. | Real operator identity provider, external audit sink, and monitoring receiver are production-environment validation items. |
| H5 mobile landscape | 92% device-verified | Web export, orientation guard, shared keyboard fallback, trade price input guard, Android Chrome `notranslate` shell patch, true-device chat/private/trade keyboard screenshots, 21-state priority screenshot matrix, 64-screenshot generated-map patrol, and semantic PNG checks. | Remaining work is broader browser/device coverage and asset download budget pass. |
| iOS / Android export | 92% device-verified | Native presets, Image 2 store branding assets, iOS toolchain detection, Android SDK/JDK/build-tools/CMake/NDK setup, accepted Android licenses, native preset parse checks, locally signed/pruned Android debug APK export, APK asset-budget guard, streamed adb install/launch, Android online auth/presence/WS, landscape login/main-city/housing/fishing/tap-to-move/chat/trade keyboard smoke, Android runtime perf v1.1, Android package budget v1, Android UI interaction polish v1, Android device interaction QA v2, Android stability probe v1, native render throttle v1, and full Android device regression are verified. | Release signing, iOS true-device pass, store auth providers, push/notification decisions, and longer soak/load profiling. |

Overall local MVP closure: 100%.
Pre-device automated smoke gate: 100%, passed on 2026-05-07 via `scripts/run_mvp_100_gate.sh`.
Public Alpha pre-device readiness: 100% for the local automated scope.
Public Alpha release readiness: awaiting true-device, store-auth, signing, and production-monitoring verification.

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
| LiveOps/admin | 4.5 | 4.1 | 4.0 | Low user count path; Debug Ops now includes creator payout, reward cap-hit counters, bounded admin action audit stats, paged trade CSV export, creator/game payout drilldowns, alpha alert summary rows, trade risk counters, a lightweight alert/metrics forwarding endpoint, and an Ubuntu systemd timer probe sample. |
| H5 client runtime | 3.0 | 3.0 | 3.2 | Server is not the bottleneck; browser canvas/GPU, asset size, and mobile keyboard behavior are. |
| Android client runtime | 3.7 | 4.0 | 3.4 | True-device debug build now caps mobile rendering at 24 FPS, runs physics at 30 ticks per second, enables low-processor sleep, idles avatar/nameplate/remote interpolation processing, and pauses closed realtime polling. The 240-second route probe on `c7e94055` improved CPU to 23.5% avg / 32% max with stable memory: 335.1 MB avg PSS, 361.5 MB max PSS, -45.1 MB PSS growth, and 0.5 MB max swap PSS. APK size remains 147.3 MB after pruning generated source caches, Android-excluded launch splash payloads, and retired map candidates. |

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
- Native texture memory from the Image 2 map library; package source-cache bloat is now guarded by the Android APK asset-budget script.
- Dense HUD overlays on 844x390 landscape.
- Godot Web virtual keyboard differences across mobile browsers.

## Measured Smoke Baseline

Current baseline is a functional smoke, not a capacity benchmark:
- Default CI-sized profile: 24 authenticated WebSocket clients join one room through the gateway test server.
- Developer stress profiles: `PSW_WS_LOAD_SMOKE_CLIENTS=50` and `PSW_WS_LOAD_SMOKE_CLIENTS=100` both pass locally.
- Android true-device smoke on `c7e94055`: landscape login, online auth/presence/WS through `adb reverse`, main city, housing, fishing cast/finish reward, Trade Market open/post/cancel, tap-to-move/hotspot travel, soft-keyboard guard, strict package crash/script log scan, Android runtime perf v1.1, Android asset budget v1, Android UI interaction polish v1, and Android device interaction QA v2 pass locally. Main-city screenshots are stored under `.tools/android-device-smoke/current/`, latest polish screenshots under `.tools/android-ui-polish-v1-*.png`, and v2 screenshots under `.tools/android-v2-qa/`.
- Android native render throttle v1 on `c7e94055` passes a 240-second route stability probe and full device regression after reinstall. Stability evidence is under `.tools/android-stability-render-throttle-v1/`; regression evidence is under `.tools/android-regression-render-throttle-v1/`.
- Android compact trade priority smoke on `c7e94055` now verifies Trade Market sync, listing post, immediate visible `Cancel` in the `Mine` filter, listing cancel, and immediate visible `Post` in the `Sell` filter. Screenshots are stored under `.tools/android-trade-priority/`.
- Each client sends movement updates; one client intentionally trips movement rate limiting.
- A room chat message is sent through HTTP and fanned out through the room hub.
- `/debug/ops` must show matching online count, opened WS connections, local broadcast count,
  delivery targets, delivered messages, rate-limit hits, and zero write failures.
- Debug Ops UI now exposes WS opened, delivery target, slow write, and failed write counters, plus per-room delivered/target/slow/failed values.
- Debug Ops UI now exposes economy ledger totals, creator reward counts, creator revenue coins, and reward cap hits.
- LiveOps Audit UI now exposes bounded admin action audit rows, and the selected H5 Audit screenshot pass covers 960x540 plus 375x240 with no console messages.
- Trade price entry now participates in the shared compact mobile keyboard guard and has an H5 online trade-market screenshot case that seeds sellable stock before focused numeric entry.
- Real backend E2E now covers a two-account trade sale: listing escrow lock, self-buy/cross-cancel denial, buyer purchase, wallet transfer, inventory delivery, seller ledger, and sold-listing replay guards.
- The trade GORM layer now has an opt-in PostgreSQL persistence E2E gated by `PSW_POSTGRES_TEST_DSN`; it checks restart-style service reconstruction around purchase plus wallet, ledger, inventory, and replay guards.
- Trade now has a local concurrent double-buy regression plus a DSN-gated PostgreSQL race test; both require one winner, one inactive loser, one wallet transfer, and no duplicate inventory delivery.
- Trade player feedback now distinguishes insufficient funds, race-lost sold listings, closed cancels, escrow drift, locked stock, auth, and connection failures in the visible Trade Market panel.
- Trade Market rows now pre-disable unaffordable buys, show missing-coin state, clarify locked sellable stock, and pass refreshed desktop/mobile H5 screenshots after Web export.
- Trade Market live rows now render in player-action priority order: wallet, affordable buys, own listings, sellable stock, locked stock, short-on-coins rows, then static guidance.
- Trade Market row composition is now isolated in a reusable helper under the GDScript line budget, and the market hotspot explains the live board instead of showing stale "preparing" copy.
- Trade Market now has compact `All/Buy/Mine/Sell` filtering plus a manual refresh action with localized fresh-board feedback, keeping player trade management usable on small landscape screens.
- Trade filters now show localized empty states and reset the board scroll after filter/refresh/mutation flows, so the player is not stranded in stale list positions after trade actions.
- Trade action results now surface as compact in-panel outcome rows for posted, bought, cancelled, and failed attempts, improving player confidence without adding extra overlays.
- Trade action execution is now split out of the main panel, and successful outcome rows surface concrete purchase spend, wallet balance, listing price, or returned escrow item when the backend response includes those fields.
- Android player-route closure now verifies the three high-risk player economy loops on device: Home owned-inventory placement with a low wallet, Trade post/cancel with escrow return, and Fishing reward grant with HUD wallet sync. The latest package-scoped logcat scan after those routes is clean.
- Trade Market now shows a compact sync-state chip and failed outcomes include an in-row Sync recovery action, improving player confidence after stale listings or race-lost attempts without increasing overlay footprint.
- Trade filter labels now include live action counts for all/buy/mine/sell, helping small-screen players avoid switching into empty board states.
- Trade Market now keeps a compact latest-three outcome history under the wallet row and moved outcome construction into a helper, reducing toolbar complexity while preserving visible transaction confidence.
- Trade now persists server-side create/sale/cancel event history and exposes a read-only `/trade/history` endpoint that the Trade Market renders as latest-three backend history rows.
- LiveOps now has a read-only trade history audit panel backed by `/admin/trade/history`, with filters for event type, player, item, listing, seller, and buyer.
- Trade history audit now supports paged CSV export, and alpha LiveOps risk thresholds are captured in `docs/LiveOpsRiskThresholds.md`.
- Debug Ops now emits and renders `/debug/ops.alerts` for the wired alpha risk subset: trade race/stale listing attempts, trade cancel ratio, high-price active trade listings, trade settlement failures, reward caps, failed writes, movement culling ratio, open reports, and missing high-risk admin notes.
- `/debug/ops/alerts` now exposes the alert snapshot as a lightweight admin endpoint, supports `format=prometheus`, writes structured `liveops_alert_snapshot` logs for warning/critical states, and ships with a one-minute Ubuntu systemd probe timer sample.
- Creator payout rows now carry `game_id`, `/debug/ops.creator_payouts` summarizes top creator/game revenue rows, and `/admin/economy/creator-payouts` provides a read-only operator drilldown.
- Durable private conversation, private message detail, and mailbox inbox endpoints now support `limit` + `offset` pagination.
- Housing mutations broadcast `housing.layout.updated` to `home:<owner_id>` so owner/visitor rooms refresh without polling.
- Creator package validation now rejects `runtime_contract` values that do not match the selected `mode_id`.
- Deterministic unit coverage now verifies slow-write metrics, failed-write closure, and room-capacity denial payloads.
- Dense-room unit coverage verifies 50-player rooms use a 120ms server-side movement interval.
- Dense-room culling coverage verifies far movement recipients are skipped and `movement_culled` appears in realtime room metrics.
- Redis gateway smoke starts two independent gateway instances against one Redis backend and verifies cross-instance `player.move`, `chat.message`, fanout counters, and zero write failures.
- Redis multi-client smoke spreads clients across two gateway instances in one room, sends movement and chat, and asserts combined online count, fanout publish/receive, zero write failures, and zero fanout publish failures. Use `PSW_WS_REDIS_LOAD_SMOKE_CLIENTS` to scale the profile up to 80 clients.
- Current H5 matrix passes with 151 screenshots, 0 console messages, semantic PNG checks, and ports clear after the compact trade priority change. A focused 2026-05-10 H5 keyboard guard pass also verifies trade price, chat, and private-message input screenshots plus semantic PNG checks; Android device `c7e94055` now also verifies Gboard-open trade price entry with the input and `Post` action above the keyboard.
- Local Android debug export now produces `builds/android/pixel_social_world-debug.apk`, prunes development-only payload paths, removes generated source cache payloads and retired Android map/branding payloads, runs `zipalign`, re-signs with the local debug keystore, passes APK Signature Scheme v2/v3 verification, and enforces a 220 MB debug APK budget. Latest APK: 147.3 MB.
- MVP 100 Gate V1 passed locally on 2026-05-07. It now includes the expanded pre-device closure suite: full Go backend tests, content validation, localization syntax, broad Godot smokes across Economy/Creator/LiveOps/UI/map/minigame chains, fresh-instance backend E2E scripts, H5 runtime gate, screenshot matrix, PNG semantic screenshot checks, GDScript line budget, and whitespace checks.

## Next Performance Tasks

1. Broaden H5/mobile device coverage beyond the current Android Chrome true-device keyboard pass, especially alternate keyboard layouts and lower-height landscape viewports.
2. Configure external release signing values for Android and iOS without committing secrets.
3. Wire the systemd LiveOps alert probe output to the final external monitoring receiver.
4. Run `PSW_POSTGRES_TEST_DSN=... go test ./internal/trade -run 'TestPostgresTradePurchasePersistsLedgerInventoryAndReplayGuards|TestPostgresConcurrentPurchaseAllowsOneBuyer' -v` against the Ubuntu/Postgres target before public alpha.
