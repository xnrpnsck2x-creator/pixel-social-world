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
- `postgres`: persists economy wallet/ledger, housing layout, player world-map discovery, map activity cooldowns, map activity daily reward fatigue, inventory escrow, trade listings, and trade event history.
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

### `GET /players/maps/discovered?player_id=...`

Returns the authenticated player's discovered world-map ids and unlock records.
Requires a bearer token matching `player_id`. The backend always includes the
starter map `city_forest_dawn_v1`.

Response:

```json
{
  "player_id": "player_123",
  "map_ids": ["city_forest_dawn_v1", "city_port_market_v1"],
  "maps": [
    {
      "map_id": "city_forest_dawn_v1",
      "source": "default",
      "discovered_at": 1777545600
    },
    {
      "map_id": "city_port_market_v1",
      "source": "arrival",
      "discovered_at": 1777545700
    }
  ],
  "updated_at": 1777545700
}
```

### `POST /players/maps/discovered`

Marks one world map as discovered for the authenticated player. Requires a
bearer token matching `player_id`. `map_id` accepts catalog ids only in the
lowercase `a-z`, `0-9`, `_`, and `-` shape. Player-facing unlock sources are
`arrival`, `npc`, `item`, and `event`; `default`, `sync`, and `admin` are
reserved for system migration and operator tooling.

Request:

```json
{
  "player_id": "player_123",
  "map_id": "city_port_market_v1",
  "source": "arrival"
}
```

### `POST /players/maps/discovered/sync`

Merges the client's local discovered-map cache into the backend and returns the
server-authoritative union. Godot should call this when entering the main city;
offline clients keep `discovered_world_map_ids` as a local fallback and replay
it on the next online session. The first stored source wins; later arrival or
sync calls do not overwrite a route originally unlocked by NPC, item, event, or
admin tooling.

Request:

```json
{
  "player_id": "player_123",
  "map_ids": ["city_forest_dawn_v1", "life_fishing_riverbend_v1"],
  "source": "sync"
}
```

### `POST /admin/players/maps/discovered`

Owner-only LiveOps grant for a player's world-map route. Requires an owner admin
token and `confirm: true`; it writes the route with source `admin` without
requiring the target player's bearer token.

Request:

```json
{
  "player_id": "player_123",
  "map_id": "social_trade_market_v1",
  "confirm": true,
  "note": "alpha route grant"
}
```

Response wraps the updated discovery payload plus an `operator_id` fingerprint;
raw admin tokens are never echoed.

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

Store auth provider release handoff:

- `docs/StoreAuthProviderHandoff.md` is the release checklist for Apple/Google
  production auth.
- `scripts/check_store_auth_provider_handoff.sh` verifies the checklist,
  no-secret contract, strict `oidc_jwt` env requirements, and fail-closed
  behavior when provider env is absent.
- On the release machine, set `PSW_STORE_AUTH_PROVIDER_REQUIRED=1` with
  `PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt`, `PSW_APPLE_CLIENT_IDS`, and
  `PSW_GOOGLE_CLIENT_IDS` before public alpha auth is enabled.

### `GET /city/state`

Returns the current main city snapshot for initial entry and reconnect.

MVP player movement fields are defined in `docs/MultiplayerSync.md`.

### `GET /ws/city`

Upgrades to the city WebSocket. After connecting, clients send `world.join`
with the bearer token and target `room_id`; the Go room hub validates the
session, authorizes restricted rooms, applies room capacity policy, and then
broadcasts room-scoped movement, chat, presence, emote, and housing events.

The endpoint is intentionally a transport entry point. Message envelopes and
message types are defined below in `WebSocket Envelope` and `Message Types`.

### `POST /presence/heartbeat`

Refreshes player presence in a room with a TTL. Requires a bearer token matching `player_id` and room access.

### `GET /rooms/:room_id/members`

Returns non-expired room members. Restricted rooms require `player_id` query plus matching bearer token.

