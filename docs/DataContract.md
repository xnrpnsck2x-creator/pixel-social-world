# Data Contract

## General Rules

- JSON is the source of truth for MVP content registries.
- IDs are stable English snake_case values.
- Player-facing labels and descriptions must be localization keys.
- Optional fields should have safe runtime defaults.
- Unknown fields should be ignored by readers unless a schema version requires strict behavior.

## `configs/app.json`

Required fields:

- `schema_version`: integer schema marker.
- `app_id`: stable app identifier.
- `version`: client version used by runtime minimum-version gates.
- `app_name_key`: localization key for the app name.
- `default_locale`: fallback locale.
- `supported_locales`: locale list.
- `startup_route`: route ID from `scene_routes`.
- `content_paths`: map of registry names to resource paths.

Network fields:

- `network.online_enabled`: whether the client should attempt REST calls before offline fallback.
- `network.base_url`: REST backend base URL.
- `network.websocket_url`: realtime city WebSocket URL.
- `network.http_timeout_seconds`: short timeout for local-dev fallback.
- `offline_mode_enabled`: whether failed online calls may continue with local save data.

Runtime config fields:

- `runtime_config.enabled`: whether the trusted app shell should try runtime overrides during boot.
- `runtime_config.url`: optional external JSON URL. Relative `/...` URLs resolve against the H5 origin.
- `runtime_config.local_fallback_path`: bundled JSON fallback used when the external URL is unavailable.
- `runtime_config.timeout_seconds`: short fetch timeout so boot does not hang.

`configs/runtime_overrides.json` is the bundled fallback. Public H5 releases may
serve `/runtime_config.json` outside the Godot `.pck` so operations can change
API endpoints, maintenance metadata, and feature flags without rebuilding the
client.

Login/runtime gate fields:

- `maintenance.enabled`: when true, login is blocked before any world/session entry.
- `maintenance.message_key`: optional localized detail key shown by the trusted login shell.
- `min_client_version`: blocks clients whose bundled `configs/app.json.version` is lower.
- `web_build`: optional deploy/build label for operations and diagnostics.

Allowed runtime override fields:

- `network.environment`
- `network.online_enabled`
- `network.base_url`
- `network.websocket_url`
- `network.http_timeout_seconds`
- `network.presence_tick_seconds`
- `network.reconnect_attempts`
- `feature_flags.*` boolean values
- `maintenance`
- `min_client_version`
- `web_build`

Session storage keys, content paths, route IDs, and creator/minigame contracts
are not runtime-overridable.

## `configs/scene_routes.json`

Top-level fields:

- `schema_version`: integer schema marker.
- `routes`: array of route objects.

Route fields:

- `id`: unique route ID.
- `path`: Godot resource path to a `.tscn`.
- `type`: route group such as `system`, `world`, `housing`, `minigame`, or `ui`.
- `title_key`: localization key for UI display.
- `requires_network`: whether the route expects online services.
- `preload`: whether the route should be loaded during boot.

## `configs/chat_channels.json`

Channel fields:

- `id`: unique channel ID.
- `name_key`: localized channel name.
- `description_key`: localized channel description.
- `scope`: delivery scope.
- `persistence`: `ephemeral` for live room chat, `persistent` for durable private chat/mail surfaces.
- `default_join`: whether new sessions join automatically.
- `player_can_post`: whether player messages are accepted.
- `max_message_length`: per-message character limit.
- `history_limit`: number of recent messages retained in UI.
- `moderation_profile`: profile name consumed by chat systems.

Persistence policy:

- Room chat channels (`global`, `nearby`, `house`, `party`, `system`) are ephemeral. They can be broadcast live, rate-limited, and reported while online, but they are not restored through history after reconnect/logout.
- Private chat and mail are persistent product surfaces. They should not reuse room chat history semantics; they require dedicated durable storage and recipient-scoped access checks.

## Backend Messaging Records

Private message fields:

- `id`: server-generated durable private message ID.
- `conversation_id`: deterministic sorted sender/recipient pair key.
- `sender_id`: authenticated sender.
- `recipient_id`: recipient player.
- `body`: trimmed message body, capped by backend validation.
- `created_at`: Unix seconds.

