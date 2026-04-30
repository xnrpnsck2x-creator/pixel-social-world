# Go Backend Contract

## MVP Goal

The client can keep offline mode for fast iteration, but every online feature should match this Go contract before it ships.

Runtime stack:

- Go
- Gin
- Gorilla WebSocket
- GORM
- Redis
- PostgreSQL

Storage modes:

- `memory`: default fast iteration mode.
- `postgres`: persists economy wallet/ledger and housing layout.
- `redis` realtime mode stores auth sessions, presence, and minigame session TTL.

## REST

All HTTP responses include `X-Request-ID`. Clients and ops tooling may send `X-Request-ID`; otherwise the gateway generates one. Admin audit rows persist this value for high-risk action traceability.

### `GET /healthz`

Public liveness probe. Returns `ok`, `server_time`, and `request_id`.

### `GET /readyz`

Public readiness probe for process-level routing checks. Returns non-sensitive service readiness booleans plus `server_time` and `request_id`. Detailed counters remain behind admin-only `/debug/ops`.

### `POST /auth/guest`

Request:

```json
{
  "device_id": "ios-vendor-or-local-dev-id",
  "display_name": "Guest"
}
```

Response:

```json
{
  "player_id": "player_123",
  "session_id": "session_123",
  "access_token": "short-lived-token",
  "refresh_token": "long-lived-token"
}
```

### `GET /me`

Returns profile, wallet, starter inventory, and moderation status. Requires `Authorization: Bearer <access_token>` matching the `player_id` query.

### `POST /auth/refresh`

Refreshes and rotates access/refresh tokens without changing the player profile.

### `POST /auth/upgrade`

Player-authenticated guest account upgrade for Apple/Google prep. The bearer token must match `player_id`. The endpoint links the provider identity to the existing player and returns a fresh session without changing `player_id`, so wallet, housing, creator submissions, and room state stay attached to the same account.

Supported `provider`: `apple`, `google`.

Supported `platform`: `ios`, `android`, `h5`, `desktop`, `pc`. The backend normalizes `web` to `h5`.

Request:

```json
{
  "player_id": "guest_123",
  "provider": "google",
  "platform": "h5",
  "provider_subject": "google-stable-sub",
  "identity_token": "provider-id-token",
  "authorization_code": "optional-oauth-code",
  "email": "player@example.com",
  "display_name": "Player"
}
```

Response:

```json
{
  "session": {
    "player_id": "guest_123",
    "session_id": "session_456",
    "access_token": "fresh-short-lived-token",
    "refresh_token": "fresh-long-lived-token"
  },
  "linked_account": {
    "player_id": "guest_123",
    "provider": "google",
    "platform": "h5",
    "provider_subject": "google-stable-sub",
    "linked_at": 1777545600000
  }
}
```

Duplicate provider identity links return `409 account_already_linked`.

Provider verification modes:

- `claimed`: local/dev default. Requires `provider_subject` plus an identity proof field and is only for sandbox iteration.
- `oidc_jwt`: production path. The backend verifies Apple/Google ID token signature through the provider JWKS, checks issuer, audience, expiry, subject, and rejects a client-supplied `provider_subject` if it does not match the verified token subject.

Production env:

- `PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt`
- `PSW_APPLE_CLIENT_IDS=<sign-in-with-apple-service-or-bundle-id>`
- `PSW_GOOGLE_CLIENT_IDS=<google-ios-android-or-web-client-id>`

### `GET /city/state`

Returns the current main city snapshot for initial entry and reconnect.

MVP player movement fields are defined in `docs/MultiplayerSync.md`.

### `POST /presence/heartbeat`

Refreshes player presence in a room with a TTL. Requires a bearer token matching `player_id` and room access.

### `GET /rooms/:room_id/members`

Returns non-expired room members. Restricted rooms require `player_id` query plus matching bearer token.

### `POST /chat/send`

Accepts a chat message in a room/channel and broadcasts `chat.message` to connected city sockets. Requires a bearer token matching `sender_id`.
MVP chat send is softly rate-limited at 6 messages per 10 seconds per player, room, and channel. Rejected bursts return `400 {"error":"rate_limited"}` and increment `chat.rejected_rate_limited` in `/debug/ops`.
Active moderation actions are enforced before rate limiting. Room mutes return `400 {"error":"chat_muted"}`; global or room bans return `400 {"error":"chat_banned"}`.

