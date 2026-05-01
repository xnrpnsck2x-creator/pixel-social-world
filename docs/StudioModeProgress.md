# Studio Mode Progress

## Active Goal

Reduce the three largest risks in order:

1. Product risk: MVP scope too wide.
2. Engineering risk: offline stubs can drift away from online architecture.
3. Art risk: no unified pixel UI and missing asset paths.

Strategic source now lives in `docs/StrategicPlan.md`, based on the updated
root `AGENTS.md` and `game_design_bible.md`.
Accelerated content execution now lives in `docs/AcceleratedContentRoute.md`.

## Progress

### Alpha RC Local Test Harness

Status: Implemented and locally verified on 2026-05-02.

- Added `scripts/run_local_alpha.sh`, a one-command local Alpha harness that builds the backend, runs local preflight, serves the current H5 export, writes a runtime config for the selected ports, prints player/admin URLs, and cleans ports on exit.
- Added `docs/AlphaRCTestPlan.md` with player, two-client, LiveOps, mobile browser, and known-external test steps for the upcoming hands-on pass.
- Tightened strict backend preflight so production auth must use `oidc_jwt` and include Apple/Google client ID lists before the server is considered production-safe.
- Verified with shell syntax checks, content validation, full Go backend tests, local Alpha non-interactive readiness, and the 34-state H5 screenshot matrix: 0 console messages, ports clear.

### MVP Autopilot Slice 8 - Local MVP Closure Gates

Status: Implemented and locally verified on 2026-05-01.

- Added `limit` + `offset` pagination for private conversation summaries, private conversation history, and mailbox inbox reads across memory, PostgreSQL, REST, and Godot/H5 client wrappers.
- Added room-scoped `housing.layout.updated` broadcasts after server-authoritative housing place/style/move/remove mutations, and wired the housing room screen to apply live layout updates.
- Added economy Debug Ops counters for total ledger events, grant/spend totals, reward cap hits, creator play rewards, creator revenue-share events, and creator revenue coins.
- Tightened creator mode compatibility by validating `runtime_contract.camera`, `runtime_contract.input_profile`, and `runtime_contract.network_profile` against the selected `mode_id` in both Go intake and Godot manifest validation.
- Updated backend contracts, creator spec, content validation, LiveOps smoke data, and progress forecasts toward a local code-verifiable MVP closure pass.
- Verified with content validation, full Go backend tests, targeted Godot smoke suite, Web export, and the H5 screenshot matrix with backend ops enabled: 35 screenshots, 0 console messages, ports clear.

### MVP Autopilot Slice 7 - Retention Cleanup and Economy Caps

Status: Implemented and locally verified on 2026-05-01.

- Added `pixel-social-world-retention-cleanup`, a dry-run-by-default PostgreSQL retention runner that executes the `/debug/ops` cleanup plan and keeps room chat untouched.
- Added a daily `pixel-social-world-retention-cleanup.timer` plus release/install packaging so Ubuntu 26.04 deployments carry the cleanup binary and systemd units.
- Added `daily_soft_cap` to the backend economy policy, YAML/env config, validation, `/economy/policy`, trusted grants, fishing rewards, and creator settlement.
- Fishing and creator rewards now return the actual granted delta after caps, preventing the UI from showing coins that were not actually added.
- Verified with full Go backend tests, content validation, shell syntax checks, Linux amd64 backend build, and cleanup command dry-run.
- Raised the MVP forecast from roughly 80-84% to 84-88% by turning retention policy into an executable ops path and closing the first anti-inflation cap.

### MVP Autopilot Slice 6 - Social Trust, Retention, and Creator Payouts

Status: Implemented; verification in progress on 2026-05-01.

- Added backend follow/block relationship state with memory and PostgreSQL implementations.
- Player profile cards now expose Image 2 framed Follow and Block actions; follow/block requests route through `OnlineClient`, `WorldHUDActionsController`, and localized HUD feedback.
- Private messages now respect relationship blocks and return `private_message_blocked` instead of creating durable rows.
- Added creator revenue-share policy (`creator_share_bps`) plus an owner-only trusted settlement endpoint that writes player reward and creator payout ledger entries together, using `source_id` as an idempotency key.
- Added explicit retention policy config: room chat stays zero-day ephemeral, while private messages, mailbox, reports, ledgers, creator audit rows, and artifact staging windows are visible in `/debug/ops`.
- Added a non-destructive retention cleanup plan to `/debug/ops` so ops tooling can see which durable tables will be pruned and verify that room chat remains memory-only.
- Added a Redis multi-client two-gateway load profile so realtime fanout is no longer verified only by a two-socket cross-instance smoke.
- Raised the MVP forecast from roughly 68-72% to 80-84% by closing social trust, creator economy, retention policy/cleanup planning, and Redis-mode load-risk slices.

### MVP Autopilot Slice 3 - Room Capacity and Backpressure

Status: Implemented and locally verified on 2026-05-01.

- Added backend room-capacity policy knobs for main city, housing, minigame, and custom rooms, with conservative alpha defaults of 100 / 20 / 16 / 50.
- Enforced capacity at WebSocket `world.join`, returning `room.denied` with `room_capacity_full` before assigning a socket to an overfull room.
- Added deterministic slow-write and failed-write coverage; failed WebSocket writes now close the socket so the read loop can retire the player and emit normal room leave cleanup.
- Extended `/debug/rooms` and `/debug/ops` visibility with room capacity and failed-write-close counters.
- Wired capacity config through YAML, env overrides, validation, and the production server room hub factory.
- Added client rollback for denied room joins so Godot/H5 room state returns to the last confirmed room instead of keeping an optimistic rejected room.
- Verified on 2026-05-01: content validation, Go test suite, room lifecycle smoke, core Godot smoke, Web export, and H5 viewport matrix pass.

### MVP Autopilot Slice 4 - Dense Room Movement Backoff

Status: Implemented and locally verified on 2026-05-01.

- Split `world.join` handling out of `Hub` so the realtime hub stays below the AGENTS.md 300-line ceiling while room access, capacity, leave cleanup, and join broadcast remain one flow.
- Added first-pass dense-room movement backoff: when a local room reaches 50 joined players, server-side `player.move` accepts no faster than 120ms.
- Kept this intentionally conservative and compatible with existing clients; it reduces 50-100 player fanout pressure before full distance-based interest culling lands.
- Added dense-room movement interest filtering: at 50 joined players, distant move recipients outside a 360-unit radius are skipped while social events remain room-wide.
- Added `movement_culled` metrics to backend realtime snapshots and the LiveOps room drilldown row.

### MVP Autopilot Slice 5 - Redis Gateway Realtime Fanout Smoke

Status: Implemented and locally verified on 2026-05-01.

- Added a gateway-level Redis realtime smoke with two independent HTTP/WebSocket server instances sharing one Redis auth/fanout/rate-limit backend.
- The smoke logs in guests through separate gateway instances, joins both sockets to one room, and verifies `player.move` crosses instances through Redis pub/sub.
- The same smoke sends room chat through HTTP on one instance and verifies `chat.message` reaches the WebSocket on the other instance.
- Realtime ops assertions now cover Redis fanout publish/receive counters and zero write failures at the gateway layer, not just the lower-level room hub.

### MVP Autopilot Slice 2 - Mobile Room Chat and Safe Area

Status: Implemented and locally verified on 2026-05-01.

- Tightened `MainCityRemotePlayers` mobile safe-area spawning so remote avatars no longer appear partly under the top HUD in mobile landscape.
- Fixed `tests/remote_players_smoke.gd` so per-avatar assertions always run, then added mobile viewport coverage and a guard against top-HUD overlap.
- `scripts/run_h5_matrix.sh` now passes through `PSW_H5_CASE`, enabling targeted one-screenshot H5 checks before the full 34-case matrix.
- Mobile compact `OnlineRoomPanel` now preserves the room chat input instead of hiding it, keeping room chat usable on phones while still showing session join/host controls.
- Split compact layout rules into `OnlineRoomPanelLayout`, pulling `OnlineRoomPanel.gd` back to 271 lines and keeping room UI under the AGENTS.md 300-line ceiling.
- Updated mobile Host Fishing H5 click coverage after the compact room chat row shifted the button position.
- Verified on 2026-05-01: content validation, core Godot smoke, mobile input smoke, online room UI smoke, remote players smoke, minigame session service smoke, main city interactions smoke, world state sync smoke, Go test suite, Web export, targeted mobile room/minigame screenshots, full H5 screenshot matrix, and local port cleanup all pass.

### MVP Autopilot Slice 1 - Main City Visual Base

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 driven terrain painter for the main city so the active camera view is built from sliced pixel grass, dirt, stone, water, flower, bush, and tree PNGs instead of flat blockout plaza/path shapes.
- Kept the old Polygon2D ground shapes hidden as scene-reference scaffolding while the runtime art layer now draws through official Image 2 textures.
- Tightened compact HUD presence formatting so mobile landscape keeps the top bar readable without hiding heartbeat state.
- Compact HUD now uses a player-name-only label in the top bar, preventing mobile landscape from clipping the `Player:` prefix into unreadable fragments.
- Extended main-city smoke coverage to fail if terrain rendering loses its Image 2 Sprite2D tile field.
- Added `scripts/run_h5_matrix.sh`, which builds a temporary backend binary for the H5 screenshot matrix so test cleanup owns the actual listener process instead of a `go run` child.
- Screenshot QA caught and fixed the first sparse tile pass: the final terrain layer uses denser Image 2 tile placement plus matched underlay colors so the main city no longer shows dark placeholder cracks.
- Verified on 2026-05-01: content validation, main city interactions smoke, core Godot smoke, mobile input smoke, LiveOps smoke, Web export, full H5 screenshot matrix, Go test suite, and local port cleanup all pass.
- Follow-up risk for the next 12% slice: mobile landscape remote avatars can spawn partly under the top HUD, so camera/member spawn safe-area rules need tightening.

### Room Member Private Entry V1

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 framed member picker inside `OnlineRoomPanel` with a localized Private action for non-local room members.
- Selecting a room member now emits a private-chat request through `OnlineRoomPanel -> WorldHUDActionsController -> SocialMessagesPanel`, opens the private tab, and prefills the selected `player_id`.
- Split member picker behavior into `OnlineRoomPanelMembers` so the room panel stays below the 300-line GDScript ceiling.
- Added `SocialMessagesPanel.open_private_conversation(peer_id)` as the single UI entry point for member-list-to-private-chat routing.
- Screenshot QA caught the first desktop layout as too tall; the member area was compacted to a single selectable list row plus Private button so the room panel no longer clips its housing actions.
- Verified on 2026-05-01: content validation, Go test suite, social messages panel smoke, online room UI smoke, main city interactions smoke, Web export, targeted desktop/mobile room-panel H5 screenshots, and the full H5 screenshot matrix all pass.

### Private Conversations + Unread Polling V1

Status: Implemented and locally verified on 2026-05-01.

- Backend messaging now exposes durable private conversation summaries through `GET /private-messages?player_id=...`, including `peer_id`, latest message, and unread count.
- Added `POST /private-messages/read/:peer_id` and persisted read markers in both memory and PostgreSQL modes, keeping private chat/mail durable while room chat remains ephemeral.
- Godot `OnlineClient` now exposes `fetch_private_conversations()` and `mark_private_read()`.
- `SocialMessagesPanel` now shows a private conversation list above the selected conversation, marks opened private conversations read, and publishes combined mailbox + private unread counts to the HUD badge.
- Split unread polling into `SocialMessagesPanelUnreadController` and private memory helpers into dedicated Go files so the touched UI and messaging files stay within maintainable size.
- H5 debug coverage now includes desktop and mobile landscape private-message panel screenshots in addition to the existing mailbox message panel cases.
- Verified on 2026-05-01: Go test suite, content validation, social messages panel smoke, online messaging backend E2E, Web export, full H5 screenshot matrix, and targeted desktop/mobile private-message H5 screenshots all pass.