Room capacity policy is enforced at WebSocket `world.join` time before a socket
is assigned to a room. Defaults are intentionally conservative for first alpha:
`world_town_square` 100, `home:*` 20, `minigame:*` 16, custom rooms 50.
Override with `PSW_MAIN_CITY_ROOM_CAPACITY`, `PSW_HOUSING_ROOM_CAPACITY`,
`PSW_MINIGAME_ROOM_CAPACITY`, and `PSW_CUSTOM_ROOM_CAPACITY`.

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
If either player has blocked the other through `/social/block`, private sends
return `403 {"error":"private_message_blocked"}` before a durable message is
created.

### `GET /private-messages?player_id=...&limit=50&offset=0`

Returns the authenticated player's durable private conversation summaries,
newest first. Each row includes `conversation_id`, `peer_id`, `latest_message`,
`latest_at`, and `unread_count`. This powers the client private-chat list and
HUD unread badge without persisting room chat.
`limit` is capped at 100 and `offset` is zero-based for older pages.

### `GET /private-messages/:peer_id?player_id=...&limit=50&offset=0`

Returns the authenticated player's durable conversation with `peer_id` in
chronological order. Requires a bearer token matching `player_id`. MVP limit is
capped at 100. Page `offset=0` returns the newest tail page, still ordered
oldest-to-newest within that page; increasing `offset` walks backward through
older durable messages.

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

### Social Relationships

The player profile card exposes follow and block actions through the social
relationship contract. Requires a bearer token matching `player_id`.

- `GET /social/state/:target_player_id?player_id=...`
- `GET /social/following?player_id=...&limit=50`
- `POST /social/follow`
- `POST /social/unfollow`
- `POST /social/block`
- `POST /social/unblock`

Request body for mutating actions:

```json
{
  "player_id": "player_123",
  "target_player_id": "player_456"
}
```

Response state:

```json
{
  "player_id": "player_123",
  "target_player_id": "player_456",
  "following": true,
  "followed_by": false,
  "blocked": false,
  "blocked_by": false,
  "updated_at": 1777545600
}
```

Self-follow or self-block returns `409 self_relationship_forbidden`.

### `GET /social/facilities`

Returns the authenticated player's social facility catalog. Requires a bearer
token matching the `player_id` query. The catalog is the backend-backed source
for facility panels such as trade and guild surfaces.

Response:

```json
{
  "schema_version": 1,
  "player_id": "player_123",
  "server_time": 1777545600,
  "facilities": {
    "trade": {
      "map_id": "social_trade_market_v1",
      "status": "local_contract",
      "title_key": "facility.trade.title",
      "body_key": "facility.trade.body",
      "detail_key": "facility.trade.detail",
      "icon_id": "icon.coin",
      "rows": []
    }
  }
}
```

### `GET /social/facilities/:id`

Returns one facility definition from the same authenticated catalog. Unknown
facility IDs return `404 facility_not_found`.

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

### `GET /mailbox/inbox?player_id=...&limit=50&offset=0`

Returns the authenticated player's mailbox messages, newest first. Requires a
bearer token matching `player_id`. The legacy `GET /utility/mail` endpoint is
only the static utility-panel feed; player mailbox data must use `/mailbox/*`.
`limit` is capped at 100 and `offset` is zero-based for older pages.

### `POST /mailbox/:mail_id/read`

Marks a mailbox message as read and returns the updated message. Requires a
bearer token matching the body `player_id`, and the player must be the mailbox
recipient. Unauthorized recipient access returns `403 {"error":"mail_forbidden"}`.

## Data Retention Policy

The MVP storage boundary is explicit:

- Room chat history: `0` days. Room chat is live-only, not a durable record,
  and should disappear after logout/reconnect.
- Private messages: durable sender/recipient conversations, default 365 days.
- Mailbox messages: durable recipient-scoped mail, default 365 days.
- Reports and moderation snapshots: default 730 days.
- Economy ledger: default 2555 days for audit and creator payout debugging.
- Creator review/audit rows: default 730 days.
- Creator artifact staging files: default 30 days before cleanup candidates.

