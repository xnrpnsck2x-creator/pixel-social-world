# Overhead Emote System

## Direction

The emote behavior follows the user's reference and classic social MMO readability: a short-lived bubble pops above the avatar's head, rises slightly, holds, then fades.

The implementation borrows the interaction pattern only. All production emote art must remain original Image 2 generated assets registered in `configs/ui_assets.json`.

## Runtime Flow

```text
WorldHUD
  builds a 30-button palette from configs/emotes.json
  emits emote_requested(emote_id)

MainCityScreen / WorldScreen
  receives the signal
  calls PlayerAvatar.show_emote(emote_id)

PlayerAvatar
  forwards to child OverheadEmoteBubble

OverheadEmoteBubble
  loads Image 2 PNG through EmoteCatalog
  plays pop, rise, hold, fade animation
```

## Shared Classes

- `scripts/Systems/Emotes/EmoteCatalog.gd`
- `scripts/UI/Emotes/OverheadEmoteBubble.gd`
- `scripts/Entities/Player/PlayerAvatar.gd`
- `configs/emotes.json`

## HUD Palette

The HUD emote button opens a compact 6x5 icon palette. Palette order, localized tooltip keys, and optional shortcuts live in `configs/emotes.json`.

The first shortcut slice follows the familiar social MMO pattern:

- `Alt+1` -> `emote.exclamation`
- `Alt+2` -> `emote.question`
- `Alt+3` -> `emote.music`
- `Alt+4` -> `emote.heart`
- `Alt+5` -> `emote.sweat`
- `Alt+6` -> `emote.idea`
- `Alt+7` -> `emote.angry`
- `Alt+8` -> `emote.gloom`
- `Alt+9` -> `emote.coin`
- `Alt+0` -> `emote.silence`

## Starter Emotes

The current Image 2 overhead set supports:

- `emote.exclamation`
- `emote.question`
- `emote.music`
- `emote.heart`
- `emote.big_heart`
- `emote.sweat`
- `emote.idea`
- `emote.angry`
- `emote.gloom`
- `emote.coin`
- `emote.thanks`
- `emote.silence`
- `emote.nervous_sweat`
- `emote.sad`
- `emote.sorry`
- `emote.laugh`
- `emote.confused`
- `emote.thumbs_up`
- `emote.search`
- `emote.surprise`
- `emote.no`
- `emote.help`
- `emote.yes`
- `emote.go`
- `emote.cry`
- `emote.sly`
- `emote.kiss`
- `emote.pat`
- `emote.puff`
- `emote.nod`

## Minigame Integration

`IMinigame` exposes:

```gdscript
signal emote_requested(player_id: String, emote_id: String)

func request_emote(player_id: String, emote_id: String) -> void:
    emote_requested.emit(player_id, emote_id)
```

Creator minigames should call `request_emote(player_id, "emote.happy")` instead of implementing their own unrelated emote protocol.

Games with in-game avatars may also instance `OverheadEmoteBubble` above their local avatar nodes and call `play(emote_id)` directly.