### Selective Player Nameplates V1

Status: Implemented and locally verified on 2026-05-01.

- Player and remote-avatar name labels are hidden by default to reduce main-city visual clutter, especially in mobile landscape and crowded presence states.
- `PlayerAvatar` now reveals a nameplate only when the avatar is clicked/tapped, then hides it automatically after a short duration.
- Added explicit `reveal_name` / `hide_name` hooks so future tutorials, inspect panels, or accessibility settings can reuse the same behavior.
- H5 screenshot coverage now includes `h5-mobile-landscape-name-reveal`, pairing a default hidden-name baseline with a clicked-name reveal proof.
- Verified on 2026-05-01: player avatar smoke, remote players smoke, main city interaction smoke, core Godot smoke, online room UI smoke, content validation, Web export, targeted hidden/reveal H5 screenshots, and the full H5 screenshot matrix all pass.

### HUD Layout Controller V1

Status: Implemented and locally verified on 2026-05-01.

- Split right-side panel placement, compact safe areas, top-bar width rules, and player-name trimming into `WorldHUDLayoutController`.
- Reduced `WorldHUD.gd` from 292 lines to 247 lines, leaving room for future HUD events without violating the 300-line GDScript ceiling.
- Kept the Image 2 HUD visual contract unchanged while making messages, utility, and room panels share one layout authority.
- Verified on 2026-05-01: content validation, main city interaction smoke, core Godot smoke, online room UI smoke, social messages panel smoke, Web export, and the full H5 screenshot matrix all pass after the split.

### Message UI Risk Hardening V1

Status: Implemented and locally verified on 2026-05-01.

- Split reusable mailbox/private row rendering into `SocialMessagesPanelRows`, pulling `SocialMessagesPanel` back under the 300-line GDScript ceiling with room for conversation-list work.
- Added a HUD unread badge on the Image 2 mail/social button, with capped `9+` display and smoke coverage for the signal path.
- Tightened compact messages layout by reducing scroll-region height in mobile landscape, keeping the panel above the bottom chat bar.
- Added mobile landscape messages H5 coverage and fixed the mobile Host Fishing H5 click target after the denser HUD shifted the room-panel button location.
- Verified on 2026-05-01: content validation, social messages panel smoke, main city interaction smoke, core Godot smoke, online room UI smoke, online client smoke, Web export, targeted desktop/mobile messages screenshots, targeted mobile minigame-host screenshot, and the full H5 screenshot matrix all pass.

### Player Messages UI V1

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 framed `SocialMessagesPanel` with mailbox and private-message tabs, unread mailbox summary, read receipts, private send, and private report action.
- Added a HUD top-bar mail/social icon that opens the real player messaging surface while preserving the older `WorldUtilityPanel` mail feed as static utility/ops content.
- The main-city mail courier now routes to the real mailbox surface instead of the static utility mail panel.
- Private messages now have backend soft rate limiting at 6 sends per 10 seconds per sender and a participant-scoped `/private-messages/report` endpoint.
- `OnlineClient` now exposes `report_private_message`, and the messaging backend E2E covers private report submission.
- Added `tests/social_messages_panel_smoke.gd` and a `psw_panel=messages` H5 screenshot case.
- Verified on 2026-05-01: content validation, Go test suite, social messages panel smoke, online room UI smoke, main city interaction smoke, core Godot smoke, online client smoke, online messaging backend E2E, Web export, and targeted H5 messages screenshot all pass.

### Private Message + Mailbox Contract V1

Status: Implemented and locally verified on 2026-05-01.

- Added a dedicated backend `messaging` service for durable private conversations and mailbox records, keeping room chat ephemeral and live-only.
- Added authenticated `/private-messages/*` and `/mailbox/*` routes with sender-token checks and recipient-scoped mailbox read protection.
- PostgreSQL mode now migrates messaging records through GORM, while memory mode keeps a matching fast local implementation.
- Godot `OnlineClient` now exposes typed methods for private send/history, mailbox send/inbox, and read receipts.
- Added Go gateway coverage and a new Godot backend E2E script so the messaging contract can be tested without growing the already near-limit main online E2E file.
- `docs/BackendContract.md` and `docs/DataContract.md` now record the final boundary: room chat is not saved, private chat and mailbox use durable sender/recipient scoped storage.
- Verified on 2026-05-01: content validation, Go test suite, online messaging backend E2E against a real local server, core Godot smoke, online client smoke, and Web export all pass.

### Chat Action Router + Ephemeral Room Chat V1

Status: Implemented and locally verified on 2026-05-01.

- Added `ChatActionRouter` as the single client dispatch path for structured chat actions; `join_minigame` now routes through the router before joining and launching a session.
- Room chat persistence is now explicit: `global`, `nearby`, `house`, `party`, and `system` are live/ephemeral channels that do not restore through `/chat/history`.
- Backend memory and PostgreSQL chat services keep ephemeral room messages only transiently for rate limiting, live reports, ops counters, and WebSocket broadcasts.
- `configs/chat_channels.json`, `docs/BackendContract.md`, and `docs/DataContract.md` now record the split: room chat disappears after reconnect/logout, while future private chat and mail must use durable recipient-scoped storage.
- Online backend E2E now asserts that main-city and house room chat history are empty even though sends and live actions still work.
- Verified on 2026-05-01: content validation, Go test suite, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, chat action router smoke, online backend E2E, realtime backend E2E, and Web export pass.

### Clickable Room Invite UI V1

Status: Implemented and locally verified on 2026-05-01.

- Main HUD chat now exposes a small Image 2 pixel invite chip when the latest visible chat action is `join_minigame`.
- Online room panel now shows the same invite chip inside the room chat surface, so players can join from either the chat bar or the room panel.
- Invite clicks route through `WorldHUDChatController -> WorldHUDActionsController -> MinigameSessionService`, preserving the existing `join_minigame` action contract instead of parsing localized text.
- Room session rows now show game, host, player count, status, open slots, and TTL, making open sessions readable before joining.
- Added a local-dev H5 `psw_panel=room_invite` screenshot state that creates a real Fishing session before announcing the invite, matching backend action validation.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, Web export, targeted H5 room invite screenshot, and full 23-case H5 screenshot matrix all pass.

### Cross-Client Room Invite Intent V1

Status: Implemented and locally verified on 2026-05-01.

- Backend chat messages now preserve a sanitized optional `join_minigame` action across the memory service, REST responses, transient room state, and WebSocket `chat.message` broadcasts.
- `OnlineClient.send_chat` and `OnlineClientEndpoints.send_chat` now pass structured chat action metadata from `ChatService` to `/chat/send`.
- Room invite actions stay display-language independent: localized body text remains UI copy, while Join behavior reads `message.action`.
- Online and realtime backend E2E coverage now checks room history policy and action delivery through realtime room broadcasts.
- Verified on 2026-05-01: content validation, Go test suite, Godot room/main-city/core/session smokes, online backend E2E, realtime backend E2E, Web export, targeted H5 room-emote smoke, and full 22-case H5 screenshot matrix all pass.

### Main City Social Intent V1

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanelActions` now owns room-panel action flow for quick emotes, hosting, joining, and housing visits, keeping `OnlineRoomPanel` below the 300-line GDScript limit.
- `ChatService.send_local_message` now accepts safe optional metadata and preserves non-core fields like `action` while protecting message identity fields.
- Room minigame invites now register a structured `join_minigame` action with `game_id` and `session_id`, giving the Join button a stable intent source instead of parsing localized text.
- `OnlineRoomPanelActions.join_preferred_session` now prioritizes the latest room invite action, then falls back to the first open session, then hosts Fishing if no session exists.
- `tests/online_room_ui_smoke.gd` now checks that the room invite creates a `join_minigame` action targeting `local_fishing`.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, Go test suite, Web export, targeted room-emote H5 smoke, and full 22-case H5 screenshot matrix all pass.

### Main City Social Quick Loop V1

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanel` now has Image 2 quick emote buttons for laugh, heart, and exclamation.
- Quick emotes route through `OnlineRoomPanel -> WorldHUDActionsController -> WorldHUD -> EmoteSync -> OverheadEmoteBubble`, so room UI and minigames share the same overhead emote system.
- Hosting Fishing from the room panel now posts a localized room-chat invite before launching the sandbox.
- H5 screenshot coverage now includes `h5-desktop-room-emote`, guarding the room quick-emote row and overhead bubble state.
- The Host Fishing H5 click targets were realigned after the room panel grew, keeping desktop and mobile sandbox-entry screenshots valid.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, localization JSON syntax, Go test suite, targeted room-emote H5 smoke, and full 22-case H5 screenshot matrix all pass.

