# Alpha RC Local Test Plan

Use this when the codebase is ready for a human playtest pass, but before the
Ubuntu production deploy or store-signing work.

## Start Local Alpha

From the repo root:

```bash
scripts/run_local_alpha.sh
```

The script builds the local backend, runs local preflight, serves the current
Godot Web export, writes a local runtime config, and prints URLs.

Default endpoints:

- Player H5: `http://127.0.0.1:18888/index.html`
- Messages panel: `http://127.0.0.1:18888/index.html?psw_panel=messages`
- Creator panel: `http://127.0.0.1:18888/index.html?psw_panel=creator`
- LiveOps: `http://127.0.0.1:18888/index.html?psw_route=liveops_console`
- Backend health: `http://127.0.0.1:8787/healthz`
- Backend ready: `http://127.0.0.1:8787/readyz`
- Local admin token: `local-admin-token`

The backend URLs are API probes, not player-facing pages. For operations tools,
open the LiveOps URL, paste `local-admin-token` into the top Admin token field,
then press Refresh.

If the Web export is stale or missing:

```bash
PSW_LOCAL_ALPHA_EXPORT_WEB=1 scripts/run_local_alpha.sh
```

For a non-interactive readiness check:

```bash
PSW_LOCAL_ALPHA_EXIT_AFTER_READY=1 scripts/run_local_alpha.sh
```

Press `Ctrl+C` in the script terminal to stop local alpha. The script clears the
local web/API ports on exit.

## Player Smoke

1. Open the Player H5 URL.
2. Guest login.
3. Move around the main city and click the avatar once; names should be hidden
   by default and visible only after click.
4. Send a global chat message.
5. Open the room panel, host Fishing, enter the sandbox, cast once, and verify
   coins/reward feedback.
6. Open Home, place one starter item, move or rotate it, then leave home.
7. Open Messages, send a private message to a known player ID, and verify the
   panel remains readable on desktop width.
8. Open Creator and confirm mode contracts are visible for casual, side
   scroller, 2D fighting, strategy, RPG, tower defense, and battle royale.

## Two-Client Smoke

1. Open two browser windows to the Player H5 URL.
2. Login both as guests.
3. Join the same room; the member count should update.
4. Send chat from one window; the other should receive it.
5. Enter the owner home in one window and the visitor home in the other through
   invite/visit flow.
6. Place or move a housing item as owner. The visitor should receive the
   layout update without refreshing.
7. Trigger an overhead emote and verify it appears above the avatar.

## LiveOps Smoke

1. Open the LiveOps URL.
2. Enter `local-admin-token`.
3. Refresh all panels.
4. Confirm Debug Ops shows rooms, realtime, chat, moderation, fishing, economy,
   and room drilldown rows.
5. Export or scroll audit panels and verify narrow layout does not clip the
   critical action buttons.

## Mobile Browser Checks

Use browser responsive mode or a phone on the same machine/network:

- Landscape `844x390`: login, chat input, private input, room panel, home edit,
  and fishing host flow.
- Portrait `390x844`: the landscape-required guard should appear.
- Check the mobile software keyboard does not cover the active chat/private
  input after focus.

## External Items Not Covered By Local Alpha

- Apple/Google real OAuth provider configuration.
- iOS/Android signing and store review metadata.
- Real-device FPS, memory, and thermal checks.
- Ubuntu 26.04 PostgreSQL/Redis production dry-run.
- Cloudflare Tunnel public domain smoke.
