# Fishing

Official MVP minigame and reference implementation for the `IMinigame` interface.

This game intentionally keeps the rules small:

- Load fish and reward values from `configs/fishing.json`.
- Use `bite_timing` for a short cast, bite, and reel-in pacing loop.
- Show localized rarity callouts from `configs/fishing.json` for every catch.
- Grant local offline coins through `SaveSystem` until the Go economy service is connected.
- Emit `ended` with score, rewards, and stats for the sandbox host.