### Online Room UI V1 + Screenshot QA

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanel` now exposes a true online room surface: localized member rows, heartbeat age, room chat preview/input/send, minigame catalog/session rows, Host/Join, and housing invite/visit controls.
- Added `OnlineRoomPanelFormatter` so room UI string shaping is isolated from node wiring and stays small enough for the 300-line GDScript rule.
- `ChatService` now exposes the active view channel so the room panel can post into the same chat stream shown by the HUD.
- Added local H5 debug panel routing through `psw_panel=shop|mail|notice|creator|room`, letting Playwright open key UI surfaces directly after login.
- `tests/h5_viewport_smoke.mjs` now screenshots desktop shop, mail, notice, creator, room, mobile room, housing, LiveOps, and desktop/mobile Host Fishing sandbox entry in one matrix.
- Screenshot QA caught and fixed two real UI issues: room panel first-layout rules were skipped on desktop, and utility/room overlays needed separate bottom-safe behavior.
- Verified on 2026-05-01: online room UI smoke, main city interaction smoke, Web export, desktop/mobile Host Fishing smoke, and the full 21-case H5 screenshot matrix all pass.

### Runtime Login Gate V1

Status: Implemented and locally verified.

- `configs/app.json` now carries the bundled client `version` used by runtime minimum-version checks.
- `App.get_runtime_gate()` evaluates maintenance mode and `min_client_version` before login creates a guest session.
- `LoginScreen` hides the normal login panel when blocked and shows `RuntimeGatePanel`, an Image 2 skinned pixel panel with localized maintenance/version copy and a refresh action.
- `Boot` waits for `App.initialized` before routing so H5 cannot create the login scene before runtime config and localization finish.
- Added English, Japanese, and Simplified Chinese keys for maintenance and update-required states.
- Added `tests/runtime_gate_smoke.gd` for maintenance, version-block, and compatible-client paths.
- Added `tests/h5_runtime_gate_smoke.mjs` and screenshot-verified the maintenance gate at `.tools/artifacts/h5-runtime-gate-maintenance.png`.

### Runtime Config Layer V1

Status: Implemented and locally verified.

- Added `RuntimeConfigService` as a trusted app-shell autoload.
- `configs/app.json` now points H5 at `/runtime_config.json` with a bundled `configs/runtime_overrides.json` fallback.
- Runtime overrides are intentionally narrow: API/WebSocket endpoints, online/timeout/reconnect tuning, boolean feature flags, maintenance metadata, `min_client_version`, and `web_build`.
- Session storage keys, scene routes, content paths, creator contracts, and minigame contracts are not runtime-overridable.
- `OnlineClient` and `RealtimeClient` subscribe to `App.config_changed` unless tests or tools have manually configured them.
- Added `backend/deploy/runtime_config.funyoru.json`; the free-launch package writes it to `web/runtime_config.json`.
- Installed a local standard Godot 4.6.2 editor under `.tools/godot-standard` for Web export because the system Mono editor cannot export Godot 4 Web.
- Re-exported H5 with the standard editor and copied local `builds/web/runtime_config.json` for local browser smoke.
- Verified on 2026-04-30: content validation, runtime config smoke, Godot smoke, online client smoke, network lifecycle smoke, Go test suite, Web export, package build, and full H5 viewport smoke all pass.

### MVP Completion Check

Status: Updated on 2026-04-30.

- Local playable MVP foundation is roughly 75-81% complete: main city, chat, presence, fishing, coins, housing, Image 2 UI/art bindings, H5 export, chat moderation, and first LiveOps tooling now have automated smoke coverage.
- Public alpha readiness is roughly 59-69% complete: the server contract, runtime gate, ops dashboard, JSON access logs, config preflight, request-id tracing, readiness probes, admin roles, action confirmation, required operator notes, audit export, soft chat rate limiting, executable chat moderation, moderation audit UI, persistent chat reporting, and packaging path are strong, but production deploy, monitoring, real OAuth providers, mobile exports, and store review flows remain outside the verified path.
- Creator-platform foundation is roughly 60-65% complete: interface, mode contracts, validation, async review, install/rollback catalog, and H5 sandbox wiring exist; public creator submission UX and moderation operations are still the big remaining work.
- Art/UI foundation is roughly 65-70% complete: Image 2 UI frames, emotes, housing props, fishing UI, and main-city hotspot slices are wired; full character action sheets, NPC variety, and next minigame assets remain open.

### Strategy Plan

Status: Updated with accelerated route.

- `docs/StrategicPlan.md` now defines the accelerated route from main city v1 to mobile internal test.
- `docs/AcceleratedContentRoute.md` compresses first content expansion into 4-6 weeks and small real-player testing into weeks 8-12.
- The strategy keeps the existing forest/RO-like town as MVP baseline and moves port-city content to a later fishing/harbor expansion.
- Creator games are scoped to interface, validation, async review, and whitelist alpha during the MVP window.
- `docs/MVPRoadmap.md` now points to the strategic source and records the same MVP city/content decision.

### Product Risk

Status: Phase 2 reduced.

- Fishing is now the first enabled MVP minigame.
- `tile_dash` and `sprite_match` are disabled until the core loop is stable.
- Economy and fishing configs exist for the first coin loop.
- The roadmap now defines the first playable slice as login, movement, chat, fishing, coins, housing.
- The fishing loop now has online session launch, server-authoritative rewards, and H5 smoke coverage.
- The fishing loop now has an Image 2 skinned reward/result panel, fish icon reveal, Cast Again action, and localized coin feedback.
- The fishing loop now has config-driven bite timing, localized rarity callouts, and screenshot-verified desktop/mobile H5 reward states.

### Main City Image 2 Hotspots v0

Status: Completed.

- `forest_main_city_tileset_v0` is now sliced into 100 map prop PNGs under `assets/maps/sliced/forest_main_city_tileset_v0`.
- `assets/maps/sliced/forest_main_city_tileset_v0_contact.png` is available for fast visual picking.
- `MainCity.tscn` now uses Image 2 Sprite2D props for Fishing Pier, Home Gate, Games Hall, and Item Shop instead of Polygon2D blockout markers.
- `configs/art_assets.json` registers the map slice set and semantic hotspot art bindings.
- `tests/main_city_interactions_smoke.gd` now fails if main city hotspot art regresses back to blockout markers.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke, main city interactions smoke, online room UI smoke, online client smoke, remote players smoke, world state sync smoke, player avatar smoke, minigame launch flow smoke, Web export, and H5 viewport/Host Fishing smoke all pass.

### Engineering Risk

Status: Phase 2 reduced.

- Startup route now reads `configs/app.json`.
- Post-login route now reads `configs/app.json`.
- Chat now uses configured channels instead of a hardcoded `local` channel.
- Save data now includes a coin balance.
- The client protocol constants now include auth, chat, world, housing, fishing, and economy messages.
- Backend contract documentation now defines the first REST and WebSocket slice.
- Content validation now checks config localization keys and `res://` resource paths.
- Godot headless smoke passes after the routing, HUD, and chat changes.
- REST auth, WebSocket auth, Redis sessions/fanout, trusted fishing rewards, and request-id idempotency are now locally verified.

### Art Risk

Status: Phase 1 reduced.

- Art direction and Image 2 prompt batches are documented.
- Runtime UI and housing paths now resolve to Image 2 PNG assets.
- Fishing reward UI now uses Image 2 panel/button frames and registered Image 2 fish icon slices.
- Housing room top bar, build catalog, visitor list, and house chat controls now use shared Image 2 panel/button/input frames.
- Housing floor, wall, catalog icons, placed furniture, and placement preview now render from registered Image 2 housing prop slices.
- No SVG files remain under `assets/`; prototypes must stay out of runtime configs.

### Housing Edit Polish V1

Status: Implemented and locally verified.

- Placed furniture selection now draws stronger pixel handles plus a small move affordance marker.
- Hovering an empty tile while a placed item is selected now draws a move target preview and validates the target through `HousingService.can_move_item_to()`.
- Housing sell refund now comes from `configs/economy.json` on the client and `housing.sell_refund_rate` / `PSW_HOUSING_SELL_REFUND_RATE` on the backend.
- Sell, move, and undo feedback now explicitly explains the one-step undo rule and configured coin refund.
- `docs/DataContract.md` now documents the economy refund contract.
- `tests/h5_viewport_smoke.mjs` now captures dedicated desktop/mobile housing selected-state screenshots.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke subset, online backend E2E, realtime backend E2E, Web export, and H5 viewport screenshot matrix all pass.

### Fishing Handfeel V1

Status: Implemented and locally verified.

- `configs/fishing.json` now owns bite timing, rarity names, rarity colors, and fish-to-rarity mapping.
- Fishing now plays a cast, bite wait, bite, and reel status sequence before revealing rewards.
- Reward UI now shows localized rarity callouts tinted by config color, with Common darkened for parchment readability.
- Backend `/minigames/fishing/catch` now returns `rarity`; the client falls back to local fish config when an older dev backend omits it.
- Content validation now checks fishing timing, rarity keys, colors, and fish rarity contracts.
- `OnlineRoomPanel` caps session rows in regular and compact layouts so old waiting sessions cannot push Host Fishing out of the tested safe area.
- H5 screenshot smoke now asserts the sandbox top bar pixels for desktop and mobile minigame cases, preventing false-positive screenshots that stay in the room panel.
- Verified on 2026-04-30: content validation, Go test suite, fishing reward UI smoke, online room UI smoke, Web export, and the full 13-state H5 screenshot matrix all pass.

### Creator Mode Contracts V1

Status: Implemented and locally verified.

- `configs/creator_game_modes.json` now defines the first platform mode contracts: casual activity, 2D side-scroller, 2D fighting, war strategy, RPG adventure, tower defense, and battle royale.
- Official and creator minigame manifests now require `mode_id` and `runtime_contract`.
- `IMinigame` exposes default mode and runtime contract methods while keeping the same `SubViewport` sandbox boundary.
- Creator Lab renders the mode contracts from config through existing Image 2 UI frames and registered icons.
- Backend `/minigames/submit` validates supported mode IDs and mode player caps before queuing review.
- Content validation checks mode localization, icon IDs, minigame mode IDs, manifest mode IDs, runtime contracts, and mode player caps.
- `2d_fighting` is a separate creator mode from platforming, with side-view camera, fighting action inputs, authoritative realtime networking, hitbox/hurtbox review focus, and a 4-player alpha cap.
- `tests/h5_viewport_smoke.mjs` now waits for compact mobile lobby layout and clicks the tested Host Fishing touch area before asserting sandbox pixels.
- Verified on 2026-04-30: content validation, Go test suite, minigame contract smoke, online room UI smoke, main city/minigame smoke subset, Web export, and the full 13-state H5 screenshot matrix all pass.

### Creator Submission Draft V1

Status: Implemented and locally verified.

- Backend now exposes player-authenticated `POST /creator-submissions/draft` and owner-scoped `GET /creator-submissions/:id/status`.
- Creator draft submit reuses the same mode, runtime contract, entry scene, main script, asset budget, and player cap validation as admin submit.
- Creator Lab now renders a draft submission status row using existing Image 2 panel/button styling and the `OnlineClient.submit_creator_draft` / `fetch_creator_submission_status` path.
- `templates/creator_mode_fixtures` now contains one internal manifest fixture for every supported mode, all pointing at a shared safe `IMinigame` fixture scene/script for scanner coverage.
- Content validation now checks fixture coverage against every creator mode and scans fixture scripts for forbidden APIs.
- Verified on 2026-04-30: content validation, Go gateway/minigame tests, Godot creator UI smoke, and Web export pass.

### Creator Package Intake V1

Status: Implemented and locally verified.

- Backend now exposes player-authenticated `POST /creator-submissions/package` for JSON package inventory intake so Godot/H5 can exercise the upload path before multipart zip support.
- Package intake validates the same creator metadata contract, scans package file paths, required files, script content, blocked native/script extensions, SVG formal assets, forbidden Godot API patterns, and asset budget overflows.
- Clean packages are stored with a package snapshot, storage key, SHA256-derived digest, scan report, and `needs_review` status; rejected packages are stored with `rejected` status for owner-visible feedback.
- `POST /minigames/:id/review` now supports explicit review actions/status updates for `review_queued`, `needs_review`, `approved`, `rejected`, and `published`.
- Creator Lab now renders a Package Intake Probe row using the same Image 2 panel/button styling and calls `OnlineClient.submit_creator_package`.
- Real backend E2E now submits a package, verifies owner status includes scan data, and approves it with the admin review route.

### Creator Package Zip + Persistence V1

Status: Implemented and locally verified.

- Backend now exposes multipart `POST /creator-submissions/package.zip`; it accepts a zip archive in `package` or `file`, authenticates the `author` field, strips a single common root folder, extracts text/script files, and feeds the same package scanner used by JSON inventory intake.
- Zip intake enforces a 6 MB compressed archive cap and 8 MB uncompressed hard cap before normal manifest `asset_budget_bytes` validation.
- `minigame.NewGormSubmissionService` now persists creator submission records and package scan snapshots to PostgreSQL while delegating live minigame session concurrency to the configured memory/Redis realtime service.
- Production `storage.mode=postgres` now runs `minigame.AutoMigrate` and wraps the current minigame service with the PostgreSQL submission store.
- Go tests cover zip intake with a common root folder, owner-scoped zip submission, rejected scans, review action updates, and package snapshot serialization round trips.

### Async Creator Review Queue V1

Status: Implemented and locally verified.

- `POST /creator-submissions/package` and `POST /creator-submissions/package.zip` now return quickly with `submitted`, while the package scanner runs in an async worker and updates owner-visible status through `submitted -> scanning -> needs_review/rejected`.
- Creator Lab and the real backend E2E now poll `GET /creator-submissions/:id/status` instead of assuming scan completion inside the upload response.
- Async scan updates are guarded so late scanner writes cannot overwrite an admin/AI review status such as `approved`, `rejected`, or `published`.

### Durable Package Review Jobs V1

Status: Implemented and locally verified.

- Creator package submits now save the package artifact through `PackageArtifactStore` before queueing scan work.
- Local/memory mode uses an in-memory artifact store by default; server config wires `FilePackageArtifactStore` under `storage.package_artifacts_dir`.
- PostgreSQL storage now migrates `PackageReviewJobRecord` rows and stores queued/running/retrying/completed job snapshots next to creator submission records.
- Gorm review workers recover due `queued`, `retrying`, and stale `running` jobs and apply retry/backoff for internal artifact load failures.
- Owner status responses now expose package artifact URI and review job state for ops/debug visibility.

