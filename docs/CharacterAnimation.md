# Character Animation v1

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
- Six formal Image 2 avatar variants: male/female crossed with melee, ranged, and magic.

Controls:

- Arrow keys: move and face direction.
- `Z` or confirm/space: attack.
- `X`: toggle sitting.
- Moving while sitting stands the avatar up.

## Asset Contract

Formal generated Image 2 source:

- `assets/sprites/generated/player_male_melee_actions_v1_source.png`
- `assets/sprites/generated/player_male_ranged_actions_v1_source.png`
- `assets/sprites/generated/player_male_magic_actions_v1_source.png`
- `assets/sprites/generated/player_female_melee_actions_v1_source.png`
- `assets/sprites/generated/player_female_ranged_actions_v1_source.png`
- `assets/sprites/generated/player_female_magic_actions_v1_source.png`

Processed alpha sheets:

- `assets/sprites/generated/player_*_actions_v1_alpha.png`

Sliced frames:

- `assets/sprites/sliced/player_*_actions_v1/`

Runtime config:

- `configs/player_animations.json`

The sprite sheets are original Image 2 assets and must not be replaced by extracted or copied Ragnarok Online assets.

## NPC Profession Visuals v1

Main-city NPCs now use a dedicated Image 2 profession sheet before falling back to player avatars or legacy NPC slices.

Formal generated Image 2 source:

- `assets/sprites/generated/npc_professions_v1_source.png`

Processed alpha sheet:

- `assets/sprites/generated/npc_professions_v1_alpha.png`

Sliced idle frames:

- `assets/sprites/sliced/npc_professions_v1/`

Runtime config:

- `configs/npc_professions.json`
- `configs/main_city_npcs.json` via `npc_visual_id`

V1 intentionally ships one front-facing idle frame per high-frequency NPC profession. Full direction and action strips should be generated as one strip per approved profession seed frame when NPC patrols or service animations become gameplay-critical.

## Next Animation Risks

- Expand to eight directions after multiplayer movement sync is stable.
- Split body, head, weapon, and cosmetic anchors only when avatar customization needs it.
- Add hit reaction, cast, and death/downed states when combat rules exist.
- Standardize avatar frame canvas and foot anchor before remote player interpolation.