Configuration keys live under `retention:` in YAML and can be overridden with:
`PSW_ROOM_CHAT_HISTORY_DAYS`, `PSW_PRIVATE_MESSAGE_RETENTION_DAYS`,
`PSW_MAILBOX_RETENTION_DAYS`, `PSW_REPORT_RETENTION_DAYS`,
`PSW_LEDGER_RETENTION_DAYS`, `PSW_CREATOR_AUDIT_RETENTION_DAYS`, and
`PSW_CREATOR_ARTIFACT_STAGING_DAYS`. Validation enforces room chat at `0`.

`pixel-social-world-retention-cleanup` enforces durable PostgreSQL retention.
It defaults to dry-run; production enables
`pixel-social-world-retention-cleanup.timer`, which executes the same plan
daily. Filesystem creator-artifact staging is reported as a separate storage
boundary so raw package cleanup can later use storage-specific lifecycle rules.

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

Successful `place`, `style`, `move`, and `remove` mutations broadcast
`housing.layout.updated` to `home:<owner_id>` so visitors and the owner can
apply the new layout without polling. Payload fields:

- `owner_id`, `room_id`, and `version`.
- `action`: one of `place`, `style`, `move`, or `remove`.
- `layout`: the latest server-authoritative layout object.

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

### `GET /admin/action-audit?action=&target_type=&target_id=&role=&limit=100&offset=0`

Returns the unified in-process admin action audit stream. Requires `viewer` or
stronger via `X-Admin-Token: <token>` or
`Authorization: Bearer <admin-token>`.

The endpoint is intentionally a compact LiveOps/support index, not a durable
compliance store. It keeps the newest 200 successful high-risk actions for the
running process and never stores or returns raw admin tokens. Operator identity
is represented as the same `admin:<hash>` fingerprint used by reviewer and
moderation audit rows.

Covered MVP actions:

- `chat_moderation.apply`: mute, restore, and ban operations.
- `chat_report.review`: chat report status review.
- `minigame.review`: creator package review, publish, rollback, and unpublish.
- `economy.creator_share.grant`: owner-triggered creator settlement grants.
- `player_map.discover`: owner LiveOps map grants.
- `utility_panels.update`: owner live utility panel registry updates.

Response:

```json
{
  "items": [
    {
      "id": "admin_action_000001",
      "action": "player_map.discover",
      "actor_id": "admin:3e9f4a2c1b00",
      "role": "owner",
      "source": "liveops-console",
      "target_type": "player_map",
      "target_id": "player_123:social_trade_market_v1",
      "status": "unlocked",
      "note": "manual grant for alpha test",
      "confirmed": true,
      "request_id": "ops-req-123",
      "created_at": 1777940000,
      "metadata": {"player_id": "player_123", "map_id": "social_trade_market_v1"}
    }
  ],
  "count": 1,
  "matched": 1,
  "limit": 100,
  "offset": 0,
  "server_time": 1777940000
}
```

### `GET /admin/session`

Returns the authenticated admin role, capability list, and actions that require explicit confirmation. Viewer capabilities include `read_ops`, `read_admin_action_audit`, `read_trade_history`, and `read_creator_payouts`. Requires any valid admin token. Godot/H5 tooling calls this through `OnlineClient.fetch_admin_session(admin_token)`.

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

Per MVP session, each player can claim up to 10 rewarded catches. Extra claims return `429 fishing_session_reward_cap`. Replaying the same `request_id` returns the original catch response without granting coins again; a duplicate request still in progress returns `409 fishing_request_pending`. `reward_coin` is the actual granted delta after the economy daily soft cap, so it can be lower than the fish table value when the cap is reached.

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

### `POST /economy/first-session/claim`