### AI Reviewer Adapter V1

Status: Implemented and locally verified.

- Added a pluggable `PackageAIReviewer` boundary inside the minigame service so review logic stays out of gateway handlers and client code.
- Added `pkg/ai.LocalPolicyReviewer` as the first deterministic AI-review adapter. It produces structured notes and blocks external URL / secret-like text patterns before human review.
- Package snapshots now expose optional `ai_review` with reviewer name, approval flag, notes, and review timestamp.
- Clean packages still land in `needs_review`; AI-blocked packages land in `rejected` with an `ai_review_rejected` scan issue for creator-visible feedback.

### Publish / Install Staging V1

Status: Implemented and locally verified.

- Added `PackageInstallStore` so approved creator packages can be promoted from raw artifact storage into a runtime-safe install catalog.
- `published` now requires an approved package, reloadable artifact, clean scan/AI state, and installable file content before the status is returned.
- File install mode writes creator files under `storage.package_install_dir`, plus `install.json`, `catalog_entry.json`, and a per-game `current.json` pointer for rollback-friendly current-version lookup.
- JSON package intake now supports `content_base64` for binary assets; zip intake preserves binary file content for publish/install.
- Backend exposes `GET /minigames/catalog` for the current installed creator catalog.
- Server config and deployment env now include `PSW_PACKAGE_INSTALL_DIR` separately from raw `PSW_PACKAGE_ARTIFACT_DIR`.

### Rollback / Unpublish V1

Status: Implemented and locally verified.

- Added install-store rollback and unpublish operations for both memory and file-backed runtime catalogs.
- `rollback` switches the per-game `current.json` pointer to the previous installed version without exposing historical packages in the client catalog.
- `unpublish` removes the current pointer, returns the admin-facing record to `approved`, and keeps installed package folders available for audit or future tooling.
- `POST /minigames/:id/review` now accepts `{"action":"rollback"}` and `{"action":"unpublish"}` in addition to the existing review and publish actions.
- Backend and H5/Godot E2E helper coverage now checks that unpublished packages disappear from `/minigames/catalog`.

### LLM Reviewer Adapter V1

Status: Implemented and locally verified with LM Studio Qwen3 Coder Next.

- Added `pkg/ai.OpenAICompatibleReviewer` for LM Studio or any OpenAI-compatible `/v1/chat/completions` endpoint.
- Added strict JSON schema response formatting, review prompt rules, timeout config, and local-policy fallback through `pkg/ai.FallbackReviewer`.
- Server config now supports `PSW_AI_REVIEWER_MODE`, `PSW_AI_REVIEWER_BASE_URL`, `PSW_AI_REVIEWER_MODEL`, `PSW_AI_REVIEWER_API_KEY`, and `PSW_AI_REVIEWER_TIMEOUT_SECONDS`.
- Tested `qwen/qwen3-coder-next` through LM Studio locally. The first pass over-blocked `requires_network: true`; the prompt now clarifies that platform-managed network metadata is allowed while direct script networking APIs remain blocked by the scanner.
- Backend E2E passes with `PSW_AI_REVIEWER_MODE=openai_compatible` and model `qwen/qwen3-coder-next`.

### Reviewer Golden Set V1

Status: Implemented and locally verified.

- Added a provider-agnostic golden set in `pkg/ai` covering safe creator packages for all seven mode IDs plus blocked external URL, secret-like text, token-like text, filesystem scan issue, and root-node scan issue cases.
- Local policy runs the golden set in normal Go tests.
- Live LLM golden tests are opt-in through `PSW_RUN_LLM_GOLDEN=1`, so CI and local backend tests do not accidentally start a large model.
- Codex remains suitable for Studio Mode manual/second-pass review, but backend automation stays env-configured and does not rely on interactive OAuth login.

### Utility Backend V1

Status: Implemented and locally verified.

- Added `backend/internal/utility` as the backend source for main-city shop, mail, and notice panels.
- Added authenticated `GET /utility/panels`, `/utility/shop`, `/utility/mail`, and `/utility/notices` endpoints.
- Server config now supports `PSW_UTILITY_PANELS_CONFIG_PATH`; local and production YAML load the shared `configs/utility_panels.json`.
- `OnlineClient` can fetch utility panel data, and `WorldUtilityPanel` prefers backend rows online while preserving the local config fallback for offline/H5 smoke paths.
- Backend E2E now verifies that online shop and mail rows are served by the backend.

### Top Bar Long Name Guard V1

Status: Implemented and locally verified.

- `WorldHUD` now trims long player display names in the top bar while preserving the full localized player label in the tooltip.
- Top bar labels use clip/overrun behavior and fixed compact widths so coin and presence text keep their space under mobile/H5 pressure.
- `tests/online_room_ui_smoke.gd` now verifies long-name shortening and tooltip preservation.

### Backend Boundary Cleanup V1

Status: Implemented and locally verified.

- Split housing catalog loading from grid placement rules: `catalog.go` now owns catalog data/loading and `layout_rules.go` owns validation geometry.
- Split housing gateway surfaces: `housing_handlers.go` now owns layout/invite/visit while `housing_mutation_handlers.go` owns place/style/move/remove and mutation error mapping.
- Go/GDScript source files are currently all under the 300-line project rule, excluding third-party/tool caches.

### Reviewer Dashboard V1

Status: Implemented and locally verified.

- Backend now exposes admin-only `GET /admin/reviewer-dashboard` so humans can compare creator metadata, scanner output, AI review notes, async job state, and publish/install status in one response.
- The dashboard is implemented inside the minigame service boundary for memory, Redis-backed, and PostgreSQL-backed submission services.
- Creator Lab now shows a player-safe Review Signals row using the owner-visible package status, without exposing admin tokens or global queue data in the normal client.
- Backend tests verify admin gating and scanner/AI/job summary fields for a completed async package review.

### Versioned Submission History V1

Status: Implemented and locally verified.

- The minigame service now keeps current `game_id` records and separate `game_id + version` history snapshots, preserving submitted metadata, scan state, AI review data, async job state, and install state per version.
- Memory, Redis-backed, and PostgreSQL-backed submission services implement the same history contract; PostgreSQL now migrates `SubmissionVersionRecord`.
- Backend exposes owner-scoped `GET /creator-submissions/:id/history` for creator status pages and rollback UI without exposing other creators' versions.
- Godot `OnlineClient` has a typed endpoint for submission history so Creator Lab or a future reviewer/status page can consume it directly.

### Creator Status Page V1

Status: Implemented and locally verified.

- Creator Lab now includes a minimal Creator Status Page row with an Image 2 icon/button surface.
- The row refreshes owner-scoped version history through `OnlineClient.fetch_creator_submission_history`, stores the result locally, and summarizes latest version, review status, scan state, AI state, and install state.
- Offline/H5 paths still show local package status or a backend-waiting message, so the Creator Lab remains usable without admin tokens or global queue access.
- Online backend E2E now verifies the real history endpoint returns version records after creator package intake.

### Utility Live-Ops V1

Status: Implemented and locally verified.

- Utility panels now use a thread-safe backend service seeded from `configs/utility_panels.json`.
- Added admin-only `PUT /admin/utility/panels` to replace the running shop, mail, and notice registry without changing Godot UI layout code.
- CORS now allows `PUT` for browser-based admin tools using `X-Admin-Token`.
- Backend tests verify admin gating and that authenticated players receive the updated live-ops shop rows.

### Guest Account Upgrade Contract V1

Status: Hardened and locally verified.

- Added player-authenticated `POST /auth/upgrade` for Apple/Google account binding across iOS, Android, H5, desktop, and PC prep.
- H5 is treated as a first-class platform value; backend also normalizes `web` to `h5` for browser OAuth shells.
- Upgrade preserves the existing `player_id` and returns fresh session tokens, keeping wallet, housing, creator submissions, and room state attached to the same account.
- Godot `OnlineClient.upgrade_guest_account()` now routes account binding through the shared auth/session layer and stores linked account metadata locally.
- Added `auth.ProviderVerifier` with local `claimed` mode for sandbox iteration and production `oidc_jwt` mode for Apple/Google ID token verification through provider JWKS, issuer, audience, expiry, and subject checks.
- Deployment env now includes `PSW_AUTH_PROVIDER_VERIFICATION`, `PSW_APPLE_CLIENT_IDS`, and `PSW_GOOGLE_CLIENT_IDS`; production should set `PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt`.
- Verified with Go auth/gateway tests, `tests/online_client_smoke.gd`, `tests/session_token_store_smoke.gd`, `tests/auth_upgrade_backend_e2e.gd`, and the existing online backend E2E.

### Reviewer Console V1

Status: Implemented and locally verified.

- Added `OnlineClientAdmin` and `OnlineClient.fetch_reviewer_dashboard` / `review_minigame_admin` so Godot/H5 admin tools can call reviewer dashboard and review actions without mixing admin tokens into normal player endpoints.
- Added standalone `ReviewerConsolePanel` with Image 2 panel/button skin, admin-token input, queue summary, review rows, and status-aware actions for approve, reject, publish, rollback, and unpublish.
- Normal Creator Lab remains owner-only and still shows safe review signals/status history without admin controls.
- Added reviewer console UI smoke and backend E2E coverage for dashboard gating, approve, publish, catalog visibility, and unpublish.
- Added `backend/.gdignore` after Web export QA caught ignored backend runtime artifacts being eligible for Godot packaging; client export now keeps backend/test runtime folders outside the H5 resource pack.
- Verified with content validation, Go tests/vet, Godot UI smokes, reviewer/backend E2E, Web export, and the full H5 screenshot matrix.

### Reviewer Audit Trail V1

Status: Implemented and locally verified.

- Every successful admin review action now records a backend audit event with game ID, action, resulting status, source client, timestamp, and an admin-token fingerprint instead of the raw token.
- Memory, Redis-backed, and PostgreSQL-backed minigame services expose the same audit contract; PostgreSQL migrates `ReviewAuditRecord`.
- Backend exposes admin-only `GET /admin/reviewer-audit/:id` so Studio Mode or future H5 admin tools can inspect approval/publish/rollback history outside the normal player UI.
- Backend tests verify audit creation, admin fingerprinting, source preservation, and no admin token leakage.

### Cloudflare Deployment Assessment V1

Status: Completed as an architecture decision.