Private conversation summary fields:

- `conversation_id`: deterministic sorted sender/recipient pair key.
- `peer_id`: the other player in this conversation.
- `latest_message`: latest private message snapshot.
- `latest_at`: latest message Unix seconds.
- `unread_count`: recipient-side unread private messages since the player's read marker.

Private read marker fields:

- `conversation_id`: durable conversation key.
- `player_id`: owner of this read state.
- `last_read_at`: Unix seconds used to clear unread private message counts.

Private report fields:

- `id`: server-generated report ID.
- `message_id`: target private message ID.
- `reporter_id`: authenticated participant submitting the report.
- `reason`: normalized report reason, defaulting to `player_report`.
- `status`: moderation state, starting as `open`.
- `message_sender_id`: target message sender snapshot.
- `message_recipient_id`: target message recipient snapshot.
- `message_body`: target message body snapshot.
- `message_created_at`: target message Unix seconds.
- `created_at`: report Unix seconds.

Mailbox message fields:

- `id`: server-generated durable mail ID.
- `sender_id`: authenticated sender.
- `recipient_id`: mailbox owner.
- `subject`: trimmed subject line.
- `body`: trimmed message body.
- `created_at`: Unix seconds.
- `read_at`: Unix seconds when read, omitted/zero when unread.

Persistence policy:

- `/private-messages/*` and `/mailbox/*` are durable sender/recipient scoped surfaces.
- Private message sends are rate-limited per sender; private reports require sender/recipient participation.
- Private conversation summaries and read markers belong to the private-message surface; they must not be derived from ephemeral room chat.
- `/chat/*` remains room-scoped and ephemeral for MVP live chat.
- `/utility/mail` remains the static utility panel feed and must not be used as player mailbox storage.

## `configs/housing_items.json`

Item fields:

- `id`: unique item ID.
- `name_key`: localized item name.
- `description_key`: localized item description.
- `item_type`: broad object type.
- `category`: catalog grouping.
- `icon_path`: Godot resource path for UI icon.
- `size`: grid footprint with `width` and `height`.
- `placement`: valid placement surface.
- `rotatable`: whether rotation is allowed.
- `price`: coin cost.
- `tags`: optional behavior or filtering tags.
- `opens_minigame_id`: optional minigame ID launched by interaction.

Offline MVP save data:

- `house_items`: placed furniture/decor/activity objects.
- `house_styles`: current wall and floor style item IDs.
- `active_home_owner_id`: owner currently loaded by the housing scene.
- `active_home_visit_mode`: whether the housing scene is read-only visitor mode.
- `coin_ledger`: append-only local coin event chain for offline audit.
- `house_sync_required`: whether local housing changes need server reconciliation.

Every placement and style change spends coins through `HousingService`.

Online MVP rule: housing prices, grid size, item footprint, surface/furniture type, and rotation legality are server authoritative. The Go backend loads the same `configs/housing_items.json` contract through `PSW_HOUSING_CONFIG_PATH` / `housing.items_config_path`; online placement/style requests do not send a trusted price or trusted geometry.

Online visit rule: MVP homes are public to authenticated players through `home:<owner_id>`, but only the owner can place items or apply styles.

Online failure rule: housing does not perform fine-grained local rollback. It reconciles from the server layout when possible; otherwise it keeps the local layout and marks `house_sync_required`.

## `configs/economy.json`

Economy fields:

- `currency`: primary soft currency ID.
- `starting_balance`: offline starter wallet amount.
- `daily_soft_cap`: current soft cap target for repeatable rewards.
- `sources`: reward source records.
- `sinks`: spend sink records.
- `housing.sell_refund_rate`: furniture sell-back refund rate from 0 to 1.

MVP rule: offline Godot housing and online Go housing must use the same sell refund rate. The backend receives the mirrored value through `housing.sell_refund_rate` / `PSW_HOUSING_SELL_REFUND_RATE` while the client reads `configs/economy.json`.

## `configs/fishing.json`

Fishing fields:

