# Character Animation v0

## Reference Notes

The motion model follows classic 2D MMO readability rather than copying any shipped Ragnarok Online asset.

Useful public references:

- [Ragnarok Research Lab ACT format](https://ragnarokresearchlab.github.io/file-formats/act/): animation clips, frame timings, sprite layers, anchors, and events.
- [Hercules Acts guide](https://wiki.herc.ws/wiki/Acts): action files sequence sprite frames by facing direction and client view direction.
- [Ragnarok Research Lab animation systems](https://ragnarokresearchlab.github.io/rendering/animation-systems/): ACT frame timing is data-driven rather than hardcoded into one texture.

## MVP Scope

Current player animation states:

- `idle`: four directions.
- `walk`: four directions, three frames per direction.
- `attack`: four directions, three frames per direction.
- `sit`: four directions.

Controls:

- Arrow keys: move and face direction.
- `Z` or confirm/space: attack.
- `X`: toggle sitting.
- Moving while sitting stands the avatar up.

## Asset Contract

Generated Image 2 source:

- `assets/sprites/generated/player_adventurer_actions_v0_source.png`

Processed alpha sheet:

- `assets/sprites/generated/player_adventurer_actions_v0_alpha.png`

Sliced frames:

- `assets/sprites/sliced/player_adventurer_actions_v0/`

Runtime config:

- `configs/player_animations.json`

The sprite sheet is original and must not be replaced by extracted or copied Ragnarok Online assets.

## Next Animation Risks

- Expand to eight directions after multiplayer movement sync is stable.
- Split body, head, weapon, and cosmetic anchors only when avatar customization needs it.
- Add hit reaction, cast, and death/downed states when combat rules exist.
- Standardize avatar frame canvas and foot anchor before remote player interpolation.