- Added `docs/CloudflareDeploymentAssessment.md` to define the Cloudflare path for H5, API, WebSocket, database, artifact storage, and future platform options.
- Decision: serve the Godot Web export from Ubuntu through Cloudflare Free CDN/Tunnel on `funyoru.com`, keep the Go backend on Ubuntu 26.04 LTS for MVP, and put Cloudflare DNS/WAF/CDN/Tunnel in front.
- PostgreSQL and Redis remain the MVP durable/realtime stores; D1 is not a drop-in replacement for the current GORM/PostgreSQL model, and KV is not a Redis pub/sub/TTL replacement.
- R2 is the best next Cloudflare storage fit for creator package artifacts and generated asset bundles.
- Durable Objects are a future candidate for room/session WebSocket coordination, but adopting them now would rewrite the current Go room hub and Redis fanout.
- Backend and H5 strategy docs now point at the assessment so deployment discussions have a single source.
- Read-only Cloudflare check confirmed `funyoru.com` is active on the `Free Website` plan, with no existing DNS records or Pages projects.
- Added `docs/CloudflareFreeLaunchRunbook.md` for the free launch path and updated the Web export preset to exclude Image2 `_source.png` production masters from H5.
- Re-exported H5: `index.pck` dropped to about 18 MiB, while `index.wasm` remains about 36 MiB; therefore Pages-only hosting is deferred unless R2 or a Pages asset limit increase is used.
- Confirmed `_source.png` assets are recoverable because they still live under `assets/**/generated/`; only Web export packaging excludes them.
- Added `backend/deploy/Caddyfile.funyoru.example` and `backend/deploy/cloudflared-funyoru.yml.example` for the Ubuntu static H5 + Cloudflare Tunnel launch path.
- Documented the R2 decision: keep disabled for strict free launch, enable R2 Standard later for creator artifacts or `assets.funyoru.com` large-binary offload, and defer Workers/Durable Objects paid-plan work until realtime edge migration is justified.
- Added `backend/scripts/package-cloudflare-free-launch.sh` to build and package the current H5 export, Linux backend binary, runtime configs, and deploy samples into `.tools/releases/`.
- Added `backend/scripts/smoke-funyoru-public.sh` for public H5/API smoke after the Tunnel hostnames are live.
- Added `backend/deploy/install-funyoru-origin.sh` so an expanded release bundle can lay out `/opt/pixel-social-world`, `/etc/pixel-social-world`, Caddy examples, cloudflared examples, and the backend systemd unit on Ubuntu.
- Updated production binding defaults to `127.0.0.1:8080` for H5 static serving and `127.0.0.1:8787` for the Go backend so the project can coexist with another game already using the server's fixed IP and public `80/443` domain.
- Updated the production Redis default to `PSW_REDIS_DB=5` and documented that a dedicated Redis instance is safer if the existing game also uses Redis Pub/Sub.
- Added `RuntimeConfigService` and `configs/runtime_overrides.json` so H5 can apply a narrow `/runtime_config.json` override for API endpoints, timeout tuning, feature flags, maintenance metadata, and build metadata without rebuilding the Godot package.
- Added `backend/deploy/runtime_config.funyoru.json`; the free-launch package script copies it to `web/runtime_config.json` for `funyoru.com`.
- `OnlineClient` and `RealtimeClient` now listen for app config changes unless a test or tool has manually configured them.

## Next Queue

1. Transfer `.tools/releases/pixel-social-world-funyoru-free-launch.tar.gz` to the Ubuntu host and expand it into `/opt/pixel-social-world`.
2. Create Tunnel hostnames for `funyoru.com`, `www.funyoru.com`, and `api.funyoru.com`, then run `backend/scripts/smoke-funyoru-public.sh`.
3. Add R2-backed package artifact store after local creator review flow stays green, or earlier if Pages + `assets.funyoru.com` becomes the chosen H5 route.

### Utility PostgreSQL Persistence V1

Status: Implemented.

- Added `utility_panel_records` as the PostgreSQL-backed active registry for main-city shop, mail, and notice rows.
- `storage.mode=postgres` now runs `utility.AutoMigrate` and replaces the static utility service with `utility.NewGormService`.
- First PostgreSQL boot seeds from `configs/utility_panels.json`; later `PUT /admin/utility/panels` updates survive backend restarts.
- Memory mode remains available for local/offline smoke paths.

### Main City Utility Panels V1

Status: Implemented.

- `configs/utility_panels.json` now defines the first shop stock, mail messages, and town notices as a stable data contract.
- `configs/app.json` registers the utility panel registry under `content_paths`.
- `WorldUtilityPanel` now renders config-driven Image 2 row lists with item icons, localized copy, wallet details, and short action buttons.
- Shop stock previews housing item prices and routes players to Home; the actual coin spend still happens when a room item/style is placed through `HousingService`.
- Inventory now lists local owned/placed housing goods from save data instead of a single text blob.
- Mail and Notice now render first MVP messages from config, including Home and Games actions for future backend replacement.
- `tests/validate_content.py` now validates utility panel item IDs, icon IDs, action IDs, and localization keys.
- `docs/DataContract.md` documents the utility panel registry and the MVP rule that shop rows preview costs while housing placement remains the authoritative coin sink.
- Online room UI smoke verifies inventory, shop, mail, and notice rows; main city interaction smoke verifies shop hotspot stock rendering.
- Verified on 2026-04-30: content validation, Go unit tests, housing smoke, minigame launch flow smoke, fishing reward UI smoke, online room UI smoke, main city interaction smoke, Web export, and the full H5 screenshot matrix all pass.

### Housing Mobile Safe Area V1

Status: Implemented.

- `HousingRoomResponsiveLayout` now owns compact H5/mobile landscape layout decisions for top bar, social panel, catalog bar, room tile size, and renderer safe areas.
- `HousingRoomScreen` remains under the 300-line single-file limit while delegating responsive layout to the helper.
- `HousingRoomSocialPanel` hides chat preview and tightens input/button dimensions in short landscape screens.
- `HousingRoomCatalogBar` reduces catalog height and item button size in compact mode while keeping horizontal scrolling.
- `HousingRoomRenderer` now uses the actual browser/window size for compact layout origin and tile hit-testing, keeping the editable room out from under the right social panel and bottom catalog.
- Removed the old `Polygon2D` floor placeholder from `HousingRoom.tscn`; the room is now fully rendered by the Image 2 housing art path.
- Housing smoke now verifies compact social/catalog behavior so the mobile layout cannot silently regress.
- Verified on 2026-04-30: housing smoke, online room UI smoke, main city interaction smoke, content validation, Go unit tests, Web export, and the full 11-state H5 screenshot matrix all pass.

### H5 Visual Risk Screenshot Pass V1

Status: Implemented.

- `tests/h5_viewport_smoke.mjs` now captures explicit base-world, inventory-panel, room-panel, housing, fishing-reward, and portrait-guard states.
- The screenshot pass caught a real coordinate drift after the inventory button was added; housing clicks now target Home instead of Inventory.
- `WorldHUD` now sizes side overlays from `DisplayServer.window_get_size()` so Web/mobile landscape uses the real browser viewport.
- `OnlineRoomPanel` has a compact layout for short landscape screens, keeping the minigame lobby above the bottom HUD buttons.
- Online room UI smoke now verifies compact layout behavior so the panel cannot silently expand back over the HUD.
- Verified on 2026-04-30: content validation, Go unit tests, online room UI smoke, main city interaction smoke, Web export, and the full H5 screenshot matrix all pass.

### Main City V1 Shell Panels V1

Status: Implemented.

- `WorldUtilityPanel` adds Image 2 framed shell surfaces for inventory, shop, mail, and notice without covering the center playfield.
- HUD now exposes an Image 2 backpack action button; merchant/shop hotspot and mail/notice NPC actions route into the utility panel.
- `OnlineRoomPanel` now includes a localized enabled-game catalog row, making the existing session panel the first minigame lobby shell.
- Online room UI smoke verifies inventory shell, lobby catalog, and Image 2 frames; main city interaction smoke verifies shop shell routing.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### World HUD Boundary Split V1

Status: Implemented.

- `WorldHUDChatController` now owns chat input, send behavior, channel picker state, history view switching, and chat log rendering.
- `WorldHUDActionsController` now owns emote/fishing/home/minigames button wiring, NPC dialog routing, online room panel toggling, and home invite/visit signal forwarding.
- `WorldHUD` is back down to 176 lines and now focuses on HUD assembly, top status, coin/presence text, Image 2 frame setup, and emote palette handoff.
- Online room UI smoke verifies both HUD controllers exist so future shop/mail/inventory work does not collapse back into the root HUD script.
- Web export now packages `WorldHUDChatController.gdc` and `WorldHUDActionsController.gdc`, confirming the boundary compiles into H5.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Service Sync Boundary V1

Status: Implemented.

- `HousingOnlineSync` now owns online layout fetch, visit sync, place/style/move/remove submission, server rejection recovery, and wallet sync.
- `HousingService` is back down to 188 lines and now stays focused on local catalog, placement rules, room state, save data, and offline sell refunds.
- Housing smoke verifies the online sync helper is initialized, so the service cannot silently collapse back into one monolith.
- Web export now packages `HousingOnlineSync.gdc`, confirming the boundary compiles into the H5 build.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Online Client Boundary Split V1

Status: Implemented.

- `OnlineClientSession` now owns guest login, refresh, profile sync, device ID, and session restore/apply behavior.
- `OnlineClient` remains the stable autoload facade for existing systems while dropping to 224 lines.
- `OnlineClientEndpoints` keeps feature endpoint methods isolated from auth/session state.
- Online client smoke verifies offline fallback behavior after the split.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Edit Polish V1

Status: Implemented.

- `HousingRoomEditController` now owns catalog selection, placed-item selection, move, rotate, sell, and undo state.
- Housing room now exposes an Image 2 framed Undo button for the last move/rotate transform.
- Undo intentionally covers position/rotation transforms only; sell/remove still clears undo because it changes the economy ledger.
- H5 housing smoke now clicks a placed furniture item and moves it before screenshots, so desktop/mobile captures include the edit feedback state.
- Housing smoke verifies EditController exists and performs a move followed by undo against real `HousingService` state.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Main City Interaction Boundary Split V1

Status: Implemented.

- `MainCityInteractionController` now owns hotspot binding, NPC spawning, NPC dialog activation, and NPC primary action routing.
- `MainCityScreen` now owns scene-level service assembly, realtime sync, presence announcements, and route actions only.
- The main city controller is back under the single-file limit with room for the next shop/mail/lobby surfaces.
- Main city smoke now verifies the `InteractionController` boundary exists.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke suite, Web export, and H5 viewport smoke all pass.

### Housing Edit Verbs V1

Status: Implemented.

- Client housing now supports select placed furniture, move to an empty tile, rotate, and sell/remove.
- `HousingLayoutRules` owns grid bounds, rotated footprint checks, placed-item lookup, and occupancy validation.
- Backend now exposes `POST /housing/move` and `POST /housing/remove`.
- Server move/remove mutations remain owner-only; remove grants the configured sell refund through the economy ledger.
- Offline local housing mirrors the same move/rotate/remove rules and configured sell refund.
- Housing smoke and Go tests cover move, rotate, remove, occupied move rejection, missing item rejection, and sell refund.
- Online backend E2E now covers `OnlineClient.move_housing_item`, `OnlineClient.remove_housing_item`, insufficient-funds stability, and refund balance sync.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Furniture Art V1

Status: Implemented.

- `HousingRoomArt` centralizes Image 2 texture loading, room surface drawing, placed furniture drawing, shadows, and placement preview rendering.
- `HousingRoomScreen` now renders wall/floor surfaces and placed furniture from `housing_fishing_props_v0` slices instead of colored placeholder rectangles.
- Build catalog buttons now show Image 2 furniture icons while keeping the horizontal scroll behavior for mobile landscape.
- `HousingService` now validates room bounds and occupied tiles before spending coins, so invalid placement no longer burns currency.
- `configs/art_assets.json` now registers semantic `housing.item.*.icon` entries, and content validation requires housing item icons to be registered art assets.
- H5 housing smoke now clicks a room tile before screenshots, so desktop/mobile captures include actual placed furniture.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Room UI V1

Status: Implemented.

- `HousingRoomScreen` now uses Image 2 framed top, bottom, and social panels through shared `WorldHUDAssets` helpers.
- The room grid is centered from the active viewport instead of relying on a fixed negative origin, improving H5 desktop and mobile landscape framing.
- `HousingRoomSocialPanel` adds a live visitors list, recent house chat preview, and house-channel chat input inside the room.
- The build catalog uses Image 2 button frames and remains horizontally scrollable for narrow mobile landscape screens.
- H5 viewport smoke now includes direct housing screenshots on desktop and 844x390 mobile landscape.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Room UI Boundary Split V1

Status: Implemented.

