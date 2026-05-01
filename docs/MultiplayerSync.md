# Multiplayer Sync v4

## Goal

Make the town square visibly multiplayer before optimizing for strict realtime combat.

The current slice uses presence for membership and avatar spawning, then authenticated WebSocket fanout for room-scoped movement and overhead emotes.

## Presence To Avatar

`PresenceService` receives room members and `MainCityScreen` mirrors non-local members into `PlayerRoot/RemotePlayers`.

Remote avatars:

- Reuse `PlayerAvatar`.
- Disable local input with `input_enabled = false`.
- Use the same Image 2 animation sheet as the local player.
- Spawn around the plaza from a deterministic player-id hash.
- Are removed when absent from the latest presence list.

## `player.move` Payload

Client snapshots should use:

```json
{
  "player_id": "player_123",
  "room_id": "world_town_square",
  "position": {"x": 0, "y": 0},
  "velocity": {"x": 0, "y": 0},
  "facing": "down",
  "is_sitting": false,
  "is_attacking": false,
  "sent_at": 1777400000
}
```

`WorldStateSync.build_player_move_payload()` produces this shape from `PlayerAvatar.get_avatar_state()`.

## WebSocket Realtime v1

`RealtimeClient` connects to `/ws/city`, sends `world.join` with the guest access token, and periodically sends `player.move` snapshots for the local avatar.

The backend hub:

- Stores each socket's current room from `world.join`.
- Rejects invalid join tokens with `auth.failed`.
- Overrides client-sent `player_id` and `room_id` on movement and emote payloads.
- Rate-limits `player.move` and `emote.send` per socket, or through Redis in `realtime.mode=redis`.
- Clips movement positions to room bounds.
- Stores the latest room movement states for `world.snapshot` recovery.
- Publishes room fanout through Redis pub/sub in `realtime.mode=redis`.
- Shares auth validation, movement/emote rate limiting, and room pub/sub across gateway instances in Redis mode.
- Emits `world.leave` when players disconnect or switch rooms.
- Exposes realtime counters through `/city/state`.
- Broadcasts `player.move` only to clients in that room.
- Converts `emote.send` into `emote.event` and fans it out to the sender's room.
- Keeps `/city/state` room counts for operational smoke checks.
- Applies room caps at `world.join`: main city, housing, minigame, and custom rooms each have separate config/env knobs.
- Counts slow writes and closes failed writes as the first backpressure policy.
- Raises the effective `player.move` interval to 120ms when a local room reaches 50 joined players, reducing dense-room broadcast pressure before full interest management lands.
- Filters dense-room `player.move` targets by a 360-unit interest radius while keeping chat, joins, emotes, and snapshots room-wide.
- Has gateway smoke coverage for two Redis-backed server instances exchanging cross-instance `player.move` and `chat.message`.

Godot `RoomLifecycle` switches between `world_town_square`, `home:{owner_id}`, and `minigame:{game_id}:{session_id}`. `MainCityScreen` applies `player.move` and `world.snapshot` payloads to remote `PlayerAvatar` instances with interpolation. `RealtimeClient` retries dropped connections with capped backoff.

## Next Realtime Slice

1. Add a Redis-mode multi-client load profile beyond the current two-gateway smoke.
2. Persist room snapshots across process restarts where useful.
3. Move private-room member/history reads behind a cleaner token-derived identity helper.
4. Tune interest radius with real playtest data and add admin alerts for high cull/write-failure rates.
5. Add mobile foreground/background network lifecycle handling.
