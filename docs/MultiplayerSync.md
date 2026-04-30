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
- Emits `world.leave` when players disconnect or switch rooms.
- Exposes realtime counters through `/city/state`.
- Broadcasts `player.move` only to clients in that room.
- Converts `emote.send` into `emote.event` and fans it out to the sender's room.
- Keeps `/city/state` room counts for operational smoke checks.

Godot `RoomLifecycle` switches between `world_town_square`, `home:{owner_id}`, and `minigame:{game_id}:{session_id}`. `MainCityScreen` applies `player.move` and `world.snapshot` payloads to remote `PlayerAvatar` instances with interpolation. `RealtimeClient` retries dropped connections with capped backoff.

## Next Realtime Slice

1. Persist room snapshots across process restarts where useful.
2. Move private-room member/history reads behind a cleaner token-derived identity helper.
3. Add fanout latency histograms and dropped packet counters.
4. Add admin/debug UI for room metrics.
5. Add mobile foreground/background network lifecycle handling.