- `HousingRoomScreen` has been reduced from 296 lines to 197 lines and now owns assembly, routing, selection state, and input forwarding only.
- `HousingRoomCatalogBar` owns the Image 2 framed furniture catalog, selection status, and build controls.
- `HousingRoomRenderer` owns room surface drawing, grid placement preview, and placed furniture rendering.
- `HousingRoomSocialController` owns house-channel chat, visitor presence, and the social panel data flow.
- Housing smoke tests now verify the catalog bar and social controller boundaries so future edits do not collapse the room UI back into one large controller.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Invite / Visit V1

Status: Implemented.

- Backend now exposes `POST /housing/invite` and `POST /housing/visit`.
- MVP homes are public visit rooms: authenticated visitors can join `home:<owner_id>`, send house-channel chat, and appear in presence.
- Housing edits remain owner-only; cross-owner placement/style mutations still return `403 owner_mismatch`.
- `OnlineClient` now exposes housing invite and visit endpoints.
- `HousingService` can load another player's layout in read-only visit mode and blocks visitor placement before spending coins.
- `OnlineRoomPanel` adds Image 2 framed `Invite Home` and `Visit Home` actions next to the minigame actions.
- Main city sends localized home invites through the house chat channel and routes selected members into visit mode.
- H5 desktop and mobile landscape screenshots show the room panel with both home social actions visible.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Fishing Reward UI V1

Status: Implemented.

- The official fishing minigame now shows a compact Image 2 reward/result panel after each catch.
- Reward UI displays localized fish name, coin gain, fish icon, wallet feedback, and a `Cast Again` loop action.
- Fishing catches now trigger the platform overhead emote hook with `emote.fishing_bite`, keeping minigame feedback on the same social bubble system as the main city.
- `configs/fishing.json` now maps each fish to an Image 2 PNG icon slice from `housing_fishing_props_v0`.
- `configs/art_assets.json` now registers semantic fishing fish icon bindings for content validation and future UI lookup.
- `tests/fishing_reward_ui_smoke.gd` verifies Image 2 panel/button skin, reward visibility, icon loading, and wallet coin gain.
- H5 viewport smoke now clicks into Host Fishing, casts once, and captures the reward panel on desktop and mobile landscape.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Main City UI Skin V1

Status: Implemented.

- `WorldHUDAssets` now owns shared Image 2 `StyleBoxTexture` helpers for panels, buttons, and text fields.
- HUD TopBar, BottomBar, chat input, channel picker, primary HUD buttons, emote palette, NPC dialog, and Online Room panel now share the same semantic `ui.panel.pixel` / `ui.button.pixel` bindings.
- `OnlineRoomPanel` no longer renders as a flat engineering panel; its frame and action buttons now use Image 2 UI kit slices.
- `tests/online_room_ui_smoke.gd` now fails if key HUD and Online Room surfaces lose their Image 2 frame bindings.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass with the new Image 2 skin.

### Main City NPC Service Menu V1

Status: Implemented.

- `MainCityNPCDialog` adds a compact bottom-left service dialog that protects the center playfield.
- NPC dialog panels and buttons use the semantic Image 2 UI bindings `ui.panel.pixel` and `ui.button.pixel`; close and primary actions use Image 2 HUD icons.
- `configs/main_city_npcs.json` now defines each NPC primary action, localized button key, and icon binding.
- Fisher, Game Host, and Home Keeper route to Fishing, Game Hall, and Home Edit through the same HUD signal path.
- Merchant, Mail Courier, and Event Guide now have service menu entries while their deeper systems remain scoped.
- `WorldHUD/Root` now ignores pass-through mouse input so map NPCs and hotspots remain clickable under the HUD layer.
- `tests/main_city_interactions_smoke.gd` verifies event guide dialog text and Game Host primary action opening the room panel.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, H5 viewport/Host Fishing smoke, and an H5 NPC dialog screenshot pass.

### Main City NPC + Chat V1

Status: Implemented for first NPC batch.

- `characters_npcs_v0` is now sliced into 38 NPC/character PNGs under `assets/sprites/sliced/characters_npcs_v0`.
- `assets/sprites/sliced/characters_npcs_v0_contact.png` is available for fast visual picking.
- `configs/main_city_npcs.json` defines the first town NPC batch: fisher, merchant, mail courier, game host, home keeper, and event guide.
- `MainCityNPC` spawns data-driven Image 2 NPC sprites with localized names, click/tap activation, and overhead emote bubbles.
- Main city NPC clicks now open localized service dialogs; deeper primary actions post system notices where useful.
- Chat views now filter by the selected channel while keeping system messages visible.
- `tests/main_city_interactions_smoke.gd` now covers NPC spawn art, event guide dialogue, and channel view filtering.
- H5 screenshot QA caught unsafe north-side NPC placement and oversized world labels; NPC positions, scale, and labels were adjusted to keep the first viewport clear of the HUD.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Ops + Chat/Main City V1 Push

Status: Implemented for the first v1 step.

- Added authenticated `POST /chat/report` and in-memory report stats so player reports become visible in `/debug/ops`.
- Added PostgreSQL-backed chat message/report persistence for `storage.mode=postgres`, while keeping memory mode fast for local iteration.
- Added admin-only `GET /admin/chat-reports` and `POST /admin/chat-reports/:id/review`, with admin fingerprint/source tracking and no raw token storage.
- Added soft chat send rate limiting at 6 messages per 10 seconds per player/room/channel, plus localized client feedback and ops rejection counters.
- Added admin-only chat moderation actions: `mute`, `ban`, and `restore`, with active restriction enforcement on `/chat/send`, GORM persistence, memory-mode parity, and ops counters.
- Added admin role tokens (`viewer`, `moderator`, `reviewer`, `owner`) and high-risk action confirmation for chat bans plus creator rollback/unpublish.
- Added required operator notes for creator rollback/unpublish and chat bans, persisted reviewer audit notes, and CSV export for reviewer/chat moderation audit streams.
- Added global `X-Request-ID` propagation, `/readyz`, request IDs on admin audit rows, reviewer audit filters/pagination, and chat moderation audit action/offset filtering.
- Replaced Gin text request logging with structured JSON access logs keyed by request_id.
- Added `pixel-social-world-preflight` for Ubuntu/systemd dry-run config checks, wired it into Linux builds, release packaging, the origin install script, and `ExecStartPre`.
- Client `ChatService` can report the latest reportable visible online message and emits localized system feedback for sent, missing, failed, or offline report states.
- `OnlineRoomPanel` now exposes a compact Image 2 skinned report button without adding more persistent HUD chrome.
- Added a standalone Image 2 skinned `ChatReportsConsolePanel` for first-pass chat moderation actions in Godot/H5 admin tooling.
- `ChatReportsConsolePanel` now exposes the first safe executable action, room mute for 1 hour, and then marks the report reviewed.
- Added an Image 2 skinned `ChatModerationAuditPanel` for active restrictions, recent moderation actions, and restore operations.
- `ChatModerationAuditPanel` now supports target-player filtering, action filtering, and CSV export readiness feedback through the admin API.
- `ReviewerConsolePanel` now exposes per-game CSV export readiness feedback while keeping review actions and audit summaries in the same Image 2 tool surface.
- Added a standalone `LiveOpsConsolePanel` that hosts creator review, chat report moderation, role display, moderation audit, and ops counters under one internal tool shell.
- Split `OnlineClientRequest` out of `OnlineClient`, and split `ChatModerationAuditFilters` out of the moderation audit panel so the client admin surface has safer file-size headroom.
- Added an Image 2 skinned `DebugOpsPanel` for `/debug/ops` room, realtime, chat, moderation, and fishing reward counters.
- `DebugOpsPanel` now also calls `/debug/rooms` and renders a room drilldown section for connected clients and retained snapshot players.
- Backend `/debug/rooms` now includes inferred room type and last active time, so LiveOps can distinguish main city, housing, minigame, and custom room pressure.
- Main city presence pill now distinguishes online, stale, and offline states by color, keeps the full desktop H5 label visible, and exposes room plus heartbeat age in the tooltip.
- `LiveOpsConsolePanel` now adapts from a two-column desktop grid to a single-column scroll layout below 1120px, keeping 960x540 and 375px-wide H5 tool views readable.
- `LiveOpsConsolePanel` and H5 smoke automation now harden admin-token propagation before every child-panel refresh, eliminating the long-matrix stale-token 403 flake.
- Local Web debug routing supports `?psw_route=liveops_console` only when `network.environment` is `local_dev`, so screenshot QA can open internal tools without enabling that route in production runtime config.
- Backend `/debug/ops` now exposes administrator-only room, realtime, chat, and fishing reward stats.
- H5 viewport smoke now has reusable helper steps, a single-case filter via `PSW_H5_CASE`, and an opt-in real-backend LiveOps refresh path via `PSW_H5_INCLUDE_BACKEND_OPS=1`.
- Chat service now loads online room history, ingests realtime `chat.message`, deduplicates server echoes, and resets cleanly on scene initialization.
- Main city now pulls chat history on entry and routes realtime `chat.message` into the HUD chat stream.
- Presence HUD now shows member count and stale/heartbeat status in English, Japanese, and Simplified Chinese.
- Realtime backend E2E now verifies room-scoped `chat.message` broadcast and leak prevention.
- Verified on 2026-04-30: content validation, Go unit tests including admin roles, action confirmation, required notes, audit CSV export/filtering, request-id propagation, structured access logs, readiness probes, config validation, and mute/restore enforcement, Godot smoke subset, liveops console smoke with Debug Ops, chat moderation audit smoke, reviewer console smoke, online client smoke, reviewer backend E2E, online backend E2E, realtime backend E2E, Web export, H5 runtime gate smoke, H5 LiveOps screenshot smoke, H5 real-backend LiveOps refresh smoke, Linux amd64 backend/preflight build, and free-launch package build all pass.

## Client Foundation Split + Main City Signals

Status: Implemented.

- `OnlineClient` now delegates REST feature endpoints to `OnlineClientEndpoints`, keeping the autoload API stable while reducing file size.
- `WorldHUD` now delegates Image 2 icon binding and emote palette behavior to small HUD helper scripts.
- Main city presence changes now surface as localized system chat notices after the initial member snapshot.
- The risky near-300-line files have headroom again: `OnlineClient.gd` is 262 lines and `WorldHUD.gd` is 181 lines.
- Verified on 2026-04-29: content validation, Godot smoke, online client smoke, online room UI smoke, minigame launch smoke, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Main City Interaction V1

Status: Implemented for first interactable map pass.

- `MainCityScreen` now delegates remote avatar creation/sync to `MainCityRemotePlayers`; the scene controller is back under 200 lines.
- `MainCityHotspot` adds clickable/tappable map hotspots with localized labels.
- Main city now exposes Fishing Pier, Game Hall, Home Gate, and Item Shop hotspots.
- Fishing Pier starts the fishing session flow; Game Hall opens the online room/minigame panel; Home Gate routes to housing; Item Shop posts a system notice while the shop loop is pending.
- `WorldHUD` now includes a channel picker backed by `configs/chat_channels.json`; outgoing chat can switch from global to nearby/house/party.
- `tests/main_city_interactions_smoke.gd` verifies channel switching, Game Hall panel opening, and Item Shop system notice.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke, main city interactions smoke, online client smoke, online room UI smoke, minigame launch smoke, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Studio Mode V2 Update

Status: Started.

- `AGENTS.md` now keeps the original art/UI plan while using Go and `IMinigame` for platform architecture.
- `IMinigame`, `MinigameLauncher`, and `MinigameManifestValidator` have been added.
- The official fishing game now has a creator-style package with `main.tscn`, `game.gd`, `meta.json`, and `README.md`.
- A Go backend skeleton now exists under `backend/`.
- Content validation and Godot smoke tests pass after the sandbox and fishing package changes.
- Go formatting/tests use the project-local `.tools/go` toolchain without global install.

## Studio Mode UI / Main City Push