Claims the one-time first-session guide reward. Requires a bearer token matching
`player_id`. The backend validates that the required guide step IDs are present
and grants `first_session.guide_complete` exactly once through the economy
ledger. Replays are idempotent and return `delta: 0`.

Request:

```json
{
  "player_id": "player_123",
  "completed_step_ids": [
    "npc_met",
    "map_opened",
    "trade_opened",
    "games_opened",
    "chat_sent"
  ]
}
```

Response:

```json
{
  "player_id": "player_123",
  "balance": 30,
  "delta": 5,
  "source_id": "first_session.guide_complete",
  "claimed": true
}
```

Incomplete guide state returns `400 first_session_incomplete`.

### `POST /map-activities/claim`

Claims a server-authoritative map activity reward and cooldown. Requires a
bearer token matching `player_id`. The backend validates that `action_id` is
allowed on `map_id`, applies per-player/per-map/per-action cooldown, applies
per-player/per-day/per-action reward fatigue for coin-bearing activities, and
returns the wallet balance from the economy service.

The route is config-driven in both memory and PostgreSQL modes: activity
rules load from `configs/map_activities.json`, and map/action scope loads from
`configs/map_points.json`. Backend startup and preflight must fail if these
contracts cannot be parsed, so generated map metadata and economy rewards do
not silently drift apart.

Request:

```json
{
  "player_id": "player_123",
  "map_id": "random_flower_valley_v1",
  "action_id": "explore"
}
```

Response:

```json
{
  "player_id": "player_123",
  "map_id": "random_flower_valley_v1",
  "action_id": "explore",
  "reward_coins": 1,
  "skill_id": "exploration",
  "skill_xp": 2,
  "drops": [{"item_id": "trail_token", "amount": 1, "rarity": "common"}],
  "cooldown_seconds": 35,
  "daily_reward_limit": 10,
  "daily_reward_count": 1,
  "ready_at": 1777545635,
  "ready_in_seconds": 35,
  "server_time": 1777545600,
  "claimed": true,
  "wallet": {"player_id": "player_123", "balance": 26, "delta": 1},
  "inventory_items": [
    {"player_id": "player_123", "item_id": "trail_token", "owned": 1, "locked": 0, "available": 1}
  ]
}
```

Cooldown returns `429 activity_cooldown` with the same timing fields. Daily
fatigue returns `429 activity_daily_limit` with `daily_reward_limit` and
`daily_reward_count`, does not grant coins, and does not write a new cooldown.
Invalid map/action pairs return `400 activity_not_on_map`; unknown actions
return `400 unknown_activity`.

Map activity gameplay rewards are config-driven through
`configs/map_activities.json`: `skill_id`, `skill_xp`, `drops`, and optional
deterministic `rare_event` are returned only on successful claims. Successful
online claims also grant configured drops into the backend inventory service and
return the affected `inventory_items` rows. Coins stay server-authoritative
through `wallet.balance`; drop counts are server-authoritative for online
sessions and can be rendered locally from `inventory_items`.

### `GET /economy/policy`

Admin read-only endpoint exposing current economy policy knobs. MVP includes
`creator_share_bps`, the basis-point share granted to a creator when trusted
server logic settles play rewards for a creator minigame, and
`daily_soft_cap`, the per-player daily reward grant cap.

### `POST /economy/creator-share`

Owner-only trusted settlement endpoint for creator minigames. It grants the
player's play reward and the creator's revenue share in one server-side ledger
transaction. Normal clients must not call this directly.
`source_id` is required and acts as the idempotency key; replaying the same
settlement returns current balances without duplicating player or creator
ledger events.

Request:

```json
{
  "player_id": "player_123",
  "creator_id": "player_creator",
  "game_id": "creator_duel",
  "source_id": "creator.play.creator_duel",
  "player_amount": 50
}
```

With the default `creator_share_bps: 1000`, the creator receives `5` coins for
a `50` coin player reward. If the player's `daily_soft_cap` leaves only `20`
coins available, the player receives `20` and the creator share is recalculated
from that capped grant.