Request:

```json
{
  "room_id": "world_town_square",
  "channel_id": "global",
  "sender_id": "player_123",
  "sender_name": "Guest",
  "body": "hello",
  "action": {
    "type": "join_minigame",
    "game_id": "fishing",
    "session_id": "session_abc"
  }
}
```

`action` is optional structured intent metadata. MVP only preserves
`join_minigame` with `game_id` and `session_id`; unsupported action payloads
are dropped instead of echoed. This lets localized chat text stay display-only
while room UI can offer stable Join behavior across clients.

### `GET /chat/history/:room_id/:channel_id?limit=50`

Returns recent persisted channel messages. MVP limit is capped at 100; restricted rooms require room access.

Room-scoped channels are intentionally ephemeral: `global`, `nearby`, `house`,
`party`, and `system` are broadcast live and kept only in transient server
memory for rate limiting and reporting. They are not written to PostgreSQL and
history returns an empty list after reconnect/logout. Private chat and mail are
the reserved persistent surfaces and must use durable end-to-end conversation
or mail storage when implemented.

### `POST /chat/report`

Stores a player report for an existing room/channel message. Requires a bearer token matching `reporter_id`; restricted rooms require normal room access. Reports snapshot the target sender/body at submission time so moderation tooling still has context if chat history later rolls over.

Request:

```json
{
  "message_id": "world_town_square:global-000001",
  "room_id": "world_town_square",
  "channel_id": "global",
  "reporter_id": "player_456",
  "reason": "player_report"
}
```

When `storage.mode=postgres`, chat messages and report records are persisted through GORM. In memory mode they remain process-local for fast iteration.

### `POST /players/report`

Stores a profile-card player report in the same moderation queue as chat
reports. Requires a bearer token matching `reporter_id`; `context_room_id`
defaults to `world_town_square` and must pass the reporter's normal room-access
check. The report snapshots the target player id/name with `channel_id: profile`
so `GET /admin/chat-reports` and the existing moderation console can
review it without a separate queue.

Request:

```json
{
  "target_player_id": "player_123",
  "target_player_name": "Ari",
  "reporter_id": "player_456",
  "context_room_id": "world_town_square",
  "reason": "profile_report"
}
```

### `POST /private-messages`

Stores a durable private message between two players. Requires a bearer token
matching `sender_id`. This is separate from room chat: it is not broadcast as a
room message and it is not affected by the ephemeral room history policy.

Request:

```json
{
  "sender_id": "player_123",
  "recipient_id": "player_456",
  "body": "hello"
}
```

Response fields include `id`, deterministic `conversation_id`, sender,
recipient, body, and `created_at`.

Private messages are softly rate-limited at 6 sends per 10 seconds per player.
Rejected bursts return `429 {"error":"private_rate_limited"}`.

### `GET /private-messages?player_id=...&limit=50`

Returns the authenticated player's durable private conversation summaries,
newest first. Each row includes `conversation_id`, `peer_id`, `latest_message`,
`latest_at`, and `unread_count`. This powers the client private-chat list and
HUD unread badge without persisting room chat.

### `GET /private-messages/:peer_id?player_id=...&limit=50`

Returns the authenticated player's durable conversation with `peer_id` in
chronological order. Requires a bearer token matching `player_id`. MVP limit is
capped at 100.

### `POST /private-messages/read/:peer_id`

Marks the authenticated player's private conversation with `peer_id` as read
and returns the updated conversation summary. Requires a bearer token matching
the body `player_id`.

### `POST /private-messages/report`

Stores a player report for a private message. Requires a bearer token matching
`reporter_id`, and the reporter must be either the sender or recipient of the
message. The report snapshots sender, recipient, body, and created time so
moderation can review it even if the conversation UI changes later.

Request:

```json
{
  "message_id": "pm-123",
  "reporter_id": "player_456",
  "reason": "player_report"
}
```

Unauthorized participant access returns `403 {"error":"private_message_forbidden"}`.

### `POST /mailbox/send`