Status: Completed v0.

- Art direction now explicitly follows the original reference-board baseline: cozy fantasy MMO, warm forest town, compact pixel UI, and social emote bubbles.
- The visual direction is original and avoids copying any existing commercial game sprites or UI frames.
- `CreatorSafetyScanner` now blocks dangerous GDScript API patterns for minigame packages.
- `MainCity.tscn` exists as the new post-login route while the older `world` route remains available.
- `configs/ui_assets.json` tracks UI kit, HUD icons, and emote asset bindings.
- Runtime SVG UI placeholders were removed; scene button icons use generated PNG assets.

## Image 2 Asset Batch v0

Status: Completed.

- UI Kit, overhead emotes, HUD icons, main city tileset, character/NPC sheet, and housing/fishing props were generated with Image 2.
- Source PNGs and chroma-key-removed alpha PNGs are stored in project assets.
- `configs/ui_assets.json` now references generated UI sheets.
- `configs/art_assets.json` now references generated map, sprite, housing, and fishing sheets.
- Content validation and Godot smoke both pass after asset registration.

Generated alpha sheets:

- `assets/ui/generated/ui_kit_v0_alpha.png`
- `assets/ui/generated/overhead_emotes_v1_alpha.png`
- `assets/ui/generated/hud_icons_v0_alpha.png`
- `assets/maps/generated/forest_main_city_tileset_v0_alpha.png`
- `assets/sprites/generated/characters_npcs_v0_alpha.png`
- `assets/housing/generated/housing_fishing_props_v0_alpha.png`

## Asset Slicing v0

Status: Completed for starter UI, overhead emote, map prop, and housing/fishing sheets.

- `AGENTS.md` now hard-requires Image 2 PNG/WebP for official UI and art production assets.
- `scripts/Tools/AssetSlicer/slice_generated_sheets.py` slices generated alpha sheets into individual PNG candidates.
- `configs/generated_asset_slices.json` registers 255 sliced Image 2 assets.
- Sliced output counts: 100 main city map props, 61 UI Kit, 30 overhead emotes, 40 HUD icons, 24 housing/fishing props.

## UI Binding v0

Status: Completed for primary HUD buttons and first emote entry.

- `WorldHUD.tscn` now uses Image 2 sliced PNG icons for Emote, Send, Fishing, Home, and Games.
- HUD icons are loaded at runtime from `configs/ui_assets.json` with `ImageTexture` so fresh clones do not require pre-generated `.import` metadata.
- `configs/ui_assets.json` now maps common HUD icons and emotes to semantic IDs.
- The old social and sad emote sheets were replaced by `overhead_emotes_v1`.
- `configs/ui_assets.json` now maps the 30 overhead bubble emotes to semantic IDs.
- `emote.laugh` is locked to `overhead_emotes_v1_016.png`; `emote.exclamation` is locked to `overhead_emotes_v1_001.png`.
- Content validation now rejects old social/sad emote asset paths.

## Overhead Emote System v0

Status: Completed for local player, HUD selection, shortcuts, and minigames.

- HUD emote actions now emit a structured `emote_requested` signal instead of posting emote text to chat.
- The HUD emote button opens a 30-button icon palette driven by `configs/emotes.json`.
- `Alt+1` through `Alt+0` now trigger the first shortcut set.
- `PlayerAvatar.show_emote()` plays a head-above bubble animation through `OverheadEmoteBubble`.
- `EmoteCatalog` loads Image 2 sliced PNGs from `configs/ui_assets.json` at runtime.
- `IMinigame.request_emote()` and `MinigameLauncher.emote_requested` expose the same emote protocol for creator games.
- `EmoteSync` now introduces the `emote.send` / `emote.event` client protocol path; offline mode echoes the local event.

## Housing Build Loop v0

Status: Completed for offline MVP.

- The HUD Home button now routes to `home_edit`.
- Players can select furniture, decor, and activity items and place them on an 8x5 room grid.
- Wall/floor style changes and item placement spend coins through `HousingService`.
- Layout is saved to `house_items`; room styles are saved to `house_styles`.
- `tests/housing_smoke.gd` verifies placement cost, style cost, save data, and scene instantiation.

## Economy Ledger + Housing Backend Contract v0

Status: Completed for local/offline contract.

- `SaveSystem` now stores an append-only `coin_ledger` with checksum chaining.
- `tests/economy_ledger_smoke.gd` verifies grant, spend, and tamper detection.
- The Go economy skeleton now exposes reward, spend, and ledger APIs.
- The Go house skeleton now exposes layout, place item, and apply style APIs.
- Housing backend spends use server-side catalog prices instead of trusting client-submitted prices.

## Housing Art Binding v0

Status: Completed for starter catalog icons.

- `housing_fishing_props_v0` was sliced into 24 Image 2 PNG assets.
- `configs/housing_items.json` now uses Image 2 PNG icon paths for starter wall, floor, chair, table, plant, and arcade cabinet.
- The old housing SVG placeholder icon files were removed.
- A contact sheet is available at `assets/housing/sliced/housing_fishing_props_v0_contact.png`.

## Online Client Contract v0

Status: Completed with offline fallback.

- `OnlineClient` is now an autoload singleton for REST calls against the Go backend contract.
- Login tries `POST /auth/guest`; if local backend is unavailable, it falls back to offline mode.
- Online login can refresh wallet data through `GET /me`.
- Housing service can sync layout from `GET /housing/layout/:owner_id`.
- Housing placement/style changes keep the local optimistic MVP loop and submit to `/housing/place` or `/housing/style` when connected.
- Server balance responses are reconciled into the local coin ledger with `server.sync` events.
- `tests/online_client_smoke.gd` verifies offline fallback without requiring a running backend.

## Chatrooms + Minigame Sessions Backend v0

Status: Completed and locally verified.

- The Go chat service now stores room/channel history with a capped MVP message length.
- `POST /chat/send` persists a message and broadcasts `chat.message` through the city hub.
- `GET /chat/history/:room_id/:channel_id` returns recent chat history.
- The Go minigame service now manages sessions with create, list, join, leave, and end operations.
- Session operations are mutex-protected so concurrent joins cannot overfill a room.
- Sessions now expose `expires_at`; memory sessions prune stale entries on read and Redis sessions refresh TTL on mutation.
- Go tests cover chat history/length limits and concurrent minigame joins.
- Client `OnlineClient` exposes chat and minigame session methods for the next UI wiring slice.
- Housing online failure handling uses server reconciliation and `house_sync_required` instead of complex per-operation rollback.

## Local Toolchain

Status: Completed without global install.

- Go is installed project-locally under `.tools/go` and ignored by git.
- Go module and build caches are kept under `.tools/gomodcache` and `.tools/gocache`.
- `go test ./...` passes with the local toolchain.
- A real backend smoke on port `18787` passed for health, city state, chat send/history, minigame create/join/full, housing place, and housing insufficient funds.

## Godot Online Backend E2E

Status: Completed.

- Backend guest login now initializes a 25-coin wallet for the generated guest player.
- `/me` supports `player_id` lookup for the MVP memory backend.
- `OnlineClient` preserves manual test configuration so endpoint overrides are not reset by login.
- `tests/online_backend_e2e.gd` passes against a real backend on `127.0.0.1:18787`.
- The E2E covers login, wallet sync, chat, minigame session creation/join, housing placement, backend ledger, and HTTP 402 without marking the client disconnected.

## Backend Persistence Architecture v0

Status: Implemented with optional PostgreSQL mode.

- Backend config now supports `memory` and `postgres` storage modes.
- `cmd/server` loads `configs/local.yaml` plus `PSW_*` environment overrides.
- Economy has a GORM-backed wallet and append-only ledger implementation.
- Housing has a GORM-backed layout implementation.
- PostgreSQL and Redis local services are defined in `backend/docker-compose.yaml`.
- Redis client wiring exists for the next presence/chat/session persistence pass.
- Docker is not installed in this environment, so PostgreSQL mode was compiled but not runtime-smoked here.
- Memory mode E2E still passes after the dependency-injection split.

## Redis Realtime Architecture v0

Status: Implemented with optional Redis mode.

- `presence.Service` now supports memory and Redis-backed heartbeat TTL.
- New endpoints: `POST /presence/heartbeat` and `GET /rooms/:room_id/members`.
- Minigame sessions now support Redis-backed TTL storage with optimistic Redis WATCH updates.
- Redis session tests cover concurrent joins and TTL expiration with miniredis.
- Godot `OnlineClient` can send presence and fetch room members.
- `tests/online_backend_e2e.gd` now covers presence heartbeat and room member listing.
- Verified on 2026-04-29: Go unit tests, Godot smoke tests, content validation, and real memory-backend E2E all pass.

## Linux Backend Deployment v0

Status: Implemented as a production deployment baseline.

- Target server profile is now documented as Ubuntu 26.04 LTS, Linux amd64, i9-13900KF, 64GB RAM.
- `cmd/server` supports `PSW_CONFIG` and graceful SIGTERM shutdown for systemd.
- `backend/configs/production.yaml` defines the postgres + redis production mode.
- `backend/deploy/pixel-social-world.service` provides a systemd service template.
- `backend/deploy/pixel-social-world.env.example` defines the runtime environment contract.
- `backend/scripts/build-linux-amd64.sh` builds the Linux amd64 backend binary.
- `docs/BackendDeployment.md` captures install layout, service setup, ports, and single-host sizing.
- Verified on 2026-04-29: backend Go tests pass, Linux amd64 ELF builds, and real memory-backend E2E still passes.

## Online Room UI v0

Status: Implemented and locally verified.

- Main city now starts `PresenceService` and `MinigameSessionService`.
- HUD shows a presence heartbeat pill with online/offline state and last pulse seconds.
- `OnlineRoomPanel` shows room members, recent chat, active/local minigame sessions, and fishing host/join actions.
- The Games HUD button now toggles the online room panel instead of only writing a status line.
- `tests/online_room_ui_smoke.gd` covers panel open, local member display, session rendering, and heartbeat label rendering.
- Remaining runtime SVG UI placeholder paths were removed; `ui.panel.pixel` and `ui.button.pixel` now point at Image 2 PNG slices.

## Player Action Animation v0

Status: Implemented with Image 2 production sprites.

- Researched classic RO-style action data at the behavior level: action clips, facing directions, frame timing, and anchor-driven sprites.
- Generated an original Image 2 player action sheet for idle, walk, attack, and sit.
- Processed the sheet to alpha PNG and sliced 32 action frames under `assets/sprites/sliced/player_adventurer_actions_v0/`.
- Added `configs/player_animations.json` for config-driven avatar animation.
- `PlayerAvatar` now supports walking animation, directional facing, `Z`/confirm attack, and `X` sit toggle.
- `tests/player_avatar_smoke.gd` covers sprite creation, sit state, and attack state.
- Content validation now checks player animation source sheets and frame paths.

## Remote Player Presence v0

Status: Implemented as the first visible multiplayer slice.

- Main city now mirrors non-local presence members into `PlayerRoot/RemotePlayers`.
- Remote avatars reuse `PlayerAvatar` and the Image 2 action animation sheet with local input disabled.
- Remote avatars spawn around the plaza from deterministic player-id positions and clean up when presence expires.
- `WorldStateSync.build_player_move_payload()` now emits the reserved `player.move` payload fields.
- `docs/MultiplayerSync.md` defines the presence-to-avatar flow and movement snapshot shape.
- `tests/remote_players_smoke.gd` covers remote spawn and cleanup.
- `tests/world_state_sync_smoke.gd` covers movement payload fields.

## WebSocket Movement + Emote Sync v0

Status: Implemented and locally verified.