- `daily_full_reward_count`: MVP per-session rewarded catch cap for online sessions.
- `bite_timing`: client pacing values for cast, bite wait, and reel reveal.
- `rarities`: ordered rarity records with `id`, localized `name_key`, and hex `color`.
- `fish`: weighted reward table with `id`, `name_key`, `rarity`, `weight`, `sell_value`, and Image 2 `icon_path`.

Online rule: the Go backend is authoritative for fish selection, reward coin value, catch caps, and idempotency. It reads `fish[].rarity` from the shared config and returns that rarity in `/minigames/fishing/catch` responses so the Godot reward panel can show the same callout online and offline.

## `configs/utility_panels.json`

This registry backs the first usable main-city utility panels. It is intentionally config-first so the backend can later replace the local rows without changing the panel layout.

Shop offer fields:

- `id`: stable offer ID.
- `item_id`: housing item ID shown as shop stock.
- `action_id`: utility action routed by the HUD, such as `home`.
- `action_key`: short localized action label.

Mail message fields:

- `id`: stable message ID.
- `sender_key`: localized sender name.
- `subject_key`: localized subject.
- `body_key`: localized body copy.
- `icon_id`: Image 2 UI icon ID from `configs/ui_assets.json`.
- `action_id`: optional HUD action.
- `action_key`: optional short localized action label.

Notice fields mirror mail messages but do not require `sender_key`.

MVP rule: shop rows preview coin costs and route players to Home; the actual coin spend still happens through `HousingService` when a room item/style is placed.

Online replacement rule: authenticated clients should prefer `GET /utility/panels?player_id=...` and use this local config as the offline fallback. The backend response keeps the same `shop`, `mail`, and `notice` shape so UI layout and localization keys do not fork.

Live-ops V1 rule: `PUT /admin/utility/panels` can replace the backend's panel registry with the same shape after admin auth. Memory mode keeps the update in process memory. PostgreSQL mode stores the current registry in `utility_panel_records`, seeded from `PSW_UTILITY_PANELS_CONFIG_PATH` only when no active record exists yet.

## `configs/emotes.json`

Emote fields:

- `id`: semantic emote ID.
- `name_key`: localized tooltip/name key.
- `shortcut`: optional keyboard shortcut label.

Visual files are mapped in `configs/ui_assets.json`. `emote.laugh` and `emote.exclamation` are locked by content validation.

## `configs/minigames.json`

Minigame fields:

- `id`: unique minigame ID.
- `mode_id`: creator mode contract ID from `configs/creator_game_modes.json`.
- `name_key`: localized game name.
- `description_key`: localized game description.
- `route_id`: route ID from `scene_routes`.
- `enabled`: whether it appears in MVP UI.
- `min_players`: minimum session size.
- `max_players`: maximum session size.
- `session_seconds`: nominal match duration.
- `matchmaking`: queue settings.
- `rewards`: coin payout values.

## `configs/creator_game_modes.json`

This registry defines the mode contracts that player-made games can target. Every official and creator minigame must declare exactly one `mode_id`.

Mode fields:

- `id`: stable mode ID such as `side_scroller_2d`, `2d_fighting`, `strategy_war`, `rpg_adventure`, `tower_defense`, or `battle_royale`.
- `name_key` / `summary_key`: localized creator-facing copy.
- `icon_id`: Image 2 UI icon from `configs/ui_assets.json`.
- `camera_key`, `input_key`, `network_key`: localized contract labels shown in the Creator Lab panel.
- `session_model`: broad runtime model used by backend/session planning.
- `min_players` / `max_players`: platform cap for this mode.
- `allowed_capabilities`: high-level features creators may use inside the sandbox.
- `review_focus`: review and AI-audit checks that matter most for the mode.

Manifest rule: `meta.json` must include `mode_id` and a `runtime_contract` object. Player caps in `meta.json` must not exceed the selected mode cap.

## Localization

Day 1 locales:

- `localization/en.json`
- `localization/ja.json`
- `localization/zh-Hans.json`

Each locale file must expose the same key set. Keys should be stable even if text changes.