Creator reward ledger rows store `game_id` for both the player's
`creator.play_reward` event and the creator's `creator.revenue_share` event,
so LiveOps can drill into payout totals by creator and minigame.

### `GET /admin/economy/creator-payouts`

Admin read-only creator payout drilldown. Requires a viewer-or-higher admin
token and accepts `limit` with a max of 50. The response groups
`creator.revenue_share` ledger events by `creator_id` and `game_id`, ordered by
revenue coins descending.

```json
{
  "request_id": "psw-...",
  "server_time": 1777545600,
  "items": [
    {
      "creator_id": "player_creator",
      "game_id": "creator_duel",
      "revenue_events": 3,
      "revenue_coins": 15,
      "last_revenue_at": 1777545590,
      "recent_source_id": "creator.play.creator_duel.3"
    }
  ],
  "count": 1,
  "matched": 1,
  "limit": 8,
  "total_creators": 1,
  "total_revenue_events": 3,
  "total_revenue_coins": 15
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

### `GET /inventory`

Returns the authenticated player's shared inventory escrow state. Requires a
bearer token matching the `player_id` query. This is the authoritative MVP
inventory surface for starter items, map-activity drops, and future minigame or
housing rewards. Items expose `owned`, `locked`, and `available`; marketplace
listing creation locks one `available` count through the inventory service.

Response:

```json
{
  "server_time": 1777545600,
  "items": [
    {
      "player_id": "player_123",
      "item_id": "trail_token",
      "owned": 1,
      "locked": 0,
      "available": 1
    }
  ]
}
```

### `GET /admin/inventory/audit`

Admin read-only inventory audit endpoint. Requires a viewer-or-higher admin
token. Optional `player_id` narrows the audit to one player; without it the
service returns the default normalized player scope used by the inventory
service.

The response exposes item rows, reservation-source totals, and diagnostic flags
such as `locked_without_reservation`, `reservation_exceeds_locked`, and
`unknown_reservation_reason`. It is for LiveOps/support triage and does not
repair inventory.

Response:

```json
{
  "player_id": "player_123",
  "server_time": 1777545600,
  "totals": {
    "items": 2,
    "owned": 2,
    "locked": 1,
    "available": 1,
    "reservation_count": 1,
    "housing_reservations": 1,
    "trade_reservations": 0,
    "legacy_reservations": 0,
    "other_reservations": 0,
    "locked_without_reservation": 0
  },
  "flags": [],
  "items": []
}
```

### `GET /trade/listings`

Returns player listings for the trade market. Requires a bearer token matching
the `player_id` query. V1 listings are server-authoritative; clients may render
price and status, but they must not mutate wallet balances locally.
Active listings have `escrow_status: "locked"`, sold listings have
`"delivered"`, and cancelled listings have `"returned"`.

Response:

```json
{
  "server_time": 1777545600,
  "items": [
    {
      "id": "trade_player_123_1777545600000",
      "seller_id": "player_123",
      "item_id": "simple_chair",
      "title_key": "facility.trade.listing.simple_chair.title",
      "body_key": "facility.trade.listing.simple_chair.body",
      "icon_id": "icon.home",
      "price": 7,
      "status": "active",
      "escrow_status": "locked",
      "created_unix": 1777545600,
      "updated_unix": 1777545600
    }
  ]
}
```

### `GET /trade/inventory`

Compatibility alias for `GET /inventory`, kept for the trade market UI. New
clients should prefer `GET /inventory` and let trade-specific UI consume that
same authoritative item state.

Response:

```json
{
  "server_time": 1777545600,
  "items": [
    {
      "player_id": "player_123",
      "item_id": "simple_chair",
      "owned": 1,
      "locked": 0,
      "available": 1
    }
  ]
}
```

### `GET /trade/history`

Returns the recent server-authoritative trade event stream for compact market
confidence UI. Requires a bearer token matching the `player_id` query.
`limit` defaults to 10 and is capped at 50. Events are created when a listing is
posted, sold, or cancelled; clients render this as read-only history and must
not infer wallet state from it.

Response:

```json
{
  "server_time": 1777545600,
  "items": [
    {
      "id": "trade_event_01777545600000000000_sold_trade_player_123",
      "type": "sold",
      "listing_id": "trade_player_123_1777545600000",
      "seller_id": "player_123",
      "buyer_id": "player_456",
      "item_id": "simple_chair",
      "title_key": "facility.trade.listing.simple_chair.title",
      "icon_id": "icon.home",
      "price": 7,
      "created_unix": 1777545600
    }
  ]
}
```

### `GET /admin/trade/history`

Owner/viewer LiveOps read path for the same trade event stream. Requires an
admin bearer token. Supported filters: `type`, `player_id`, `seller_id`,
`buyer_id`, `item_id`, `listing_id`, `limit`, and `offset`. This endpoint is
read-only and must never expose raw admin tokens or mutate player inventory.
Add `format=csv` to export the filtered page as CSV for LiveOps support handoff.
CSV export uses the same capped pagination as JSON, so production operators
must page large investigations instead of dumping the full event table.

Response:

```json
{
  "server_time": 1777545600,
  "count": 1,
  "matched": 1,
  "limit": 25,
  "offset": 0,
  "items": [
    {
      "id": "trade_event_01777545600000000000_sold_trade_player_123",
      "type": "sold",
      "listing_id": "trade_player_123_1777545600000",
      "seller_id": "player_123",
      "buyer_id": "player_456",
      "item_id": "simple_chair",
      "title_key": "facility.trade.listing.simple_chair.title",
      "icon_id": "icon.home",
      "price": 7,
      "created_unix": 1777545600
    }
  ]
}
```

### `POST /trade/listings`

Creates a server-side listing. Requires a bearer token matching `seller_id`.
The backend locks one available inventory item at listing creation. A player
cannot list the same one-count item twice; unavailable inventory returns
`409 item_unavailable`.

Request:

```json
{
  "seller_id": "player_123",
  "item_id": "simple_chair",
  "title_key": "facility.trade.listing.simple_chair.title",
  "body_key": "facility.trade.listing.simple_chair.body",
  "icon_id": "icon.home",
  "price": 7
}
```

Response:

```json
{
  "listing": {
    "id": "trade_player_123_1777545600000",
    "seller_id": "player_123",
    "item_id": "simple_chair",
    "price": 7,
    "status": "active",
    "escrow_status": "locked"
  }
}
```

Invalid listings return `400 invalid_listing`.

### `POST /trade/listings/:id/buy`

Purchases an active listing through backend escrow. Requires a bearer token
matching `buyer_id`. The server rejects self-purchase, inactive listings, and
insufficient funds. Successful purchase atomically writes:

- buyer ledger event: `transfer.out`
- seller ledger event: `transfer.in`
- listing status: `sold`
- seller locked inventory decremented and owned count reduced
- buyer owned inventory incremented

Request:

```json
{
  "buyer_id": "player_456"
}
```

Response:

```json
{
  "listing": {
    "id": "trade_player_123_1777545600000",
    "seller_id": "player_123",
    "buyer_id": "player_456",
    "item_id": "simple_chair",
    "price": 7,
    "status": "sold",
    "escrow_status": "delivered"
  },
  "transfer": {
    "from": {"player_id": "player_456", "balance": 18, "delta": -7},
    "to": {"player_id": "player_123", "balance": 32, "delta": 7},
    "amount": 7
  },
  "item_transfer": {
    "item_id": "simple_chair",
    "quantity": 1,
    "from": {"player_id": "player_123", "item_id": "simple_chair", "owned": 0, "locked": 0, "available": 0},
    "to": {"player_id": "player_456", "item_id": "simple_chair", "owned": 2, "locked": 0, "available": 2}
  }
}
```

Error statuses:

- `402 insufficient_funds`
- `403 self_purchase_forbidden`
- `404 listing_not_found`
- `409 item_unavailable` or `listing_inactive`

### `POST /trade/listings/:id/cancel`

Cancels an active listing. Requires a bearer token matching `seller_id`.
Cancelled or sold listings cannot be purchased. Cancelling returns the locked
item to the seller inventory by decrementing `locked` and restoring
`available`.

Request:

```json
{
  "seller_id": "player_123"
}
```

Response:

```json
{
  "listing": {
    "id": "trade_player_123_1777545600000",
    "seller_id": "player_123",
    "item_id": "simple_chair",
    "price": 7,
    "status": "cancelled",
    "escrow_status": "returned"
  }
}
```

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

### `POST /housing/move`

Moves an existing placed item. Requires a bearer token matching `player_id`;
only the owner can mutate the layout. The backend validates that the referenced
item exists in the layout, applies placement rules at the target tile, bumps the
layout version, and broadcasts `housing.layout.updated` to `home:<owner_id>`.

Request:

```json
{
  "owner_id": "player_123",
  "player_id": "player_123",
  "item_id": "simple_chair",
  "tile_x": 3,
  "tile_y": 2,
  "rotation": 0,
  "target_tile_x": 4,
  "target_tile_y": 2,
  "target_rotation": 0
}
```

Response:

```json
{
  "layout": {
    "owner_id": "player_123",
    "version": 3,
    "items": []
  }
}
```

### `POST /housing/remove`

Removes an existing placed item. Requires a bearer token matching `player_id`;
only the owner can mutate the layout. The backend releases a housing inventory
reservation when the item came from inventory, otherwise it grants the configured
sell refund when applicable. Successful removes broadcast `housing.layout.updated`.

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

Response:

```json
{
  "layout": {
    "owner_id": "player_123",
    "version": 4,
    "items": []
  },
  "balance": 25,
  "refund": 0,
  "inventory_items": []
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
- `capacity`: configured room cap for the inferred room type.
- Per-room realtime counters include `local_broadcasts`, `local_delivery_target`, `local_delivered`, `movement_culled`, `slow_writes`, and `write_failed`.
- `realtime`: fanout publish/receive/failure, rate-limit, leave, culling, write-backpressure, and local-delivery counters.

### `GET /debug/ops`

Returns an administrator-only operational snapshot for local QA and live-ops triage. Requires `X-Admin-Token: <token>` or `Authorization: Bearer <admin-token>`.
Godot/H5 admin tooling calls this through `OnlineClient.fetch_debug_ops_admin(admin_token)`, and the internal `LiveOpsConsolePanel` renders the snapshot through `DebugOpsPanel`.

Response includes:

- `rooms`: current room/player snapshot.
- `realtime`: fanout publish/receive/failure, rate-limit, leave, culling, write-backpressure, and local-delivery counters.
- `chat`: message totals by room/channel, report totals by room, moderation action counts, active moderation counts, and soft rate-limit rejection counts.
- `fishing_rewards`: trusted reward grants, replays, caps, pending requests, errors, active counters, and stored request count.
- `economy`: ledger event totals, grant/spend counters, reward cap hits, creator play reward count, creator revenue-share count, and creator revenue coins.
- `creator_payouts`: compact creator/game payout drilldown equivalent to `/admin/economy/creator-payouts?limit=5`.
- `economy_policy`: creator share basis points and daily reward soft cap.
- `admin_action_audit`: in-process action audit count, max retained events, and last event ID.
- `alerts`: Public Alpha threshold snapshot with `highest_severity`, `count`, `items`, `open_reports`, `admin_missing_notes`, `movement_culled_rate`, `trade`, and `thresholds_version`. The `trade` block includes gateway counters for inactive buys, insufficient funds, settlement failures, and recent event-derived cancel/high-price listing stats.
- `retention_policy`: room-chat, private-message, mailbox, report, ledger, creator-audit, and artifact-staging retention windows.
- `retention_cleanup_plan`: non-destructive cleanup task metadata for ops tooling; room chat is marked `memory_only` / `ephemeral`, while durable stores expose table, cutoff column, and parameterized SQL shape.

### `GET /debug/ops/alerts`

Returns the same Public Alpha alert snapshot as `/debug/ops.alerts` without the heavier room, chat, economy, and cleanup payloads. Requires the same admin token rules as `/debug/ops`.

Response:

```json
{
  "request_id": "psw-...",
  "alerts": {
    "generated_at": 1777392000,
    "thresholds_version": "public-alpha-2026-05-05",
    "highest_severity": "warning",
    "count": 1,
    "open_reports": 21,
    "admin_missing_notes": 0,
    "movement_culled_rate": 0,
    "items": [
      {
        "area": "moderation",
        "code": "open_chat_reports",
        "severity": "warning",
        "value": 21,
        "warning": 20,
        "critical": 50
      }
    ]
  }
}
```

`GET /debug/ops/alerts?format=prometheus` returns a text metrics view for a lightweight poller. The exported series include `psw_liveops_alerts_active`, `psw_liveops_alerts_severity`, and `psw_liveops_alert_item`. When active alerts exist, the endpoint also writes a structured `liveops_alert_snapshot` JSON line to the normal server log; `emit_log=1` forces a log line even when severity is `ok`.

Production monitoring release handoff:

- `docs/ProductionMonitoringHandoff.md` is the checklist for health/readiness,
  LiveOps alert polling, systemd alert probe/timer evidence, and rollback
  metrics.
- `scripts/check_production_monitoring_handoff.sh` verifies the checklist,
  systemd packaging, no-secret monitoring contract, and strict-mode fail-closed
  behavior when monitoring env is absent.
- On the release host, set `PSW_PRODUCTION_MONITORING_REQUIRED=1` with
  `PSW_LIVEOPS_ALERT_ENDPOINT` and either `PSW_LIVEOPS_ALERT_TOKEN` or
  `PSW_ADMIN_TOKEN` before public alpha monitoring is considered ready.

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
- `room.denied` with `error:"room_access_denied"` or `error:"room_capacity_full"`
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
- `housing.layout.updated`
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

Slow or blocked WebSocket writes are counted in `/debug/ops`. A failed write is
closed immediately so the read loop can retire the client and emit normal leave
cleanup instead of letting a blocked socket consume broadcast work indefinitely.
Dense rooms keep social events room-wide, but `player.move` fanout is filtered
by server-side interest range once the room reaches 50 joined players.
In `realtime.mode=redis`, gateway-level smoke coverage verifies that separate
HTTP/WebSocket server instances can share Redis auth, rate limiting, and room
pub/sub so `player.move` and `chat.message` cross instance boundaries.

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

Local E2E: start backend on `:18787`, then run `tests/auth_upgrade_backend_e2e.gd`, `tests/reviewer_console_backend_e2e.gd`, `tests/online_backend_e2e.gd`, and `tests/realtime_backend_e2e.gd`; checks cover H5 guest account upgrade, reviewer dashboard/action flow, refresh, admin gates, `/debug/ops`, spoof rejection, owner checks, room-scoped realtime chat broadcast, housing invite/visit, house presence/chat, trusted fishing rewards, map activity rewards/cooldowns, request-id replay, backend ledger writes, and blocked public rewards.

Gateway Redis smoke: `TestRedisRealtimeFanoutCrossesGatewayInstances` starts
two independent gateway instances against miniredis and verifies cross-instance
movement, room chat, fanout counters, and zero write failures.
`TestRedisRealtimeFanoutMultiClientLoadProfile` extends this into a
configurable multi-client two-gateway profile through
`PSW_WS_REDIS_LOAD_SMOKE_CLIENTS`.

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