Stores a durable mailbox message. Requires a bearer token matching `sender_id`.
Mailbox messages are recipient-scoped and should be used for async player mail
or system mail that must survive logout.

Request:

```json
{
  "sender_id": "player_123",
  "recipient_id": "player_456",
  "subject": "Welcome",
  "body": "Your room invite is ready."
}
```

### `GET /mailbox/inbox?player_id=...&limit=50`

Returns the authenticated player's mailbox messages, newest first. Requires a
bearer token matching `player_id`. The legacy `GET /utility/mail` endpoint is
only the static utility-panel feed; player mailbox data must use `/mailbox/*`.

### `POST /mailbox/:mail_id/read`

Marks a mailbox message as read and returns the updated message. Requires a
bearer token matching the body `player_id`, and the player must be the mailbox
recipient. Unauthorized recipient access returns `403 {"error":"mail_forbidden"}`.

### `POST /minigames/submit`

Accepts creator metadata and queues asynchronous AI review. Requires admin token; upload storage is out of scope for the first skeleton.

Request includes `mode_id` and `runtime_contract` so the backend can enforce the selected creator mode before review:

```json
{
  "game_id": "creator_side_run",
  "version": "1.0.0",
  "author": "player_123",
  "mode_id": "side_scroller_2d",
  "name": {"en": "Side Run", "ja": "サイドラン", "zh": "横版奔跑"},
  "min_players": 1,
  "max_players": 4,
  "tags": ["action", "platformer"],
  "requires_network": true,
  "runtime_contract": {
    "camera": "side_view",
    "input_profile": "action_platformer",
    "network_profile": "session_sync"
  },
  "entry_scene": "res://creator/creator_side_run/main.tscn",
  "main_script": "res://creator/creator_side_run/game.gd",
  "asset_budget_bytes": 5242880
}
```

Mode caps currently cover `casual_activity`, `side_scroller_2d`, `2d_fighting`, `strategy_war`, `rpg_adventure`, `tower_defense`, and `battle_royale`; `2d_fighting` is capped at 4 players and `battle_royale` is capped at 16 players for the alpha contract.

### `POST /creator-submissions/draft`

Player-authenticated draft metadata submit. The bearer token must belong to `author`; the server stores the record as `pending_review`.

This endpoint uses the same mode, runtime, entry scene, main script, and asset budget validation as the admin submit route.

### `POST /creator-submissions/package`

Player-authenticated package intake submit. V1 accepts a JSON package inventory for Godot/H5 clients and tooling. The bearer token must belong to `author`; the server saves a package artifact, stores the request as `submitted`, starts an async scan job, then moves the owner-visible status to `scanning`, `needs_review`, or `rejected`.

Request shape:

```json
{
  "game_id": "creator_duel",
  "version": "0.1.0",
  "author": "player_123",
  "mode_id": "2d_fighting",
  "name": {"en": "Creator Duel", "ja": "Creator Duel", "zh": "Creator Duel"},
  "min_players": 1,
  "max_players": 4,
  "tags": ["fighting"],
  "requires_network": true,
  "runtime_contract": {
    "camera": "side_view",
    "input_profile": "fighting_action",
    "network_profile": "authoritative_realtime"
  },
  "entry_scene": "res://creator/creator_duel/main.tscn",
  "main_script": "res://creator/creator_duel/game.gd",
  "asset_budget_bytes": 5242880,
  "files": [
    {"path": "meta.json", "size_bytes": 1024, "content_text": "{...}"},
    {"path": "main.tscn", "size_bytes": 512, "content_text": "..."},
    {"path": "game.gd", "size_bytes": 2048, "content_text": "..."},
    {"path": "README.md", "size_bytes": 128, "content_text": "..."},
    {"path": "assets/icon.webp", "size_bytes": 4096, "content_base64": "..."}
  ]
}
```

Scanner rules in V1:

- Required files: `meta.json`, entry scene, main script, and `README.md`.
- Rejects path traversal, duplicate paths, unsupported script/native file types, SVG formal assets, missing script text, forbidden Godot APIs, and packages over `asset_budget_bytes`.
- Clean package submits return `202` with initial status `submitted`; poll `GET /creator-submissions/:id/status` until `needs_review`.
- Rejected package submits also return `202` when queued successfully; poll status until `rejected` and read the scan report.
- Invalid metadata or malformed request bodies still return `400`.
- Status responses include `package.storage_key`, optional `package.artifact_uri`, `package.review_job`, optional `package.ai_review`, and optional `package.install` after publish for operations visibility. Clients should not execute creator package files directly from artifact fields.
- V1 AI review defaults to the local policy adapter. `PSW_AI_REVIEWER_MODE=openai_compatible` enables an OpenAI-compatible endpoint such as LM Studio at `PSW_AI_REVIEWER_BASE_URL`, using `PSW_AI_REVIEWER_MODEL`. LLM failures fall back to local policy so the review queue does not stall.
- Codex can be used as a Studio Mode manual reviewer, but the backend should not depend on interactive Codex OAuth login. Automated review providers must be reproducible through environment-configured endpoints or secrets.

### `POST /creator-submissions/package.zip`

Player-authenticated multipart zip intake. This endpoint extracts the archive into the same package inventory model used by `POST /creator-submissions/package`, stores it as `submitted`, then uses the same async scanner and status transition.

Multipart fields:

- `author`: creator player ID. Must match the bearer token.
- `package` or `file`: zip archive containing `meta.json`, `main.tscn`, `game.gd`, `README.md`, and optional `assets/`.

Limits:

- Compressed archive: 6 MB.
- Uncompressed package: 8 MB hard stop, then the manifest `asset_budget_bytes` still applies.
- A single common root folder, such as `my_game/meta.json`, is accepted and stripped before scanning.

Production storage note: package artifacts are written under `storage.package_artifacts_dir` / `PSW_PACKAGE_ARTIFACT_DIR`. Published runtime installs are written under `storage.package_install_dir` / `PSW_PACKAGE_INSTALL_DIR` and expose only the current approved package through the runtime catalog. When `storage.mode` is `postgres`, creator submission records, package scan snapshots, and review job rows are persisted through PostgreSQL. Realtime minigame sessions still use the configured realtime backend, memory or Redis.

### `GET /creator-submissions/:id/status?player_id=:player_id`

Returns draft review status for the owning creator only. Other players receive `403`.

### `GET /creator-submissions/:id/history?player_id=:player_id`

Returns owner-scoped version history for a creator submission. The current record is still addressed by `game_id`, while this endpoint preserves each submitted `version` as a separate audit item. It is intended for creator status pages, rollback UI, and support review when a current install pointer no longer tells the full story.

Response:

```json
{
  "game_id": "creator_duel",
  "items": [
    {
      "game_id": "creator_duel",
      "version": "0.1.0",
      "status": "published",
      "created_unix": 1777500000,
      "updated_unix": 1777500300,
      "record": {"game_id": "creator_duel", "version": "0.1.0", "package": {"scan_report": {"status": "published"}}}
    }
  ]
}
```

### `GET /minigames/:id`

Returns registered minigame metadata and review status.

### `GET /minigames/catalog`

Returns the current runtime-safe creator catalog. Only packages that passed scan, AI review, admin approval, and publish/install staging appear here.

Response:

```json
{
  "items": [
    {
      "status": "installed",
      "game_id": "creator_duel",
      "version": "0.1.0",
      "mode_id": "2d_fighting",
      "install_key": "creator/creator_duel/0.1.0",
      "install_uri": "file:///var/lib/pixel-social-world/creator_runtime/creator/creator_duel/0.1.0",
      "manifest_uri": "file:///var/lib/pixel-social-world/creator_runtime/creator/creator_duel/0.1.0/install.json"
    }
  ]
}
```

### `POST /minigames/:id/review`

Queues or updates review state without blocking the upload request. Requires a `reviewer` or stronger admin role for approve/reject/status updates. Runtime package operations require `owner`.

Request may be empty, or:

```json
{"action": "approve"}
```

Supported actions/statuses currently map to `review_queued`, `needs_review`, `approved`, `rejected`, and `published`. Runtime-only states such as `submitted` and `scanning` are reported by package scan stages, not manually set by admins.

`published` is no longer a plain status flip: the package must already be `approved`, the original artifact must be reloadable, every file must have `content_text` or `content_base64`, and the publish step writes an installed package plus `current.json` pointer before returning `published`.