- Backend city hub now tracks socket room membership from `world.join`.
- `player.move` broadcasts only inside the sender's room.
- `emote.send` is converted to `emote.event` and shares the same room fanout path.
- Godot `RealtimeClient` connects to `/ws/city`, sends join metadata, and streams local movement snapshots.
- Main city applies remote `player.move` payloads to visible `PlayerAvatar` instances.
- Main city applies remote `emote.event` payloads through the RO-style overhead bubble system.
- Fixed Godot-to-Go timestamp compatibility by sending integer Unix timestamps in protocol payloads.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke suite, online backend E2E, and realtime backend E2E all pass.

## Realtime + REST Authority Hardening v4

Status: Implemented and locally verified.

- Guest auth now stores random access/refresh tokens, rotates refreshes, validates WebSocket joins, and shares H5 session/lifecycle code through `SessionTokenStore` and `NetworkLifecycle`.
- Invalid `world.join` requests receive `auth.failed` and disconnect.
- Backend overrides client-sent `player_id` and `room_id` for movement and emote messages.
- Backend rate-limits `player.move` and `emote.send`, clips movement to room bounds, serves `world.snapshot`, and emits `world.leave`.
- REST profile, presence, chat, minigame-session, economy spend/ledger, housing mutations, and creator/admin routes now validate tokens.
- Housing layout/mutation endpoints are owner-only for MVP; public reward grants are blocked until trusted server reward flows own them.
- `realtime.mode=redis` now uses Redis pub/sub room fanout for multi-process WebSocket delivery.
- `realtime.mode=redis` now also uses Redis-backed auth sessions and distributed rate limits.
- `/city/state` now reports realtime counters for fanout, local delivery, rate limits, and leave events.
- `RoomLifecycle` now switches main city, housing, and minigame rooms through `RealtimeClient.switch_room()`.
- `RealtimeClient` now retries dropped WebSocket connections with capped backoff from `network.reconnect_attempts`.
- Remote `PlayerAvatar` movement now interpolates, and main city applies snapshot recovery payloads.
- Tests now verify token refresh, admin gates, REST anti-spoofing, room isolation, position clipping, snapshot recovery, Redis fanout/rate limiting, metrics, and emotes.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke suite, online backend E2E, and realtime backend E2E all pass.

## Architecture Health Pass v1

Status: Completed and locally verified.

- Minigame session lifecycle is now explicit across memory and Redis services with `expires_at`.
- Online room UI renders localized session state and remaining minutes for operational visibility.
- Web export output is isolated by `builds/.gdignore`; old Playwright screenshots were removed from `builds/web`.
- Current `.gd` and `.go` files stay under the 300-line project rule.
- Verified on 2026-04-29: content validation, Go tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop room-panel smoke all pass.
- Follow-up risk: portrait H5/mobile still needs a dedicated responsive scale pass; landscape H5 is stable for current testing.

## H5 Landscape Guard v0

Status: Implemented and locally verified.

- Added a global `OrientationGuard` autoload for the Web build.
- H5 portrait viewports now show a localized landscape-required overlay instead of exposing unusably tiny UI.
- English, Japanese, and Simplified Chinese localization keys were added for the guard message.
- Re-exported Web with the standard Godot build after confirming the Mono editor cannot export Web.
- Added `tests/h5_viewport_smoke.mjs` for desktop landscape, mobile landscape, and mobile portrait guard screenshot regression.
- Verified on 2026-04-29: desktop landscape login/world, mobile landscape login/world, mobile portrait guard overlay, and desktop/mobile landscape online room panel screenshots all pass without page errors.
- Remaining risk: true portrait-play UI is intentionally out of MVP scope until the core landscape social loop is stable.

## Minigame Launch Loop v0

Status: Implemented and locally verified.

- `MinigameSessionService.create_session()` and `join_session()` now only manage session state; scene transitions are owned by `launch_game()`.
- Offline session creation now remembers `pending_minigame_id` and `pending_minigame_session_id` without double-routing.
- Main HUD and online room panel both launch fishing through the same service path after a successful create/join.
- Main city remote avatar spawn points are clamped to a camera/HUD safe playable rect so stale presence members no longer appear under top or bottom HUD.
- Added `tests/minigame_session_service_smoke.gd` and `tests/minigame_launch_flow_smoke.gd`.
- `tests/h5_viewport_smoke.mjs` now also captures desktop/mobile Host Fishing entry into the sandbox.
- Verified on 2026-04-29: content validation, Go tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, H5 viewport smoke, and H5 Host Fishing smoke all pass.

## Fishing Trusted Reward Loop v0

Status: Implemented and locally verified.

- Added `POST /minigames/fishing/catch` as the first trusted minigame reward flow.
- The backend validates bearer token, active fishing session, and session membership before granting coins.
- Fishing rewards now use server-side weighted RNG and append to the backend economy ledger with `minigame.fishing.*` source IDs.
- Each player/session pair is capped at 10 rewarded catches for the current MVP session loop.
- `scenes/minigames/fishing/game.gd` no longer grants local coins for online sessions; it syncs the wallet from the backend response.
- Offline/local fishing still uses local save rewards so device-only smoke and offline play remain usable.
- `MinigameLauncher` now closes online sessions through end/leave and routes finished or exited minigames back to the main city room.
- Added backend cap/membership unit coverage and extended online backend E2E plus minigame launch smoke.
- H5 viewport smoke now ignores Chromium's harmless `CONTEXT_LOST_WEBGL` teardown warning while still failing on real page errors.
- Verified on 2026-04-29: content validation, Go tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Minigame Reward Service v1

Status: Implemented and locally verified.

- Moved trusted fishing reward selection, per-session counters, and economy grants from gateway code into `minigame.FishingRewardService`.
- Gateway fishing routes now only handle request binding, auth, error-code mapping, and JSON responses.
- `cmd/server` loads fishing reward rules from the shared `configs/fishing.json` file through `PSW_FISHING_CONFIG_PATH` or `minigames.fishing_config_path`.
- The backend reads `daily_full_reward_count` as the MVP per-session catch cap and `fish[].sell_value/weight/name_key` as the authoritative reward table.
- Added unit coverage for shared config loading and reward cap behavior.
- Production deployment docs and env examples now include the shared fishing config path.
- Verified on 2026-04-29: Go unit tests, content validation, online backend E2E, and realtime backend E2E all pass.

## Server-Authoritative Housing Catalog v1

Status: Implemented and locally verified.

- Backend housing services now load item prices, sizes, categories, rotation flags, and item types from the shared `configs/housing_items.json` contract.
- `cmd/server` wires `PSW_HOUSING_CONFIG_PATH` / `housing.items_config_path` into both memory and PostgreSQL housing services.
- Gateway placement/style routes still pre-check before spending and re-check before persisting, with refund protection if a post-spend validation conflict appears.
- Added Go coverage for loading the shared housing catalog and for blocking invalid placement/style requests without spending coins.
- Production deployment docs and env examples now include the shared housing config path.

## Fishing Reward Idempotency v1

Status: Implemented and locally verified.

- `fishing.catch` now accepts a client `request_id` and returns it in the reward response.
- Godot `OnlineClient.claim_fishing_catch()` generates request IDs, and the fishing minigame passes one per cast.
- Memory reward service replays completed request IDs without issuing another grant.
- Redis reward service stores `minigame:fishing:request:{session_id}:{player_id}:{request_id}` and `minigame:fishing:count:{session_id}:{player_id}` so multi-process backends share idempotency and reward caps.
- Redis duplicate in-flight requests return `409 fishing_request_pending`; completed duplicates return the original response.
- `tests/online_backend_e2e.gd` now verifies request-id replay does not change catch number or wallet balance.
- Re-exported H5 and reran viewport/Host Fishing smoke.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke subset, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

## Player Profile Card + Mobile Keyboard Guard v1

Status: Implemented and locally verified.

- Room member actions now open a compact Image2-framed player profile card instead of jumping directly to private chat.
- The player card exposes private chat, visit home, quick emote, and a disabled report affordance for the moderation follow-up.
- Member selection now stores structured profile metadata in the `ItemList` instead of parsing display text.
- `WorldHUD.show_player_profile()` gives H5 and future systems a stable public entry point for contextual player cards.
- Web export enables Godot's experimental virtual keyboard setting, while the HUD keeps a fallback inset for browsers or platforms that do not report keyboard height.
- `WorldHUDMobileInputController` raises the bottom chat bar and the focused side panel on compact landscape viewports, then restores offsets on blur.
- H5 smoke now captures desktop/mobile player-card states plus mobile chat/private keyboard-guard states.
- Verified on 2026-05-01: content validation, Go tests, Godot room/main-city/social/mobile-input smokes, Web export, full H5 viewport matrix, and targeted H5 profile/keyboard screenshots all pass.

## Player Profile Report + MVP Performance Forecast v1

Status: Implemented and locally verified.

- Added `POST /players/report` so profile-card player reports enter the same chat moderation queue as message reports.
- Backend memory and PostgreSQL chat services now snapshot target player id/name with `channel_id=profile` for existing admin review tools.
- Godot `OnlineClient.report_player_profile()` and `PlayerProfileCard.report_requested` now wire the Report button end-to-end.
- Player profile report feedback is shown as a lightweight system chat message; successful reports disable the card's Report button.
- Remote player avatars now emit profile requests, so clicking/tapping a visible remote character opens the same profile card used by the room member list.
- `docs/MVPProgressPerformanceScore.md` now tracks MVP chain progress plus forecast concurrency, CPU, and memory scores for the planned Ubuntu 26.04 single-host deployment.
- Verified on 2026-05-01: content validation, Go tests, Godot main-city/room/remote/online-client smokes, online backend E2E, Web export, targeted H5 profile-report screenshots, and full H5 viewport matrix all pass.

## WS Load Smoke + Realtime Metrics v0

Status: Implemented and locally verified.

- Room hub metrics now track opened/closed WS connections, local broadcast count, delivery targets, direct deliveries, local deliveries, write failures, and slow writes.
- WebSocket writes now use a bounded write deadline so slow or wedged clients cannot block hub fanout forever.
- Added a 24-client gateway load smoke that logs in guests, joins one room, sends movement fanout, triggers movement rate limiting, sends chat, and verifies `/debug/ops` realtime counters.
- Debug Ops panel now shows WS opened, delivery target, slow write, and failed write counters in English, Simplified Chinese, and Japanese.
- `docs/MVPProgressPerformanceScore.md` now records the measured smoke baseline separately from the single-host capacity forecast.
- Verified on 2026-05-01: content validation, full Go test suite, Godot LiveOps console smoke, Web export, static H5 LiveOps screenshots, and real-backend H5 LiveOps refresh screenshot all pass.

## WS Load Smoke v1 + Production Runtime Defaults

Status: Implemented and locally verified.

- The WS load smoke now accepts `PSW_WS_LOAD_SMOKE_CLIENTS` with a guarded 1-100 range; the default remains 24 for normal test speed.
- Local developer profiles with 50 and 100 authenticated clients in one room pass, including movement fanout, rate limiting, chat fanout, and zero write failures.
- Room debug snapshots now include per-room local broadcast, delivery target, delivered, slow write, and failed write counters.
- Debug Ops room drilldown now renders per-room WS delivered/target/slow/failed counters in English, Simplified Chinese, and Japanese.
- Production and local backend configs now declare HTTP timeouts, graceful shutdown timeout, PostgreSQL pool sizing, and Redis pool/timeout sizing.
- The Go server applies those HTTP, PostgreSQL, and Redis runtime defaults from config and environment variables.
- Verified on 2026-05-01: content validation, full Go test suite, 50-client WS load smoke, 100-client WS load smoke, Godot LiveOps console smoke, Web export, real-backend H5 LiveOps refresh screenshot, and 375px LiveOps screenshot all pass.