Admin-only runtime operations:

- `{"action":"publish"}` or `{"status":"published"}` installs the approved package and moves the per-game `current.json` pointer to that version.
- `{"action":"rollback","confirm":true,"note":"why"}` moves `current.json` back to the previous installed package version. The previous package files remain immutable; only the runtime current pointer changes.
- `{"action":"unpublish","confirm":true,"note":"why"}` removes the per-game `current.json` pointer, returns the submission record to `approved`, and removes that creator package from `GET /minigames/catalog`.

The catalog endpoint only exposes current installed packages. Historical install folders remain server-side rollback targets and are not enumerated to clients.
Missing `confirm:true` on rollback/unpublish returns `400 {"error":"confirmation_required"}`.
Missing `note` on rollback/unpublish returns `400 {"error":"note_required"}`.

Every successful admin review action writes a reviewer audit event. The event records `game_id`, action, resulting status, optional operator note, an admin-token fingerprint, source client, and timestamp; it never stores the raw admin token.

### Admin Roles

Admin credentials accept either a single token, which defaults to `owner`, or a comma-separated role map:

```text
owner:root-token,reviewer:review-token,moderator:mod-token,viewer:view-token
```

Roles are hierarchical: `viewer < moderator < reviewer < owner`.

- `viewer`: read-only ops, dashboards, reports, and audit panels.
- `moderator`: review chat reports, mute chat, restore chat.
- `reviewer`: creator package review actions such as approve/reject.
- `owner`: publish/rollback/unpublish creator packages, ban chat, and edit live-ops configuration.

### `GET /admin/session`

Returns the authenticated admin role, capability list, and actions that require explicit confirmation. Requires any valid admin token. Godot/H5 tooling calls this through `OnlineClient.fetch_admin_session(admin_token)`.

### `GET /admin/reviewer-dashboard`

Returns an administrator-only package review queue snapshot. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.

Each item includes creator identity, mode contract metadata, scanner status/issues, AI reviewer status/notes, async job state, and install/publish state. This endpoint is for human reviewer tooling and Studio Mode audits; normal clients should use owner-scoped `GET /creator-submissions/:id/status`.

Godot/H5 admin tooling calls this through `OnlineClient.fetch_reviewer_dashboard(admin_token)` and applies actions through `OnlineClient.review_minigame_admin(game_id, action, admin_token, confirm, note)`. The standalone `ReviewerConsolePanel` is an admin surface, not part of the normal player Creator Lab.

Response:

```json
{
  "generated_at": 1777500000,
  "items": [
    {
      "game_id": "creator_duel",
      "status": "needs_review",
      "mode_id": "2d_fighting",
      "scan": {"status": "needs_review", "issue_count": 0, "file_count": 4},
      "ai": {"status": "approved", "reviewer": "local_policy_v1", "risk_level": "low"},
      "job": {"status": "completed", "attempts": 1},
      "install": {"status": ""}
    }
  ]
}
```

### `GET /admin/chat-reports?status=open&limit=50`

Returns administrator-only chat report rows. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.

Each item includes the report metadata, target message snapshot, current status, reviewer fingerprint, and review timestamp if already handled. The standalone `ChatReportsConsolePanel` calls this through `OnlineClient.fetch_chat_reports_admin(admin_token)`.

### `POST /admin/chat-reports/:id/review`

Marks one chat report as `reviewed`, `dismissed`, or `open`. Requires `moderator` or stronger. The backend stores an admin-token fingerprint, source client, optional note, and `reviewed_at`; it does not store raw admin tokens.

Request:

```json
{
  "status": "reviewed",
  "note": "handled"
}
```

### `GET /admin/chat-moderation/actions?target_player_id=player_123&action=mute&limit=50&offset=0`

Returns administrator-only active chat restrictions and recent moderation action audit rows. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.

The response is split into `active` and `recent`. `active` includes non-expired, non-revoked `mute` and `ban` actions. `recent` is the append-only operator history, including `restore` actions. `limit` caps both lists; `offset` pages `recent`; `target_player_id` and `action` filter both lists.
The standalone `ChatModerationAuditPanel` calls this through `OnlineClient.fetch_chat_moderation_admin(admin_token, target_player_id, action, offset)` and applies restores through `OnlineClient.apply_chat_moderation_admin(request, admin_token)`.

Add `format=csv` to export the same moderation audit rows as CSV for LiveOps review and support handoff. The Godot admin client exposes this as `OnlineClient.export_chat_moderation_admin(...)` and reports CSV readiness/size in the panel.

### `POST /admin/chat-moderation/actions`

Applies a chat moderation action. MVP actions are `mute`, `ban`, and `restore`. Room-scoped mutes are the default first-line action; global bans are reserved for later trust/safety workflows. `mute` and `restore` require `moderator`; `ban` requires `owner` plus `confirm:true` and a non-empty `reason`.

Request:

```json
{
  "target_player_id": "player_123",
  "target_name": "Guest",
  "action": "mute",
  "scope": "room",
  "room_id": "world_town_square",
  "duration_seconds": 3600,
  "reason": "spam",
  "report_id": "report-000001",
  "confirm": false
}
```

### `GET /admin/reviewer-audit/:id`

Returns the admin-only reviewer audit trail for one creator package. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.
Supports `action`, `status`, `source`, `limit`, and `offset` query filters. Add `format=csv` to export the filtered event stream as CSV.
The Godot reviewer console exposes per-game CSV export through `OnlineClient.export_reviewer_audit_admin(game_id, admin_token, filters)`.

Response:

```json
{
  "game_id": "creator_duel",
  "items": [
    {
      "game_id": "creator_duel",
      "action": "approve",
      "status": "approved",
      "reviewer": "admin:3e9f4a2c1b00",
      "source": "reviewer-console",
      "note": "manual verification",
      "request_id": "ops-req-123",
      "created_unix": 1777500000
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

### `POST /minigame-sessions`

Creates a concurrency-managed minigame session inside a room. Requires a bearer token matching `host_player_id`.
Responses include `created_at`, `updated_at`, and `expires_at`; clients should treat sessions past `expires_at` as stale.

Request:

```json
{
  "game_id": "fishing",
  "room_id": "world_town_square",
  "host_player_id": "player_123",
  "max_players": 4
}
```

### `GET /minigame-sessions/:room_id`

Lists active or waiting minigame sessions for a room; restricted room lists require room access.
Expired memory sessions are dropped during reads, while Redis-backed sessions expire by TTL and are pruned from room sets.

### `POST /minigame-sessions/:session_id/join`

Joins a player to a session if it is not full or ended. Requires a bearer token matching `player_id`.

Request:

```json
{
  "player_id": "player_456"
}
```

### `POST /minigame-sessions/:session_id/leave`

Removes a player from a session. Empty sessions become `ended`; requires a bearer token matching `player_id`.

### `POST /minigame-sessions/:session_id/end`

Ends a minigame session. Requires the current host player's bearer token.

### `POST /minigames/fishing/catch`

Claims one server-authoritative fishing catch reward. Requires a bearer token matching `player_id`; the player must belong to the referenced fishing session. The backend owns fish selection and coin amount.

Request:

```json
{
  "player_id": "player_123",
  "session_id": "session_000001",
  "request_id": "client-generated-uuid"
}
```

Response:

```json
{
  "player_id": "player_123",
  "session_id": "session_000001",
  "request_id": "client-generated-uuid",
  "catch_number": 1,
  "fish_id": "pond_minnow",
  "fish_name_key": "fishing.fish.pond_minnow.name",
  "reward_coin": 3,
  "balance": 28
}
```

Per MVP session, each player can claim up to 10 rewarded catches. Extra claims return `429 fishing_session_reward_cap`. Replaying the same `request_id` returns the original catch response without granting coins again; a duplicate request still in progress returns `409 fishing_request_pending`.

### `POST /economy/reward`

MVP client route is blocked with `403 server_authoritative_rewards_only`; rewards must be issued by trusted server logic.

Request:

```json
{
  "player_id": "player_123",
  "source_id": "fishing_catch",
  "amount": 10
}
```

### `POST /economy/spend`

Spends coins against a server-authoritative sink. Client UI may display prices, but the backend decides final spend rules. Requires a bearer token matching `player_id`.

Request:

```json
{
  "player_id": "player_123",
  "sink_id": "housing.simple_chair",
  "amount": 25
}
```

Insufficient funds return `402` with `error: "insufficient_funds"`.

### `GET /economy/ledger/:player_id`

Returns append-only coin events with balance-after values and checksum chaining for audit/debug. Requires a bearer token matching `player_id`.

### `GET /housing/layout/:owner_id`

Returns the saved home layout for the authenticated owner. Use `POST /housing/visit` for public read-only visits to another player's home.

Response:

```json
{
  "owner_id": "player_123",
  "version": 2,
  "items": [
    {
      "item_id": "simple_chair",
      "tile_x": 3,
      "tile_y": 2,
      "rotation": 0
    }
  ],
  "styles": {
    "wall": "starter_wallpaper",
    "floor": "wooden_floor"
  }
}
```

### `POST /housing/invite`

Creates the MVP invite payload for the authenticated owner's public home room. The client sends the localized invite text through chat.

Request:

```json
{
  "owner_id": "player_123",
  "sender_id": "player_123"
}
```

Response:

```json
{
  "owner_id": "player_123",
  "room_id": "home:player_123"
}
```

### `POST /housing/visit`

Returns a read-only visit payload for a home. MVP homes are public to authenticated players; only the owner can mutate layout or spend housing coins.

Request:

```json
{
  "owner_id": "player_123",
  "visitor_id": "player_456"
}
```

Response:

```json
{
  "owner_id": "player_123",
  "visitor_id": "player_456",
  "room_id": "home:player_123",
  "can_edit": false,
  "layout": {}
}
```

### `POST /housing/place`

Places one owned/purchased room object and spends coins using the server catalog price. Cross-owner mutations return `403 owner_mismatch`.

Request:

```json
{
  "owner_id": "player_123",
  "player_id": "player_123",
  "item_id": "simple_chair",
  "tile_x": 3,
  "tile_y": 2,
  "rotation": 0
}
```

### `POST /housing/style`

Applies a room style such as wall or floor and spends coins using the server catalog price. Cross-owner mutations return `403 owner_mismatch`.

Request:

```json
{
  "owner_id": "player_123",
  "player_id": "player_123",
  "category": "floor",
  "item_id": "wooden_floor"
}
```

### `GET /utility/panels`

Returns the backend-backed main-city utility panel registry for the authenticated player. This is the online replacement source for the local `configs/utility_panels.json` rows.

Request:

```http
GET /utility/panels?player_id=player_123
Authorization: Bearer <access-token>
```

Response:

```json
{
  "schema_version": 1,
  "player_id": "player_123",
  "server_time": 1777500000,
  "shop": {"items": [{"id": "simple_chair_offer", "item_id": "simple_chair", "action_id": "home", "action_key": "world.panel.action.home"}]},
  "mail": {"messages": [{"id": "welcome_home", "sender_key": "mail.sender.town_office", "subject_key": "mail.welcome.subject", "body_key": "mail.welcome.body", "icon_id": "icon.mail", "action_id": "home", "action_key": "world.panel.action.home"}]},
  "notice": {"notices": []}
}
```

Companion endpoints `GET /utility/shop`, `GET /utility/mail`, and `GET /utility/notices` return single sections with the same auth rule.

### `PUT /admin/utility/panels`

Replaces the live utility panel registry. Requires `owner` via `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.

The request body uses the same `schema_version`, `shop`, `mail`, and `notice` shape as `configs/utility_panels.json`. In `storage.mode=memory`, this is process-memory state seeded from config. In `storage.mode=postgres`, the current registry is stored in `utility_panel_records` and survives backend restarts.

```json
{
  "schema_version": 1,
  "shop": {"items": [{"id": "tiny_table_offer", "item_id": "tiny_table", "action_id": "home", "action_key": "world.panel.action.home"}]},
  "mail": {"messages": []},
  "notice": {"notices": []}
}
```

MVP rule: shop remains display/routing only. Coin spend is still authoritative in housing mutation endpoints until a dedicated purchase/fulfillment flow is added.

### `GET /debug/rooms`

Returns administrator-only room debug state for local QA and live-ops drilldown. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.
Godot/H5 admin tooling calls this through `OnlineClient.fetch_debug_rooms_admin(admin_token)`, and `DebugOpsPanel` renders it as room drilldown rows.

Response includes:

- `online_count`: currently connected realtime clients.
- `rooms`: per-room `connected` client count, `snapshot_players` retained in the movement snapshot, `room_type`, and `last_active_at` Unix seconds.
- `room_type`: one of `main_city`, `housing`, `minigame`, or `custom`, inferred from the room ID contract.
- `last_active_at`: newest connected-client or retained movement activity timestamp, used by H5/Godot admin tooling to show stale rooms.
- `realtime`: fanout, rate-limit, leave, and local-delivery counters.

### `GET /debug/ops`

Returns an administrator-only operational snapshot for local QA and live-ops triage. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.
Godot/H5 admin tooling calls this through `OnlineClient.fetch_debug_ops_admin(admin_token)`, and the internal `LiveOpsConsolePanel` renders the snapshot through `DebugOpsPanel`.

Response includes:

- `rooms`: current room/player snapshot.
- `realtime`: fanout, rate-limit, leave, and local-delivery counters.
- `chat`: message totals by room/channel, report totals by room, moderation action counts, active moderation counts, and soft rate-limit rejection counts.
- `fishing_rewards`: trusted reward grants, replays, caps, pending requests, errors, active counters, and stored request count.

## WebSocket Envelope

```json
{
  "schema_version": 1,
  "type": "chat.send",
  "request_id": "client-request-id",
  "sent_at": 1777392000,
  "payload": {}
}
```

## Message Types

- `world.join` / `world.leave` / `world.snapshot`
- `auth.failed`
- `player.move`
- `chat.send`
- `chat.history`
- `chat.message` with optional `message.action.type == "join_minigame"`
- `presence.heartbeat`
- `presence.members`
- `emote.send`
- `emote.event`
- `housing.invite`
- `housing.visit`
- `housing.place_item`
- `housing.save_layout`
- `minigame.session_create`
- `minigame.session_join`
- `minigame.session_leave`
- `minigame.session_end`
- `fishing.catch`
- `economy.grant_reward`
- `economy.spend`
- `economy.ledger`
- `minigame.submit`
- `minigame.review_queued`

## Redis MVP Keys

- `presence:{room_id}:{player_id}` with heartbeat TTL
- `auth:access:{token}` and `auth:refresh:{token}` with configured TTL
- `auth:linked:{provider}:{provider_subject}` persistent account link record
- `room:{room_id}:members`
- `room:{room_id}:minigame_sessions`
- `minigame_session:{id}`
- `chat:{scope}:{id}` stream
- `room:{room_id}:fanout` Redis pub/sub for realtime room messages
- `rate:{player_id}:{action}`
- `minigame:fishing:count:{session_id}:{player_id}`
- `minigame:fishing:request:{session_id}:{player_id}:{request_id}`
- `home:{owner_id}:layout`
- `ledger:{player_id}` append-only coin events

## Verified Local E2E

Local E2E: start backend on `:18787`, then run `tests/auth_upgrade_backend_e2e.gd`, `tests/reviewer_console_backend_e2e.gd`, `tests/online_backend_e2e.gd`, and `tests/realtime_backend_e2e.gd`; checks cover H5 guest account upgrade, reviewer dashboard/action flow, refresh, admin gates, `/debug/ops`, spoof rejection, owner checks, room-scoped realtime chat broadcast, housing invite/visit, house presence/chat, trusted fishing rewards, request-id replay, backend ledger writes, and blocked public rewards.

## First Vertical Slice

1. Guest login.
2. WebSocket connect to `/ws/city` and join `world_town_square` with an access token.
3. Send room-scoped `player.move` and `emote.send`.
4. Send and receive global chat.
5. Create or join a minigame session in the current room.
6. Submit `fishing.catch`.
7. Server-side rewards append coins through the ledger; public client rewards stay blocked.
8. Spend coins to place a housing item.
9. Invite another player to visit the home and chat in `home:<owner_id>`.
10. Verify visitors cannot mutate the owner's layout.
11. Submit a creator minigame manifest through admin review and receive `pending_review`.
