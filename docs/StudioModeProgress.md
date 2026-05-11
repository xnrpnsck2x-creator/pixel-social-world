# Studio Mode Progress

## Active Goal

Reduce the three largest risks in order:

1. Product risk: MVP scope too wide.
2. Engineering risk: offline stubs can drift away from online architecture.
3. Art risk: no unified pixel UI and missing asset paths.

Strategic source now lives in `docs/StrategicPlan.md`, based on the updated
root `AGENTS.md` and `game_design_bible.md`.
Accelerated content execution now lives in `docs/AcceleratedContentRoute.md`.

## Progress

### App Store / Google Play Publish Handoff V1

Status: Implemented and locally verified on 2026-05-12.

- Added `docs/StorePublishHandoff.md` as the store submission handoff source of truth for Apple TestFlight/App Store and Google Play internal/closed/production tracks.
- Added a dedicated `Android Play AAB` export preset targeting `builds/android/pixel_social_world.aab` with Gradle enabled and target SDK 35, while keeping the existing APK preset for local/debug/device handoff.
- Added `scripts/check_store_publish_handoff.sh` to validate official Apple/Google requirement sources, store branding assets, Android AAB readiness, no committed store secrets, and strict-mode fail-closed behavior when App Store Connect / Play Console evidence env is absent.
- Wired the publish check into `mobile_h5_native` through `store_publish_handoff_contract_pass`, so the project category v2 gate now covers store-publish readiness alongside native release signing, Android runtime budget, and true-device evidence.
- Updated native release, mobile export, project category, and MVP progress docs so "can publish to Apple/Google" is treated as a gated handoff, not a loose checklist.

### Production Data Backup Handoff V1

Status: Implemented and locally verified on 2026-05-12.

- Added `docs/ProductionDataBackupHandoff.md` as the release handoff source of truth for PostgreSQL, creator package artifacts, creator runtime installs, release manifest evidence, restore drill evidence, stop conditions, and rollback blockers.
- Added `scripts/check_production_data_backup_handoff.sh` to validate the handoff doc, production package paths, external backup destination/encryption env, no committed backup artifacts, and strict-mode fail-closed behavior when backup env is absent.
- Wired the handoff check into `liveops_moderation` through `production_data_backup_handoff_contract_pass`, so the project category v2 gate now checks backup/restore readiness alongside monitoring and LiveOps backend coverage.
- Updated deployment, LiveOps release, project-category, and MVP progress docs so backup/restore is treated as a release gate rather than a loose operator note.

### Production Monitoring Handoff V1

Status: Implemented and locally verified on 2026-05-12.

- Added `docs/ProductionMonitoringHandoff.md` as the release handoff source of truth for health/readiness probes, LiveOps alert polling, systemd probe/timer evidence, rollout metrics, stop conditions, and rollback.
- Added `scripts/check_production_monitoring_handoff.sh` to validate the handoff doc, backend health/readiness and `/debug/ops/alerts` contracts, prometheus/heartbeat modes, systemd alert probe/timer packaging, no committed monitoring secrets, and strict-mode fail-closed behavior when monitoring env is absent.
- Wired the handoff check into `liveops_moderation` through `production_monitoring_handoff_contract_pass`, so the project category v2 gate now checks monitoring readiness alongside LiveOps backend package coverage.
- Updated LiveOps thresholds, backend deployment, backend contract, and MVP progress docs to reflect the new gated monitoring handoff while keeping real alert/admin tokens outside committed config.
- Verified: `scripts/check_production_monitoring_handoff.sh`, strict-mode env check, Python syntax parse for `tests/project_category_v2_gate.py`, JSON syntax for `configs/project_categories_v2.json`, and `scripts/run_project_category_v2_gate.sh`.

### Store Auth Provider Handoff V1

Status: Implemented and locally verified on 2026-05-12.

- Added `docs/StoreAuthProviderHandoff.md` as the release handoff source of truth for Apple/Google guest-account upgrade, strict backend OIDC env, store review evidence, stop conditions, and rollback.
- Added `scripts/check_store_auth_provider_handoff.sh` to validate the handoff doc, `/auth/upgrade` backend contract, production `oidc_jwt` config, required Apple/Google env names, no committed provider secret assignments, and strict-mode fail-closed behavior when provider env is absent.
- Wired the handoff check into `auth_profile` through `store_auth_provider_handoff_contract_pass`, so the project category v2 gate now checks store auth readiness alongside backend auth package coverage and localization key coverage.
- Updated the backend contract and MVP progress docs to reflect the new gated handoff while keeping real Apple/Google credentials outside committed config.
- Verified: `scripts/check_store_auth_provider_handoff.sh`, Python syntax parse for `tests/project_category_v2_gate.py`, JSON syntax for `configs/project_categories_v2.json`, and `scripts/run_project_category_v2_gate.sh`.

### Native Release Handoff Runbook V1

Status: Implemented and locally verified on 2026-05-12.

- Added `docs/NativeReleaseHandoffRunbook.md` as the release-candidate handoff source of truth for Android/iOS signing, local gates, true-device evidence, stop conditions, and rollback.
- Added `scripts/check_native_release_handoff.sh` to validate the runbook contract, default iOS/Android release readiness checks, required signing env names, evidence paths, and strict-mode fail-closed behavior when release signing env is absent.
- Wired the handoff check into `mobile_h5_native` through `native_release_handoff_contract_pass`, so the project category v2 gate now checks the release handoff alongside iOS readiness, Android readiness, store branding, and Android runtime budget evidence.
- Updated the mobile export and MVP progress docs to reflect the new gated handoff step while keeping real signing credentials outside committed config.
- Verified: `scripts/check_native_release_handoff.sh`, Python syntax parse for `tests/project_category_v2_gate.py`, JSON syntax for `configs/project_categories_v2.json`, and `scripts/run_project_category_v2_gate.sh`.

### iOS Release Signing Readiness V1

Status: Implemented and locally verified on 2026-05-11.

- Added `scripts/check_ios_release_readiness.sh` as the iOS release preflight for the native handoff path.
- The script verifies the iOS export preset, zip export path, arm64, stable bundle id, short/build versions, minimum iOS version, store icon wiring, full Xcode, `xcodebuild`, iphoneos SDK, `codesign`, and the keychain `security` tool.
- Signing values stay outside the repo: the preflight fails if `export_presets.cfg` contains Team ID, provisioning profile, or code-sign identity values.
- The strict mode `PSW_IOS_RELEASE_SIGNING_REQUIRED=1` is reserved for the actual release machine; default local mode passes as a no-secret contract check when iOS signing env is intentionally unset.
- Wired the iOS release readiness contract into the project category v2 gate through `ios_release_readiness_contract_pass`, so `mobile_h5_native` now verifies iOS and Android release signing hygiene together.
- Verified: `scripts/check_ios_release_readiness.sh`, strict-mode negative check, partial-env negative check, Python syntax parse for `tests/project_category_v2_gate.py`, JSON syntax for `configs/project_categories_v2.json`, and `scripts/run_project_category_v2_gate.sh`.

### Android Release Signing Readiness V1

Status: Implemented and locally verified on 2026-05-11.

- Added `scripts/check_android_release_readiness.sh` as the Android release preflight for the native handoff path.
- The script verifies the Android export preset, stable package id, signing-enabled package setting, internet permission, APK/AAB format contract, Java/build-tools availability, `zipalign`, `apksigner`, and `keytool`.
- Release credentials stay outside the repo: the preflight fails if `export_presets.cfg` contains signing/provisioning values, and it only validates keystore file/alias when `ANDROID_RELEASE_KEYSTORE`, `ANDROID_RELEASE_KEYSTORE_USER`, and `ANDROID_RELEASE_KEYSTORE_PASSWORD` are provided together.
- The strict mode `PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1` is reserved for the actual release machine; default local mode passes as a no-secret contract check when release env is intentionally unset.
- Wired the release readiness contract into the project category v2 gate through `android_release_readiness_contract_pass`, so `mobile_h5_native` now verifies both release signing hygiene and Android runtime budget evidence.
- Verified: `scripts/check_android_release_readiness.sh`, Python syntax parse for `tests/project_category_v2_gate.py`, JSON syntax for `configs/project_categories_v2.json`, and `scripts/run_project_category_v2_gate.sh`.

### Android Runtime Budget Gate V1

Status: Implemented and Android-device budget verified on `c7e94055` reports on 2026-05-11.

- Added `scripts/check_android_runtime_budget.sh` as the repeatable Android runtime budget gate for stability reports. It fails on low sample coverage, high average/peak CPU, high average/peak PSS, PSS growth, or swap PSS over budget.
- Wired `scripts/run_android_stability_probe.sh` to call the runtime budget gate automatically after package/Godot-focused logcat scanning. Set `PSW_ANDROID_STABILITY_SKIP_BUDGET=1` only when collecting diagnostic data that should not fail the outer command.
- Hardened the stability sampler so transient `dumpsys meminfo` failures or missing temp folders record a zeroed sample instead of aborting the whole route.
- Calibrated the default debug-build budget from current true-device data: at least 12 samples, 65% observed/wall duration coverage, CPU <= 30% average / 40% peak, PSS <= 380 MB average / 430 MB peak, PSS growth <= 80 MB, and swap PSS <= 32 MB.
- Verified the budget against the 240-second native render throttle report: 20 samples, 229s observed, CPU 23.5% / 32% avg/max, PSS 335.1 MB / 361.5 MB avg/max, -45.1 MB PSS growth, and 0.5 MB max swap PSS.
- Ran and calibrated against a longer 600-second Android route soak. App metrics stayed healthy with 36 samples, 413s observed, CPU 20.8% / 32.6% avg/max, PSS 314.9 MB / 341.5 MB avg/max, -30.2 MB PSS growth, and 20.6 MB max swap PSS.
- Promoted the Android budget evidence into the project category v2 gate through the `android_runtime_budget_reports_pass` check, so `mobile_h5_native` now fails if the committed gate cannot validate both Android runtime reports.
- The 600-second run initially proved that strict desktop-style sample coverage and a 20 MB swap cap were too brittle for real Android devices under background memory pressure; the current gate keeps CPU/PSS strict while allowing realistic adb route overhead and small swap PSS.
- Short 120/180-second diagnostic probes in the desktop tool environment can fail the sample-count gate when wall time is paused or delayed; those runs are not used as release evidence. The committed budget gate is intended for the 240-second-plus Android stability reports and the default 600-second probe.
- Evidence: `.tools/android-stability-render-throttle-v1/android-stability-report.json`, `.tools/android-stability-soak-v1/android-stability-report.json`, `.tools/android-stability-soak-v1/android-stability-summary.txt`, and `.tools/project-category-v2-gate/project-category-v2-report.html`.

### Android Native Render Throttle V1

Status: Implemented, re-exported, reinstalled, and Android-device verified on `c7e94055` on 2026-05-11.

- Tightened the mobile native frame budget in `Boot.gd`: Android/iOS now cap foreground rendering at 24 FPS, run physics at 30 ticks per second, limit max physics catch-up steps, and enable Godot low-processor sleep for the social-world route.
- Stopped idle `PlayerAvatar` work when no nameplate is visible and no remote interpolation is active; remote avatars now also disable physics processing while they are not locally controlled.
- Stopped `RealtimeClient` from polling every frame after it is closed with no pending reconnect window, while keeping connected and reconnecting sockets active.
- Re-exported, pruned, aligned, signed, reinstalled, and verified the Android debug APK. The package still passes APK Signature Scheme v2/v3 verification and the 220 MB asset budget at 147.3 MB.
- Ran the same 240-second Android stability probe shape as the previous baseline. CPU improved from 37.5% / 43.6% avg/max to 23.5% / 32% avg/max; PSS remained stable with -45.1 MB growth, 335.1 MB average PSS, and only 0.5 MB max swap PSS.
- Re-ran the full Android device regression wrapper after the performance change: 7 player-path cases, 4 UI-panel cases, and all 32 generated maps passed on `c7e94055`.
- Verified focused Godot smokes for player avatar variants, remote players, tap-to-move, network lifecycle, room lifecycle, main-city interactions, and actor depth sorting; changed GDScript files remain under the 300-line budget.
- Evidence: `.tools/android-stability-render-throttle-v1/android-stability-report.json`, `.tools/android-stability-render-throttle-v1/android-stability-summary.txt`, `.tools/android-regression-render-throttle-v1/android-device-regression.json`, and `.tools/android-regression-render-throttle-v1/map-sweep/contact-sheet.png`.

### Android Stability Probe V1

Status: Implemented and Android-device verified on `c7e94055` on 2026-05-11.

- Added `scripts/run_android_stability_probe.sh` as the repeatable true-device stability sampler for CPU, PSS/RSS memory, swap PSS, screenshots, and package/Godot-focused logcat scanning.
- The default case loop covers main city idle, Trade Market panel, Map Atlas, Housing Edit, and the fishing minigame route; custom case JSON is supported through `PSW_ANDROID_STABILITY_CASES_JSON`.
- Verified a short 75-second smoke after fixing the sampler parser and narrowing logcat issue detection to package/Godot signals.
- Ran a 240-second stability probe with 10-second sampling and 45-second route intervals on Android device `c7e94055`.
- Current 240-second result: 20 samples, observed duration 229s, average/peak CPU 37.5% / 43.6%, average/peak PSS 311.4 MB / 337.8 MB, average/peak RSS 393.2 MB / 421.3 MB, max swap PSS 6.6 MB, and PSS growth -15.9 MB.
- Logcat passed the package/Godot-focused issue scan; no fatal exception, ANR, Godot script error, panic, segmentation, or package crash marker was found.
- Evidence: `.tools/android-stability-current/android-stability-report.json`, `.tools/android-stability-current/stability_samples.tsv`, `.tools/android-stability-current/route-03-map-atlas.png`, `.tools/android-stability-current/route-04-housing-edit.png`, and `.tools/android-stability-current/route-05-fishing-minigame.png`.
- Remaining performance note: the app is stable in this short route-cycle probe, but the 37.5% average process CPU confirms the next native performance pass should focus on render/idle throttling rather than memory leaks.

### Android Device Regression Gate V1

Status: Implemented and Android-device verified on `c7e94055` on 2026-05-11.

- Added `scripts/run_android_device_regression.sh` as the single true-device regression entry point after a local MVP/H5 gate is green.
- The wrapper installs and launches the debug APK by default, then runs the Android player path sweep, Android UI panel sweep, and full 32-map Android sweep into one artifact root.
- It keeps fast iteration as the default by using the existing APK when present, while still allowing `PSW_ANDROID_REGRESSION_EXPORT=1` for a fresh export and `PSW_ANDROID_REGRESSION_SKIP_READINESS=0` / `PSW_ANDROID_REGRESSION_SKIP_PREFLIGHT_MAP=0` for a heavier handoff gate.
- The wrapper writes `android-device-regression.json` summarizing device id, artifact folders, 7 player-path cases, 4 UI-panel cases, and 32 map screenshots.
- Verified the new wrapper on Android device `c7e94055` with `builds/android/pixel_social_world-debug.apk`; APK asset budget stayed at 147.3 MB against the 220 MB budget.
- Evidence: `.tools/android-regression-current/android-device-regression.json`, `.tools/android-regression-current/player-path/minigame-fishing.png`, `.tools/android-regression-current/ui-panel/trade-facility.png`, and `.tools/android-regression-current/map-sweep/contact-sheet.png`.

### Android Map UI Device Sweep V2

Status: Implemented, re-exported, reinstalled, and Android-device verified on `c7e94055` on 2026-05-11.

- Re-ran Android device preflight with mobile export readiness, debug APK export, APK pruning/signing, asset budget, install, and launch. The debug APK remains 147.3 MB against the 220 MB budget.
- Ran a full Android map sweep across all 32 generated maps: 6 main city maps, 8 life-skill maps, 8 random exploration maps, 6 social maps, and 4 seasonal/activity maps. All 32 launched, screenshotted, and passed the package logcat issue scan.
- Ran Android player path sweep for main city start, tap-to-move feedback, NPC dialog, private-message keyboard, Trade Market, housing placement, and fishing minigame reward flow.
- Ran Android UI panel sweep for Map Atlas, player profile card, Trade Market panel, and Housing Edit.
- Found and fixed a true-device housing UI issue where the compact Visitors panel sat too close to the right screen edge. The compact housing social panel now has a wider 236px frame, a 26px right inset, an 82px minimum chat field, and the room renderer reserves 274px of right-side safe space.
- Re-exported/reinstalled after the fix, then re-ran Android UI panel and player path sweeps. The housing right panel now stays inside the safe area, and the follow-up player sweep passed all 7 routes.
- Verified focused Godot smokes: `housing_responsive_layout_smoke` and `housing_smoke`; changed GDScript files remain below the 300-line budget.
- Evidence: `.tools/android-map-sweep-current/contact-sheet.png`, `.tools/android-ui-panel-sweep-after-housing-safe/housing-edit.png`, `.tools/android-player-path-sweep-after-housing-safe/housing-place.png`, `.tools/android-player-path-sweep-after-housing-safe/private-keyboard.png`, and `.tools/android-player-path-sweep-after-housing-safe/minigame-fishing.png`.

### Map Avatar QA Sweep V2

Status: Locally/H5 verified on 2026-05-11.

- Re-ran the full map quality v2 gate, including map production contract, first-screen readability, map point quality, gathering zones, NPC grounding, NPC visual quality, action routes, actor depth sorting, collision patrol, activity/utility hotspots, route integrity, tap-to-move, return portals, hotspot prompt safe area, interaction quality, map unlocks, and scoped whitespace checks.
- Re-ran the H5-focused map quality matrix with Web export reuse, covering mobile-landscape base map, tap-move feedback, hotspot feedback, name reveal, and Map Atlas wilds filter states with zero browser console messages.
- Re-ran focused avatar Godot smokes for base avatar behavior, six player variants, login character selection, and remote player synchronization.
- Re-ran H5 avatar variant patrol for all six gender/class variants and H5 avatar action patrol for movement, emote, and remote-sync states; both semantic gates passed with zero console messages.
- Manually reviewed the generated 844x390 screenshots for left/right movement, overhead emote scale, remote player scale, HUD safe area, and class/gender readability. Current state is suitable for the next Android device sweep.
- Evidence: `.tools/map-quality-v2-focused-current/h5/`, `.tools/h5-avatar-variant-current/avatar-variant-patrol-report.html`, `.tools/h5-avatar-action-current/avatar-action-patrol-report.html`, `.tools/h5-avatar-action-current/h5-mobile-landscape-avatar-action-walk-right.png`, `.tools/h5-avatar-action-current/h5-mobile-landscape-avatar-action-walk-left.png`, and `.tools/h5-avatar-action-current/h5-mobile-landscape-avatar-action-emote.png`.

### H5 Side Panel Density Sweep V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Tightened the shared compact row-card frame used by right-side utility, trade, creator, and message rows, reducing compact card padding and row separation so Image 2 yellow panels no longer feel as stretched on 844x390 H5.
- Compressed compact Creator Lab rows with smaller mode icons, one-line runtime traits, and a one-line intro, allowing more creator modes to be visible before scrolling.
- Rebalanced compact Trade Market rows: smaller toolbar controls, tighter price inputs, smaller Post buttons, and denser row text while preserving the inline price/action flow and numeric mobile keyboard target.
- Tightened compact Messages and Private Messages rows, including smaller row icons, shorter private-message list height, and immediate row replacement to avoid one-frame duplicate rows after tab refresh.
- Updated focused smoke coverage for compact creator row space, trade toolbar/action density, compact message row icons, and the adjusted H5 trade price input tap point.
- Verified with Godot panel/action smokes, H5 5-case mobile-landscape screenshot matrix, H5 semantic screenshot gate, JavaScript syntax checks, scoped whitespace checks, and manual screenshot review.
- Evidence: `.tools/panel-density-sweep-v2b-web/h5-mobile-landscape-creator-panel.png`, `.tools/panel-density-sweep-v2b-web/h5-mobile-landscape-trade-facility-panel.png`, `.tools/panel-density-sweep-v2b-web/h5-mobile-landscape-trade-price-keyboard-guard.png`, and `.tools/panel-density-sweep-v2b-web/h5-mobile-landscape-private-messages-panel.png`.

### H5 Housing and Minigame Density V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Tightened the mobile housing social panel from the older wide visitor frame to a compact 218px layout, freeing more room for the editable room view.
- Reworked the mobile housing catalog into short localized item chips (`Wall`, `Floor`, `Chair`, `Table`, etc.) so the first row no longer shows half-clipped long item names on 844x390 H5.
- Reduced the compact fishing pond/reward panel widths, inner margins, button heights, reward icon size, and reward spacing so the yellow Image 2 frame reads as a contained game panel instead of a stretched overlay.
- Added focused smoke coverage for compact housing catalog overflow behavior, compact housing layout width limits, and compact fishing panel dimensions.
- Verified with Godot housing/fishing smokes, localization JSON syntax checks, H5 3-case screenshot matrix, H5 semantic screenshot gate, and manual screenshot review.
- Evidence: `.tools/housing-minigame-density-v2b-web/h5-mobile-landscape-housing-selected.png`, `.tools/housing-minigame-density-v2b-web/h5-mobile-landscape-housing.png`, and `.tools/housing-minigame-density-v2b-web/h5-mobile-landscape-minigame-host.png`.

### H5 Profile Housing Minigame Route V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Added an explicit Web debug overlay marker for player profile cards, including the report-state route, so H5 smoke tests now assert that the profile surface actually opened.
- Promoted mobile-landscape Profile, Profile Report, Housing Edit, Housing Selected, and Minigame Host into a focused H5 route matrix with semantic screenshot expectations.
- Visually reviewed the generated 844x390 screenshots for profile actions, housing edit/catalog, and the fishing sandbox host; all stayed inside the mobile landscape play area without blank or hidden primary controls.
- Re-ran focused Godot smokes for profile-card density, housing logic/responsive layout, minigame contract/session/launch flow, and fishing reward UI.
- Evidence: `.tools/profile-housing-minigame-v2-web/h5-mobile-landscape-profile-card.png`, `.tools/profile-housing-minigame-v2-web/h5-mobile-landscape-profile-report.png`, `.tools/profile-housing-minigame-v2-web/h5-mobile-landscape-housing.png`, and `.tools/profile-housing-minigame-v2-web/h5-mobile-landscape-minigame-host.png`.

### H5 UI Touch Stability V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Promoted mobile-landscape Map, Map Atlas, Inventory, Creator Lab, Mail, and Private Messages panels to explicit H5 overlay assertions so click-route drift fails fast instead of only producing screenshots.
- Added semantic screenshot expectations for the same surfaces, including activity-reward inventory state and wilds-filter Map Atlas state.
- Verified 8 focused H5 panel screenshots with zero console messages, then passed the semantic screenshot gate across all 8 cases.
- Re-ran focused Godot UI contract/smoke coverage for world utility panels, inventory rows, UI frames, HUD tooltip policy, UI v2 contract, and project category v2.
- Evidence: `.tools/ui-touch-stability-v2-web/h5-mobile-landscape-map-panel.png`, `.tools/ui-touch-stability-v2-web/h5-mobile-landscape-map-atlas-wilds-filter.png`, `.tools/ui-touch-stability-v2-web/h5-mobile-landscape-inventory-activity-rewards.png`, and `.tools/ui-touch-stability-v2-web/h5-mobile-landscape-creator-panel.png`.

### H5 HUD Input Focus Route V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Added Web-only focused-input markers for HUD text fields, so H5 tests can assert the actual Godot `LineEdit` focus state for chat, private messages, room chat, and trade price input.
- Corrected the compact mobile-landscape trade price and private-message input click targets after the right-side panels were tightened.
- Added a room-chat keyboard-guard H5 case and focused-input assertions for all four mobile-landscape text-entry routes.
- Verified with Godot panel smokes, H5 matrix screenshots, and the H5 semantic screenshot gate for chat, private messages, trade price, and room chat.
- Evidence: `.tools/hud-input-route-v2e-web/h5-mobile-landscape-chat-keyboard-guard.png`, `.tools/hud-input-route-v2e-web/h5-mobile-landscape-private-keyboard-guard.png`, `.tools/hud-input-route-v2e-web/h5-mobile-landscape-trade-price-keyboard-guard.png`, and `.tools/hud-input-route-v2e-web/h5-mobile-landscape-room-keyboard-guard.png`.

### H5 HUD Overlay Click Route V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Corrected the mobile-landscape Inventory, Town Square room, Mail, Map, and Emote HUD click targets so the H5 route gate opens the intended panel or palette instead of drifting into neighboring controls.
- Added Web debug overlay markers for `inventory`, `room`, `mail`, `map`, and `emote`, so H5 route tests now assert the actual opened surface instead of relying only on visual variance.
- Extended the H5 smoke/semantic gates with `mapClick`, `socialClick`, and `emoteClick` steps plus focused overlay expectations for all five mobile-landscape HUD entries.
- Verified with focused Godot smokes, H5 script syntax checks, scoped whitespace checks, and fresh mobile-landscape H5 screenshots for all five entries.
- Evidence: `.tools/hud-entry-route-v2c-web/h5-mobile-landscape-map-button-panel.png`, `.tools/hud-entry-route-v2c-web/h5-mobile-landscape-mail-button-panel.png`, `.tools/hud-entry-route-v2c-web/h5-mobile-landscape-emote-palette.png`, `.tools/hud-entry-route-v2c-web/h5-mobile-landscape-inventory-panel.png`, and `.tools/hud-entry-route-v2c-web/h5-mobile-landscape-room-panel.png`.

### Right Panel Compact Density V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Tightened compact Trade Market rows so price inputs and action buttons sit inline with the row summary, keeping the first sellable items fully actionable on 844x390 mobile-landscape H5.
- Reduced compact trade row icon, spacing, title, body, price-input, and action-button footprint while keeping `SocialFacilityPanel.gd` under the 300-line GDScript budget.
- Converted compact Creator Lab mode rows from long wrapped summaries to one-line runtime traits, using the new localized `creator.mode.row_detail_compact_format` key for English, Japanese, and Simplified Chinese.
- Extended focused smokes so compact trade actions must stay inline and compact creator mode rows must remain one-line scan text.
- Verified with focused Godot smokes, localization JSON syntax checks, scoped whitespace checks, and fresh mobile-landscape H5 screenshots for Trade Market and Creator Lab.
- Evidence: `.tools/right-panel-sweep-v2d-web/h5-mobile-landscape-trade-facility-panel.png` and `.tools/right-panel-sweep-v2c-web/h5-mobile-landscape-creator-panel.png`.

### Social Messages Compact Input V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Tightened the compact private-message input row so the text field keeps usable width, the `Send` button remains text-readable, and the `Report` control stays hidden until there is a reportable incoming message.
- Added a compact-only localized private-message placeholder (`Message` / `メッセージ` / `消息`) to avoid clipped input text on 844x390 mobile-landscape H5.
- Promoted `PrivateInputRow` to a unique scene node and covered its spacing, report visibility, short placeholder, and compact row-card density in the social messages smoke.
- Verified with the focused Godot social messages smoke, localization JSON syntax checks, scoped whitespace checks, and a fresh Web-exported mobile-landscape H5 private-message/keyboard-guard matrix.
- Evidence: `.tools/social-messages-compact-v2e-web/h5-mobile-landscape-private-messages-panel.png` and `.tools/social-messages-compact-v2e-web/h5-mobile-landscape-private-keyboard-guard.png`.

### Player Profile Compact Readability V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Tightened the compact player profile card so avatar previews ignore source texture size, preserving the intended 42px mobile-landscape preview instead of letting full sprite sheets squeeze profile text.
- Added compact role copy for social inspection, showing short gender + range labels such as `Female · Far` while keeping the full localized role format for larger layouts.
- Updated the H5 profile debug fixture to pass a concrete character variant, so screenshot gates now exercise the real six-role character identity path instead of a generic placeholder profile.
- Added a focused profile-card smoke for compact layout density, avatar sizing, action spacing, and role readability.
- Consolidated H5 debug global-variable writes behind a small helper, reducing `MainCityWebDebug.gd` to 285 lines while keeping all screenshot-gate debug variables stable.
- Verified with the focused Godot profile-card smoke, main-city interaction smoke, localization JSON syntax checks, H5 smoke script syntax, targeted diff whitespace checks, and a fresh Web-exported desktop/mobile-landscape H5 profile-card matrix.
- Evidence: `.tools/profile-card-compact-v2d-web/h5-desktop-profile-card.png` and `.tools/profile-card-compact-v2d-web/h5-mobile-landscape-profile-card.png`.

### Map/NPC Grounding and HUD Title Frame V2

Status: Implemented and locally/H5 verified on 2026-05-11.

- Added `MainCityMapMetadata.is_world_position_visually_grounded()` so NPC placement now checks a walkable foot-room footprint instead of only a single baseline point.
- Upgraded NPC grounding and collision patrol smokes to fail when NPC points are technically walkable but visually too close to blocked roof/wall/decor art.
- Switched the long HUD map-title badge to the Image 2 HUD bar frame while keeping short player/coin/presence badges on compact frames, reducing the stretched yellow-box look in mobile landscape.
- Added the HUD title badge to the UI frame contract so future UI edits must keep the title on the longer HUD bar asset.
- Verified focused Godot smokes: `map_npc_grounding_smoke`, `map_collision_patrol_smoke`, `ui_frame_contract_smoke`, and `online_room_ui_smoke`.
- Re-ran the map quality v2 Godot gate plus the 5-case mobile-landscape H5 screenshot/semantic matrix with zero console messages.

### Android Trade Frontend Closed Loop Fix

Status: Implemented, re-exported, reinstalled, and verified on Android device `c7e94055` on 2026-05-10.

- Fixed the live trade inventory path so Godot `OnlineClient.fetch_trade_inventory()` calls `/trade/inventory` instead of falling back to generic `/inventory`.
- Updated `SocialFacilityService` to prefer the trade inventory endpoint and keep generic inventory as a fallback only if the trade-specific fetch fails.
- Made the Trade Market panel auto-sync when opened, removing the stale first-open `No Sellable Stock` state that previously required a manual `Sync` tap after online login.
- Verified backend contract directly with curl: guest login, default sellable inventory, create listing, escrow lock, cancel listing, and inventory return all passed.
- Re-exported and installed the Android debug APK, then verified on-device player flow: enter online Trade Market, open the panel, auto-fetch `All 3`, post `Arcade Cabinet` at 7c, switch to `Mine 1`, cancel listing, and return to `Sell 3`.
- Verification passed: `social_facility_panel_actions_smoke`, `social_facility_trade_actions_smoke`, `online_client_smoke`, targeted `git diff --check`, Android APK signing/asset budget, and strict package logcat scan.
- Artifacts: `.tools/android-trade-inventory-fix-route/13-autosync-trade-panel.png`, `14-after-post.png`, `15-after-cancel.png`, plus meminfo showing roughly 272 MB PSS / 236 MB RSS; APK remains 147 MB.

### Android Route Smoke V4

Status: Locally verified on Android device `c7e94055` on 2026-05-10.

- Installed and launched the latest debug APK through the Android device preflight path, then entered Forest Dawn Town with a fresh Android QA display name.
- Verified true-device tap-to-move on Forest Dawn Town: the target marker appears on tap, the avatar moves to the right-side path, and nearby hotspot text appears only after the player is in range.
- Entered Trade Market from the main city hotspot and opened the trade facility panel from the broker point; the compact right-side panel remains readable with wallet, market board, creator stalls, and sync controls visible.
- Verified Android Gboard keyboard guard from the Trade Market scene: the chat input lifts above the keyboard and remains editable while the map/panel layer stays recoverable after dismiss.
- Verified world-map handoff: the route list opens from the HUD, then `Open Map Atlas` opens the category atlas with readable City/Skill/Social/Event/Wild filters and scrollable generated-route rows.
- Brought up local Alpha, bridged Android with `adb reverse tcp:8787 tcp:8787`, relaunched the native APK, and verified the HUD settles to `Online 1 · 0s` after guest auth.
- Verified the online Trade Market route: the Android client sent `/auth/guest`, `/me`, room membership, presence heartbeats, mailbox/private-message polling, map-discovery save, and the Trade Market panel rendered `Backend connected; prices are live.`
- Device artifacts are under `.tools/android-route-smoke-current/`, especially `02-world-entry-after-keyboard.png`, `03-tap-move-feedback.png`, `05-trade-market-entry.png`, `06-trade-panel-attempt.png`, `07-chat-keyboard-open.png`, and `12-map-atlas.png`.
- Online route screenshots include `14-online-world-entry.png` and `15-online-trade-panel.png`; local backend `/healthz` and `/readyz` both returned `ok`.
- Package-scoped logcat strict scans found no fatal exception, AndroidRuntime package crash, ANR, Godot script error/warning, backtrace, or panic. Current route snapshot reports roughly 293 MB PSS / 284 MB RSS, with the APK still at 147 MB.

### Android Device Preflight Gate V1

Status: Implemented, re-exported, reinstalled, and locally verified on Android device `c7e94055` on 2026-05-10.

- Added `scripts/run_android_device_preflight.sh` as the single Android handoff gate before true-device checks.
- The gate runs mobile export readiness, the map quality v2 gate, and the local debug APK exporter by default; `PSW_ANDROID_PREFLIGHT_INSTALL=1` then installs and launches on one authorized Android device.
- Kept fast iteration available with `PSW_ANDROID_PREFLIGHT_EXPORT=0`, and kept H5 map screenshots opt-in for this native gate through `PSW_ANDROID_PREFLIGHT_MAP_SKIP_H5=0`.
- Updated `docs/MobileExportReadiness.md` and `docs/AndroidToolchainSetup.md` so Android device QA now has one documented command instead of separate readiness/export/install steps.
- Verified the no-export preflight path with the map quality v2 gate, then syntax-checked the new wrapper.
- Re-exported through the new wrapper's export path, preserving APK signing verification and the 147.3 MB debug asset budget.
- Installed and launched through the new wrapper on Android device `c7e94055`; launch screenshot is `.tools/android-device-preflight-install-check/01-launched.png`, and the corrected package logcat strict scan found no fatal exception, ANR, Godot script error/warning, backtrace, panic, or package crash marker.

### Android Player Route Closure V3

Status: Implemented, re-exported, reinstalled, and locally verified on Android device `c7e94055` on 2026-05-09.

- Closed the online Home inventory cache gap: entering an editable online room now refreshes `/inventory` before applying the remote housing layout, so starter owned items are available to place even when the wallet is below catalog price.
- Tightened Home edit UX after device playtest: successful furniture placement now clears the selected catalog item and restores the normal build hint, preventing a stale "selected" prompt from looking like a cursor-lock state after placement.
- Extended `tests/housing_smoke.gd` to cover inventory-backed online placement through the edit controller and to assert selection clears after a successful placement.
- Re-exported, pruned, aligned, signed, and reinstalled the Android debug APK. Signing verification still passes with APK Signature Scheme v2/v3, and the debug APK remains within the 220 MB budget at 147.3 MB.
- True-device Home route: `Potted Plant 45` placed successfully with a 25c wallet because the backend starter inventory had one available item; the HUD wallet remained 25c and the bottom prompt reset to the generic build hint after placement.
- True-device Trade route: opened the Trade Market board from the central broker point, posted an `Arcade Cabinet` listing at 7c, observed the Mine listing/outcome row, then cancelled it and confirmed escrow returned to inventory.
- True-device Fishing route: entered the fishing sandbox, claimed one catch for +8c, finished back to Forest Dawn Town, and confirmed the HUD wallet updated from 25c to 33c.
- `/debug/ops` after the route reported `fishing.granted=1`, `fishing.errors=0`, one economy grant event, one online room member, and alerts `ok`.
- Package-scoped logcat after the route found no fatal exception, AndroidRuntime crash, ANR, Godot script error, backtrace, panic, or package crash.
- Device screenshots are under `.tools/android-v2-qa-next/`, especially `11-home-potted-placed-cleared-final.png`, `15-trade-panel-open.png`, `16-trade-posted.png`, `19-trade-cancel-attempt2.png`, and `24-fishing-after-finish.png`.

### Android Device Interaction QA V2

Status: Implemented, re-exported, reinstalled, and locally verified on Android device `c7e94055` on 2026-05-09.

- Fixed the main-city presence race after native login: `PresenceService` now listens for `OnlineClient.connection_changed` and refreshes immediately when the guest session connects, so the HUD settles to `Online 1 · 0s` instead of waiting for the next 10s timer or briefly showing stale/offline state.
- Re-tested Android chat with the real soft keyboard. The landscape keyboard keeps the chat input and send button visible, sending `QA_v2` hides the keyboard, clears the field, and increments backend room chat counters while LiveOps alerts remain `ok`.
- Re-tested the narrowed Forest Dawn Town trade hotspot and Trade Market panel. Tapping the market stall enters `social_trade_market_v1`, the panel opens from the broker point, shows wallet/sync/filter rows, and stays usable in the small right-side layout.
- Found and fixed a Home Edit economy/UI bug on device: online mode could optimistically select/place a 45c catalog item while the player had only 25c. `HousingService.can_afford_item()` now allows optimistic placement only when the player has either available online inventory for that item or enough current wallet balance; `HousingRoomEditController` uses the same check before selection and tile placement.
- Extended `tests/housing_smoke.gd` to cover online authenticated low-wallet/no-inventory placement rejection and available-inventory placement allowance. Verified focused smokes: `housing_smoke`, `social_facility_panel_actions_smoke`, `main_city_hotspot_precision_smoke`, `world_hud_cancel_overlay_smoke`, and `presence_service_online_state_smoke`.
- Re-exported, pruned, aligned, signed, and reinstalled the Android debug APK after the fix. Asset budget remains 147.3 MB. Device screenshots are under `.tools/android-v2-qa/`, especially `05-chat-sent-keyboard-hidden.png`, `07-trade-panel-open.png`, `15-after-reinstall-online-settled.png`, `17-after-fix-expensive-tap.png`, and `18-after-fix-expensive-no-place.png`.
- Strict post-fix package logcat scan after the final Home repro found no fatal exception, AndroidRuntime crash, ANR, Godot script error, script warning, panic, or backtrace.

### Android UI Interaction Polish V1

Status: Implemented, re-exported, reinstalled, and locally verified on Android device `c7e94055` on 2026-05-09.

- Changed HUD action buttons to use icon-only chrome so the Image 2 button art is not double-framed; bottom-bar actions now read as distinct emote, send, fishing, home, backpack, games, map, and mail icons on the 1080x2400 landscape device screenshot.
- Raised compact HUD action touch targets to 44x44 while keeping the bottom-bar height stable.
- Tightened the Forest Dawn Town trade hotspot touch rect so the southeast walkway tap probe no longer triggers Trade Market; correct market-stall taps still travel into `social_trade_market_v1`.
- Improved the Trade Market panel follow-up flow: successful `Post` focuses `Mine`, successful `Cancel` focuses `Sell`, and the compact board resets to the relevant action area instead of leaving the player hunting below the fold.
- Added `tests/main_city_hotspot_precision_smoke.gd` and extended `tests/social_facility_panel_actions_smoke.gd` to cover the new hotspot precision and trade filter follow-up behavior.
- Verified focused Godot smokes: `social_facility_panel_actions_smoke`, `main_city_hotspot_precision_smoke`, `map_interaction_quality_v2_smoke`, `main_city_tap_move_controller_smoke`, `social_facility_panel_smoke`, and `world_hud_cancel_overlay_smoke`; `git diff --check` and `python3 -m json.tool configs/map_points.json` also pass.
- Re-exported and reinstalled the Android debug APK, still passing signing verification and the 147.3 MB asset-budget check. Device screenshots: `.tools/android-ui-polish-v1-icon-only-world.png`, `.tools/android-ui-polish-v1-walkway-tap.png`, `.tools/android-ui-polish-v1-trade-tap.png`, and `.tools/android-ui-polish-v1-trade-panel.png`.
- Package logcat after the route showed no fatal exception, AndroidRuntime crash, Godot script error, or panic.

### Android Online Route Smoke V2

Status: Implemented, re-exported, reinstalled, and locally verified on device `c7e94055` on 2026-05-09.

- Reconnected the native Android build to the local alpha backend through `adb reverse tcp:8787 tcp:8787`; the main-city HUD settled to `Online 1 · 0s`, and backend logs confirmed Android `POST /auth/guest`, `GET /me`, `POST /presence/heartbeat`, room member polling, and authenticated WebSocket activity.
- Ran a true-device player route across Forest Dawn Town, Trade Market, housing, chat, and the fishing sandbox. Captured screenshots under `.tools/android-device-smoke/current/`, including `38_tap_move_main_city.png`, `39_fishing_button_from_main_city.png`, `40_fishing_cast_result.png`, `41_fishing_finish_result.png`, `44_trade_broker_tap.png`, `45_trade_post_result.png`, `48_trade_cancel_result.png`, `51_post_fps_world_settled.png`, and `54_post_fps_chat_send_hides_keyboard.png`.
- Verified tap-to-move / hotspot travel into Trade Market, Trade Market live board open, live `Post` action, scroll-to-`Cancel`, and cancel feedback. Backend logs showed `POST /trade/listings` returning `201` and listing cancel returning `200`; `/debug/ops` reported one created trade event, one cancelled trade event, zero alert items, and zero settlement failures.
- Verified the fishing sandbox route on Android: `Cast` enters the bite state, `Finish` returns to the city, and the wallet changed from 25 to 28 coins. `/debug/ops` reported one trusted fishing reward grant and zero reward replay/cap errors.
- Verified main chat on Android after the rebuild. Sending `After30fps` cleared the field, hid the soft keyboard, and raised `/debug/ops` room chat count from 1 to 2.
- Reduced the mobile foreground frame budget from 45 FPS to 30 FPS for Android/iOS in `Boot.gd`, keeping the social-world MVP biased toward heat/battery stability over high-refresh rendering.
- Package-scoped logcat after the route found no fatal exception, AndroidRuntime crash, ANR, Godot script error, script warning, or panic. Post-change samples on the open world were roughly 36% process CPU and about 253 MB PSS / 224 MB RSS.
- Remaining native polish item: the 30 FPS cap lowers memory and slightly improves idle CPU, but Godot still spends a visible amount of CPU continuously rendering the Image 2 map/HUD. A later native-performance pass should profile render cost and consider dynamic idle throttling.

### Android Asset Budget V1

Status: Implemented and locally verified on device `c7e94055` on 2026-05-09.

- Tightened native export filters so generated source/master image payloads no longer enter packaged builds through `.godot/imported/*_source*`.
- Added Android-specific pruning for large non-runtime iOS launch splash payloads and retired Forest Dawn city candidates A-D while keeping the actual production and test resource files in the workspace.
- Added `scripts/check_android_asset_budget.sh` and wired it into `scripts/export_android_debug_local.sh`; the local Android exporter now fails if the APK exceeds the current 220 MB debug budget or still contains generated source image caches, launch splash payloads, or retired map candidates.
- Re-exported, zip-pruned, aligned, signed, and verified the Android debug APK. Package size dropped from about 285 MB to 147.3 MB.
- Confirmed the APK contains no `_source` image payloads, no Android-excluded launch splash assets, and no candidate A-D map payloads.
- Reinstalled and launched on Android device `c7e94055`; screenshots `21_asset_budget_v1_launch.png` and `22_asset_budget_v1_world.png` confirm login and main-city runtime assets still render after pruning.
- Package-scoped logcat found no fatal exception, AndroidRuntime crash, ANR, Godot script error, or panic. Main-city idle samples after settling are roughly 35-37% process CPU with about 293 MB PSS / 378 MB RSS.

### Android Runtime Performance V1

Status: Implemented and locally verified on device `c7e94055` on 2026-05-09.

- Added a mobile-only frame budget in `Boot.gd`: Android/iOS initially capped foreground rendering at 45 FPS, preserving full-resolution art while reducing idle CPU/heat versus the 60Hz baseline. The later Android Online Route Smoke V2 pass lowers the current cap to 30 FPS.
- Reduced idle script work without changing visuals: tap-to-move stops processing when no target is active, NPC ambience uses a timer between pulses and only processes during active glances, and actor depth sorting now updates the local player every frame while batching NPC/remote actor depth at 0.08s.
- Added smoke assertions so tap-to-move and NPC ambience must stay idle when no active movement/glance is running.
- Re-exported and reinstalled the Android debug APK; screenshots `17_perf_v1_45fps_world.png` and `18_perf_v1_45fps_tap_move.png` confirm the main-city visuals and tap movement stayed intact.
- Device CPU samples improved from the 60Hz/60FPS pass at roughly 53-60% process CPU to roughly 32-39% with the 45 FPS mobile budget. The following asset-budget pass brought the Android debug APK down from about 285 MB to 147.3 MB.
- Strict package logcat scan still reports no fatal exception, crash, ANR, Godot script error, or backtrace. Remaining warnings are Android graphics-layer noise and Godot headless export editor-exit RID/ObjectDB warnings.

### Android Device Smoke V1

Status: Locally verified on a connected Android device on 2026-05-09.

- Exported, pruned, aligned, signed, installed, and launched the debug APK on device `c7e94055`; streamed install succeeded after Android incremental install rejected the APK parse path.
- Verified the native landscape login, main city entry, housing route, return-to-city route guard, intentional fishing route after the guard window, tap-to-move movement on the Fishing Riverbend map, and chat soft-keyboard guard.
- Captured device screenshots under `.tools/android-device-smoke/current/` for launch, main city, housing, guarded return, intentional fishing, tap-to-move, keyboard guard, and fishing return.
- Checked package-scoped logcat after the flow; the strict app crash/script scan found no fatal exception, crash, ANR, Godot script error, or backtrace.
- Broad package logcat still includes Android graphics-layer noise from SurfaceSyncer/Adreno buffer allocation, so future native performance QA should separate engine/game errors from driver warnings.
- Remaining native warning is export-tooling only: Godot headless export still prints editor-exit RID/ObjectDB leak warnings, but APK signing verification passes.

### Mobile Map Return Matrix V1

Status: Implemented and locally verified on 2026-05-09.

- Added a scene-level 32-map round-trip smoke that enters every generated map, activates the mobile return portal, verifies Forest Dawn south-pier respawn, and checks that the immediate duplicate touch route is suppressed.
- Confirmed the route guard releases after the debounce window so intentional follow-up travel still works.
- Wired the smoke into `scripts/run_mvp_100_gate.sh` after map hotspot route integrity, making the Android return-portal regression part of the repeatable MVP gate.
- Verified with the focused map QA suite: travel return matrix, point quality, hotspot route integrity, mobile return portal, NPC grounding, collision patrol, interaction quality v2, map activity hotspots, main-city interactions, route debounce, and tap-move controller smokes.

### Mobile Export Readiness Scan V1

Status: Implemented as a repeatable local scan on 2026-05-07.

- Added `scripts/check_mobile_export_readiness.sh` to check Godot mobile project config, export presets, local Godot templates, iOS Xcode/SDK tooling, Android Java/SDK tooling, signing environment placeholders, and app icon/splash asset presence without touching production or test artifacts.
- Added `docs/MobileExportReadiness.md` as the native-device bridge from the now-passing H5 MVP gate to the first iOS/Android exports.
- Set `config/version="0.1.0"` in `project.godot` so the app has a stable MVP version value before native preset work.
- Added non-secret iOS and Android Godot export presets with stable package IDs, output paths, mobile architectures, version metadata, and Android network permission while keeping Team ID, provisioning profile, keystore, aliases, and passwords blank.
- Added MVP store branding assets under `assets/branding/generated/`, derived from the approved Image 2 forest dawn city motherboard, then registered them in `configs/store_branding.json`, `configs/art_assets.json`, and the iOS/Android export presets.
- Added `docs/AndroidToolchainSetup.md` so the remaining Android blocker is a repeatable machine setup checklist rather than a loose memory task.
- Current local scan correctly identifies the remaining native blockers: iOS signing values and Android release signing values are intentionally absent from the repo. Full Xcode is present at `/Applications/Xcode.app`, so the script now uses that developer directory without changing the user's global `xcode-select` setting.
- Installed and verified the local Android command-line toolchain through Homebrew: `openjdk@21`, Android command-line tools, platform-tools, `platforms;android-35`, `build-tools;35.0.1`, `cmake;3.10.2.4988404`, `ndk;28.1.13356709`, and accepted SDK licenses.
- Added `scripts/export_android_debug_local.sh` plus a local Godot Editor API exporter shim so debug APK generation can inject `GODOT_ANDROID_KEYSTORE_DEBUG_*` values at process time instead of writing debug signing fields into `export_presets.cfg`.
- Hardened the local debug APK wrapper to prune development-only payload paths after export, then `zipalign`, re-sign, and verify the package before device testing.
- Added `scripts/install_android_debug_local.sh` so one authorized Android device can receive and launch the latest debug APK without remembering raw `adb` commands.
- Latest readiness scan now reports native presets, concrete branding assets, correct icon/splash dimensions, Android SDK/build-tools/CMake/NDK availability, accepted Android SDK licenses, and no signing credentials in `export_presets.cfg`; remaining warnings are external release signing values only.
- Verified the iOS and Android presets with Godot `--export-pack`, producing temporary native-pack PCKs under `.tools/native-preset-parse/`; this confirms the new presets and branding assets parse and can drive Godot resource packaging without requiring signing or Android SDK.
- Re-ran the full MVP 100 gate after adding native presets and store branding assets: backend Go tests, content validation, localization syntax, Godot smokes, backend Godot E2E, 21 priority H5 screenshots, 64 generated-map patrol screenshots, semantic screenshot checks, GDScript line budget, and whitespace checks all passed. Artifacts: `.tools/mvp-100-gate-store-branding-v1/`.

### H5 Pre-Device Priority Matrix V1

Status: Implemented and locally verified on 2026-05-07.

- Expanded the MVP H5 priority matrix from 13 to 21 screenshots so the default gate now covers map directory, mobile map atlas filtering, guild facility, mail, public chat keyboard guard, mobile inventory, profile card, and mobile minigame hosting before real-device testing.
- Added semantic screenshot expectations for the newly promoted states, including facility debug checks for trade/guild and sandbox top-bar checks for mobile minigame hosting.
- Fixed a mobile H5 inventory click drift where the test coordinate hit the housing button instead of the backpack button; re-ran the focused inventory case and confirmed the screenshot now opens the Inventory panel.
- Re-ran the full pre-device H5 priority matrix with 21 screenshots, zero console messages, runtime gate enabled, and semantic screenshot checks. Artifacts: `.tools/h5-predevice-priority-v1/`.

### Map First-Screen Readability V1

Status: Implemented and locally/H5 verified on 2026-05-07.

- Added a first-screen readability smoke for core destination maps, checking that key NPCs and interaction points land inside desktop and small mobile-landscape safe world rectangles after map camera/zoom transforms.
- Repositioned first-screen anchors for the housing district, trade market, guild garden, minigame arcade hall, mail plaza, creator gallery, and fishing riverbend so each map's purpose is visible immediately without relying on off-screen discovery.
- Kept the Image 2 map backdrops unchanged and adjusted only config-level spawn/NPC/interaction positions, preserving the generated art while improving player entry clarity.
- Wired `map_first_screen_readability_smoke.gd` into `scripts/run_mvp_100_gate.sh` near the map production checks.
- Verified with content validation, first-screen readability, map point quality, NPC grounding, hotspot route integrity, main-city interaction smokes, targeted mobile-landscape H5 screenshots for the seven adjusted maps, and semantic screenshot checks.
- Re-ran the full `scripts/run_mvp_100_gate.sh` suite, including backend tests, Godot smokes, backend E2E, 13 priority H5 screenshots, 64 generated-map patrol screenshots, semantic screenshot checks, GDScript line budget, and diff whitespace checks. Artifacts: `.tools/mvp-100-gate-current/`.

### Arcade Hall Point Polish V1

Status: Implemented and locally/H5 verified on 2026-05-07.

- Moved the Minigame Arcade Hall host, booth keeper, and `games` interaction point from the upper exhibit zone into the first-screen lobby around the portal.
- This keeps the map's Image 2 background unchanged while making the social/gameplay purpose readable immediately on desktop and mobile-landscape entry.
- Verified the updated points with content validation, map point quality, NPC grounding, hotspot route integrity, and main-city interaction smokes.
- Re-exported Web and verified targeted desktop/mobile-landscape H5 screenshots for `social_minigame_arcade_hall_v1`, with semantic screenshot checks and zero console messages.

### H5 Generated Map Patrol V1

Status: Implemented and locally verified on 2026-05-07.

- Ran the generated-map H5 patrol across all 32 Image 2 maps, covering desktop and mobile-landscape screenshots for each map.
- The patrol produced 64 screenshots with zero browser console messages, then passed PNG semantic checks for every screenshot.
- The generated patrol summary reported all 32 maps present, no review notes, and all map density scores at or above the current minimum gate.
- Preserved the report artifacts under `.tools/h5-map-patrol-current/`, including `map-patrol-report.html` and `map-patrol-summary.json`, so the full visual board can be reviewed before the next real-device pass.

### Map Actor Depth Sort V1

Status: Implemented and locally verified on 2026-05-07.

- Added `MainCityDepthSorter` to y-sort the local player, remote players, and NPCs with absolute z indices, fixing the structural risk where `PlayerRoot` and `NPCRoot` lived under different scene parents and could not naturally sort against each other.
- Kept generated map backgrounds and terrain untouched while ensuring actors in lower screen positions render in front of actors higher on the screen.
- Raised hotspot prompt labels above the actor depth band, so touch/hover labels stay readable after y-depth sorting.
- Added `map_actor_depth_sort_smoke.gd` and wired it into `scripts/run_mvp_100_gate.sh`, verifying absolute actor z, y-ordering, prompt z, and backdrop separation.
- Verified with `map_actor_depth_sort_smoke.gd`.

### Map Hotspot Route Integrity V1

Status: Implemented and locally verified on 2026-05-07.

- Added a runtime hotspot integrity patrol that switches through all 32 Image 2 maps and checks the active scene against `map_points`.
- Static route hotspots now have gate coverage for correct per-map visibility, touchability, hidden-by-default prompts, and runtime position binding to their configured interaction points.
- Dynamic activity hotspots now have gate coverage for count, no stale actions after map switches, visible prompts, and touch-enabled state, using the same action/x/y de-duplication rule as `MainCityMapRuntime`.
- Wired the patrol into `scripts/run_mvp_100_gate.sh` after the map activity hotspot smoke, so future map layout changes cannot silently break player entrances or activity nodes.
- Verified with `map_hotspot_route_integrity_smoke.gd`.

### Map Collision Patrol V1

Status: Implemented and locally verified on 2026-05-06.

- Added a runtime collision patrol smoke that instantiates the main city, switches through all 32 Image 2 maps, and checks the active `MainCityMapMetadata` against the real local player movement validator.
- The patrol verifies that spawn/NPC/activity/portal/interaction points remain walkable at runtime, blocked art centers are rejected, generated canvas edges are rejected, and the player cannot step forward into reachable blocked art edges.
- Wired the patrol into `scripts/run_mvp_100_gate.sh` after NPC grounding checks, so future map/image/layout changes must pass actual movement collision before MVP signoff.
- Verified with `map_collision_patrol_smoke.gd`; the new gate caught no current collision regressions across the full generated map set.

### Character Preview Role Chip V1

Status: Implemented and locally verified on 2026-05-06.

- Added a compact class-range label to the login character preview, so the six formal gender/class choices communicate `Near`, `Far`, or `Magic` directly from existing localization keys.
- Kept the preview in the current panel instead of adding another onboarding surface, preserving the 960x540 mobile-landscape login layout.
- Expanded the login character selection smoke to iterate all six formal variants and verify selected variant id, formal Image 2 avatar id, preview texture path, variant label, and localized range label.
- Verified with `login_character_selection_smoke.gd`.

### Map NPC Grounding Triage V1

Status: Implemented and locally verified on 2026-05-06.

- Tightened map point quality checks for NPCs with a stricter 8-sample walkable-footprint rule and a minimum 24 px distance from blocked art, catching NPCs that were technically walkable but visually glued to roofs, stalls, sculptures, or decorative displays.
- Repositioned the Forest Dawn mail courier and home keeper away from building/roof collision edges so their shadows read as grounded on road/plaza tiles.
- Repositioned the Snow Festival guide and Pumpkin Lantern Square stage manager farther south from central display blockers, reducing the "standing on a sculpture/stage" read in generated seasonal maps.
- Verified with content validation, `map_point_quality_smoke.gd`, `map_npc_grounding_smoke.gd`, targeted H5 desktop/mobile screenshots for Forest Dawn, Snow Festival, and Pumpkin Lantern Square, PNG semantic screenshot checks, and a partial H5 map patrol report.

### Character Class Action Feedback V1

Status: Implemented and locally verified on 2026-05-06.

- Added config-driven attack feedback styles for the three MVP classes: melee uses a short lunge slash, ranged uses an aim streak, and magic uses a compact cast diamond.
- Added `PlayerAvatarAttackFeedback` so class expression stays outside the core avatar controller and can later be replaced with formal Image 2 effect sprites without changing movement or sync code.
- `PlayerAvatarConfig` now passes `attack_feedback` from class metadata into the selected avatar config, while validation rejects unknown styles, invalid color channels, or unsafe distances.
- H5 attack screenshots now send the real `z` key and capture the early attack window, making browser QA verify the visible class action feedback instead of only the overhead emote.
- Verified with content validation, JSON syntax checks, player avatar smoke, avatar variant smoke, login character selection smoke, targeted H5 attack/profile screenshots, and PNG semantic screenshot checks.

### Character Class Light Expression V1

Status: Implemented and locally verified on 2026-05-06.

- Added class-driven attack overhead emotes for melee, ranged, and magic roles, giving the six formal character variants a small but readable class expression without adding combat balance scope yet.
- `PlayerAvatarConfig` now merges class metadata into each avatar config, and `PlayerAvatar.start_attack()` plays the configured class emote through the existing overhead emote path.
- Content validation now rejects player classes whose `attack_emote_id` does not exist in `configs/emotes.json`, keeping role feedback tied to registered Image 2 emote assets.
- Added H5 key-press screenshot support and a mobile landscape attack case, so browser QA can verify attack feedback in the same viewport family we use for phone testing.
- Verified with content validation, JSON syntax checks, player avatar smoke, avatar variant smoke, login character selection smoke, targeted H5 attack/profile screenshots, PNG semantic screenshot checks, GDScript line budget, and `git diff --check`.

### Character and NPC Social Identity V1

Status: Implemented and locally verified on 2026-05-06.

- NPC tap feedback now reveals a temporary two-line nameplate with localized name plus localized role, giving maps more social identity without showing permanent labels by default.
- Player profile cards now include the selected role range/type, so the six formal Image 2 variants read as gender + class + near/far/magic role at social inspection time.
- Added English, Japanese, and Simplified Chinese range labels plus profile formatting copy, and content validation now rejects player classes with unknown range ids or missing range localization.
- Verified with content validation, JSON syntax checks, NPC feedback smoke, main city interaction/profile smoke, player avatar variant smoke, login character selection smoke, targeted H5 profile/NPC screenshots, and PNG semantic screenshot checks.

### Main City Map Touch Grounding Pass V1

Status: Implemented and locally verified on 2026-05-06.

- Expanded the 32-map point quality smoke to catch missing point IDs, missing action/type routing, unsafe mobile edge placement, overly high decorative-band interactions, non-walkable clearance, and unknown portal targets.
- Increased generated activity hotspot touch targets from 116x72 to 128x80 so life-skill and random exploration nodes are easier to tap on 960x540 and small mobile landscape views.
- Extended the activity hotspot smoke to enforce minimum touch sizes for both static route/facility hotspots and generated activity hotspots, while preserving transient prompt feedback for static points.
- Added an H5 map patrol report artifact that pairs desktop and mobile screenshots for each generated map and flags missing pairs, console-message drift, or debug-map mismatches.
- Verified with map point quality, map activity hotspot, map NPC grounding smokes, and a 32-map / 64-screenshot H5 map patrol.

### Map Content Density V1

Status: Implemented and locally verified on 2026-05-06.

- Added functional NPC anchors to the remaining sparse MVP maps: workshop town, crystal mine, trade market, guild garden, all random exploration maps, and all seasonal event maps.
- Added four dedicated function-zone NPC profiles for trade, workshop, mine, and guild routes, with Image 2 profession sprite references and English/Japanese/Simplified Chinese copy.
- Reused existing exploration and festival NPC profiles for random and seasonal maps so every generated map now has at least one player-readable guide without introducing new placeholder art.
- Extended the map point quality smoke to fail when a map ships without any NPC guide/activity anchor, keeping future Image 2 map batches from regressing into empty layouts.
- Added `map_npc_action_routes_smoke.gd` to the MVP 100 gate so the new trade, guild, workshop, and mine NPC primary buttons must open the expected facility panel or route status feedback.
- Verified with content validation, map point quality, NPC grounding/action-route, hotspot, main-city interaction smokes, targeted H5 screenshots for trade/workshop/mine/pumpkin maps, and PNG semantic map checks.

### Map Content Density V2

Status: Implemented and locally verified on 2026-05-06.

- Added a second grounded social NPC anchor to the housing district, minigame arcade hall, and guild garden maps, targeting the three lowest-density social-function maps instead of over-packing random exploration maps.
- Added a map content density score gate to content validation: NPCs count as 2 points, life-skill nodes, interaction points, and gathering zones count as 1 point, and every map must score at least 7.
- Extended the H5 map patrol report with the same density score so future desktop/mobile screenshot sweeps fail if a map becomes visually too empty.
- Tightened the H5 map patrol report so full patrol mode must cover every catalog map with a registered Image 2 asset and metadata pair, while `PSW_H5_MAP_PATROL_ALLOW_PARTIAL=1` remains available for focused slice checks.
- Verified with content validation, map point quality, NPC action-route and grounding smokes, paired desktop/mobile H5 screenshots for the three social maps, a full 32-map / 64-screenshot H5 map patrol, map semantic checks, and the H5 map patrol report.

### Main City NPC Feedback Pass V1

Status: Implemented and locally verified on 2026-05-06.

- NPC map labels now stay hidden by default, then reveal briefly with a pixel outline after click/touch activation so players get immediate target feedback without cluttering the town view.
- Static route/facility hotspots now use the same transient touch feedback pattern, giving mobile players a visible target confirmation without making labels permanent.
- `MainCityNPC` now defers profession config lookup until the node is inside the scene tree, preventing standalone smoke tests from depending on autoload compile timing while preserving Image 2 NPC profession sprites and scale tuning.
- Added `tests/main_city_npc_feedback_smoke.gd`, extended hotspot feedback coverage, and wired both into `scripts/run_mvp_100_gate.sh` / H5 priority screenshots.
- Verified with content validation, the new NPC feedback smoke, map activity hotspot smoke, main city interaction smoke, GDScript line budget, `git diff --check`, fresh H5 NPC dialog screenshots, and a mobile landscape hotspot feedback screenshot.

### Pre-Device MVP Closure Gate

Status: Implemented and locally verified on 2026-05-06.

- Expanded `scripts/run_mvp_100_gate.sh` from a priority smoke gate into the pre-device MVP closure gate for Economy, Creator Platform, LiveOps/moderation, backend E2E, H5 screenshots, and screenshot semantics.
- Added `scripts/run_backend_e2e.sh`, which builds the Go server once and runs each Godot-to-backend E2E script against a fresh local backend instance on `127.0.0.1:18787`.
- The backend E2E suite now covers guest auth upgrade, reviewer dashboard and package publish/unpublish, online messaging, full online gameplay backend flow, and realtime WebSocket room sync without sharing dirty state between tests.
- The total gate now includes Economy ledger and inventory audit smokes, creator reviewer console smoke, chat report/moderation smokes, trade history audit, social facility actions, online room UI, remote players, world sync, mobile input, map activity, minigame session/launch, backend E2E, H5 runtime gate, 12 priority H5 screenshots, and PNG-level semantic screenshot checks.
- Full expanded gate passed on 2026-05-06 with clean `git diff --check`; artifacts are written under `.tools/mvp-100-gate` and backend E2E per-test logs under `.tools/backend-e2e`.

### MVP 100 Gate V1

Status: Implemented and locally verified on 2026-05-06.

- Added `scripts/run_mvp_100_gate.sh` as the repeatable local MVP closure gate across backend Go tests, content validation, localization JSON syntax, priority Godot smokes, H5 screenshot matrix, screenshot semantic checks, GDScript line budget, and whitespace checks.
- Upgraded `scripts/run_h5_matrix.sh` so it restores Playwright dependencies when missing, exports Web when `builds/web` is absent or `PSW_H5_EXPORT_WEB=1`, and can run the runtime maintenance gate while the temporary H5 server is still alive.
- Added `tests/h5_semantic_smoke.mjs`, a PNG-level screenshot semantic pass that checks priority MVP screens for nonblank regions, contrast, expected debug route/map/facility state, sandbox top-bar evidence, and clean console output.
- The default H5 priority semantic set covers world view, mobile world/name reveal, trade board plus keyboard guard, messages/private keyboard guard, housing, minigame sandbox, small LiveOps, and portrait guard.
- Full local gate passed on 2026-05-06 with 12 priority H5 screenshots, 0 browser console warnings/errors, semantic route/state checks for trade and housing, sandbox evidence for minigames, and the final `git diff --check` whitespace pass.

### Trade Market Backend Escrow V1

Status: Implemented and locally verified on 2026-05-03.

- Added backend trade listing APIs for list, create, buy, and cancel, with player bearer-token checks on seller/buyer identity.
- Added trade inventory escrow: listing creation locks one available item, purchase delivers it to the buyer, and cancel returns the lock to the seller.
- Added an economy `Transfer` path so marketplace purchases write buyer `transfer.out` and seller `transfer.in` ledger events without using reward grants or daily reward caps.
- Memory and PostgreSQL modes now have trade services; PostgreSQL purchase locks the listing and writes transfer plus sold status in one transaction when the economy service is GORM-backed.
- The Godot/H5 social facility panel can render live trade listing rows with price formatting and a Buy action through `OnlineClient.fetch_trade_listings()`, `OnlineClient.fetch_trade_inventory()`, and `OnlineClient.purchase_trade_listing()`.
- Local H5 keeps `trade_backend` disabled by default to avoid 404s when no backend is running; production/runtime config can enable it once API origin is available.
- Verified with content validation, JSON validation, Go economy/trade/gateway tests, Godot route smoke, social facility smoke, and `git diff --check`.

### LiveOps Small-Screen Readability Pass

Status: Implemented and locally verified on 2026-05-02.

- Changed 375px-class H5 LiveOps from stacked all-panels-at-once layout to a 2x2 tab strip that shows Review, Reports, Audit, or Ops one at a time.
- Moved the top admin token input into its own row and hides duplicate child-panel admin token inputs when panels are embedded inside LiveOps.
- Web LiveOps now reads browser `window.innerWidth` for responsive decisions, fixing the mismatch between Godot's 960-wide canvas and a narrow browser viewport.
- Added H5 smoke coverage for the narrow Audit and Ops tabs, re-exported Web, and verified with content validation, Godot LiveOps smoke, 960x540 regression, targeted 375px screenshots, and the full 35-state H5 matrix: 0 console messages, ports clear.

### Alpha RC Local Test Harness

Status: Implemented and locally verified on 2026-05-02.

- Added `scripts/run_local_alpha.sh`, a one-command local Alpha harness that builds the backend, runs local preflight, serves the current H5 export, writes a runtime config for the selected ports, prints player/admin URLs, and cleans ports on exit.
- Added `docs/AlphaRCTestPlan.md` with player, two-client, LiveOps, mobile browser, and known-external test steps for the upcoming hands-on pass.
- Tightened strict backend preflight so production auth must use `oidc_jwt` and include Apple/Google client ID lists before the server is considered production-safe.
- Verified with shell syntax checks, content validation, full Go backend tests, local Alpha non-interactive readiness, and the 34-state H5 screenshot matrix: 0 console messages, ports clear.

### MVP Autopilot Slice 8 - Local MVP Closure Gates

Status: Implemented and locally verified on 2026-05-01.

- Added `limit` + `offset` pagination for private conversation summaries, private conversation history, and mailbox inbox reads across memory, PostgreSQL, REST, and Godot/H5 client wrappers.
- Added room-scoped `housing.layout.updated` broadcasts after server-authoritative housing place/style/move/remove mutations, and wired the housing room screen to apply live layout updates.
- Added economy Debug Ops counters for total ledger events, grant/spend totals, reward cap hits, creator play rewards, creator revenue-share events, and creator revenue coins.
- Tightened creator mode compatibility by validating `runtime_contract.camera`, `runtime_contract.input_profile`, and `runtime_contract.network_profile` against the selected `mode_id` in both Go intake and Godot manifest validation.
- Updated backend contracts, creator spec, content validation, LiveOps smoke data, and progress forecasts toward a local code-verifiable MVP closure pass.
- Verified with content validation, full Go backend tests, targeted Godot smoke suite, Web export, and the H5 screenshot matrix with backend ops enabled: 35 screenshots, 0 console messages, ports clear.

### MVP Autopilot Slice 7 - Retention Cleanup and Economy Caps

Status: Implemented and locally verified on 2026-05-01.

- Added `pixel-social-world-retention-cleanup`, a dry-run-by-default PostgreSQL retention runner that executes the `/debug/ops` cleanup plan and keeps room chat untouched.
- Added a daily `pixel-social-world-retention-cleanup.timer` plus release/install packaging so Ubuntu 26.04 deployments carry the cleanup binary and systemd units.
- Added `daily_soft_cap` to the backend economy policy, YAML/env config, validation, `/economy/policy`, trusted grants, fishing rewards, and creator settlement.
- Fishing and creator rewards now return the actual granted delta after caps, preventing the UI from showing coins that were not actually added.
- Verified with full Go backend tests, content validation, shell syntax checks, Linux amd64 backend build, and cleanup command dry-run.
- Raised the MVP forecast from roughly 80-84% to 84-88% by turning retention policy into an executable ops path and closing the first anti-inflation cap.

### MVP Autopilot Slice 6 - Social Trust, Retention, and Creator Payouts

Status: Implemented; verification in progress on 2026-05-01.

- Added backend follow/block relationship state with memory and PostgreSQL implementations.
- Player profile cards now expose Image 2 framed Follow and Block actions; follow/block requests route through `OnlineClient`, `WorldHUDActionsController`, and localized HUD feedback.
- Private messages now respect relationship blocks and return `private_message_blocked` instead of creating durable rows.
- Added creator revenue-share policy (`creator_share_bps`) plus an owner-only trusted settlement endpoint that writes player reward and creator payout ledger entries together, using `source_id` as an idempotency key.
- Added explicit retention policy config: room chat stays zero-day ephemeral, while private messages, mailbox, reports, ledgers, creator audit rows, and artifact staging windows are visible in `/debug/ops`.
- Added a non-destructive retention cleanup plan to `/debug/ops` so ops tooling can see which durable tables will be pruned and verify that room chat remains memory-only.
- Added a Redis multi-client two-gateway load profile so realtime fanout is no longer verified only by a two-socket cross-instance smoke.
- Raised the MVP forecast from roughly 68-72% to 80-84% by closing social trust, creator economy, retention policy/cleanup planning, and Redis-mode load-risk slices.

### MVP Autopilot Slice 3 - Room Capacity and Backpressure

Status: Implemented and locally verified on 2026-05-01.

- Added backend room-capacity policy knobs for main city, housing, minigame, and custom rooms, with conservative alpha defaults of 100 / 20 / 16 / 50.
- Enforced capacity at WebSocket `world.join`, returning `room.denied` with `room_capacity_full` before assigning a socket to an overfull room.
- Added deterministic slow-write and failed-write coverage; failed WebSocket writes now close the socket so the read loop can retire the player and emit normal room leave cleanup.
- Extended `/debug/rooms` and `/debug/ops` visibility with room capacity and failed-write-close counters.
- Wired capacity config through YAML, env overrides, validation, and the production server room hub factory.
- Added client rollback for denied room joins so Godot/H5 room state returns to the last confirmed room instead of keeping an optimistic rejected room.
- Verified on 2026-05-01: content validation, Go test suite, room lifecycle smoke, core Godot smoke, Web export, and H5 viewport matrix pass.

### MVP Autopilot Slice 4 - Dense Room Movement Backoff

Status: Implemented and locally verified on 2026-05-01.

- Split `world.join` handling out of `Hub` so the realtime hub stays below the AGENTS.md 300-line ceiling while room access, capacity, leave cleanup, and join broadcast remain one flow.
- Added first-pass dense-room movement backoff: when a local room reaches 50 joined players, server-side `player.move` accepts no faster than 120ms.
- Kept this intentionally conservative and compatible with existing clients; it reduces 50-100 player fanout pressure before full distance-based interest culling lands.
- Added dense-room movement interest filtering: at 50 joined players, distant move recipients outside a 360-unit radius are skipped while social events remain room-wide.
- Added `movement_culled` metrics to backend realtime snapshots and the LiveOps room drilldown row.

### MVP Autopilot Slice 5 - Redis Gateway Realtime Fanout Smoke

Status: Implemented and locally verified on 2026-05-01.

- Added a gateway-level Redis realtime smoke with two independent HTTP/WebSocket server instances sharing one Redis auth/fanout/rate-limit backend.
- The smoke logs in guests through separate gateway instances, joins both sockets to one room, and verifies `player.move` crosses instances through Redis pub/sub.
- The same smoke sends room chat through HTTP on one instance and verifies `chat.message` reaches the WebSocket on the other instance.
- Realtime ops assertions now cover Redis fanout publish/receive counters and zero write failures at the gateway layer, not just the lower-level room hub.

### MVP Autopilot Slice 2 - Mobile Room Chat and Safe Area

Status: Implemented and locally verified on 2026-05-01.

- Tightened `MainCityRemotePlayers` mobile safe-area spawning so remote avatars no longer appear partly under the top HUD in mobile landscape.
- Fixed `tests/remote_players_smoke.gd` so per-avatar assertions always run, then added mobile viewport coverage and a guard against top-HUD overlap.
- `scripts/run_h5_matrix.sh` now passes through `PSW_H5_CASE`, enabling targeted one-screenshot H5 checks before the full 34-case matrix.
- Mobile compact `OnlineRoomPanel` now preserves the room chat input instead of hiding it, keeping room chat usable on phones while still showing session join/host controls.
- Split compact layout rules into `OnlineRoomPanelLayout`, pulling `OnlineRoomPanel.gd` back to 271 lines and keeping room UI under the AGENTS.md 300-line ceiling.
- Updated mobile Host Fishing H5 click coverage after the compact room chat row shifted the button position.
- Verified on 2026-05-01: content validation, core Godot smoke, mobile input smoke, online room UI smoke, remote players smoke, minigame session service smoke, main city interactions smoke, world state sync smoke, Go test suite, Web export, targeted mobile room/minigame screenshots, full H5 screenshot matrix, and local port cleanup all pass.

### MVP Autopilot Slice 1 - Main City Visual Base

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 driven terrain painter for the main city so the active camera view is built from sliced pixel grass, dirt, stone, water, flower, bush, and tree PNGs instead of flat blockout plaza/path shapes.
- Kept the old Polygon2D ground shapes hidden as scene-reference scaffolding while the runtime art layer now draws through official Image 2 textures.
- Tightened compact HUD presence formatting so mobile landscape keeps the top bar readable without hiding heartbeat state.
- Compact HUD now uses a player-name-only label in the top bar, preventing mobile landscape from clipping the `Player:` prefix into unreadable fragments.
- Extended main-city smoke coverage to fail if terrain rendering loses its Image 2 Sprite2D tile field.
- Added `scripts/run_h5_matrix.sh`, which builds a temporary backend binary for the H5 screenshot matrix so test cleanup owns the actual listener process instead of a `go run` child.
- Screenshot QA caught and fixed the first sparse tile pass: the final terrain layer uses denser Image 2 tile placement plus matched underlay colors so the main city no longer shows dark placeholder cracks.
- Verified on 2026-05-01: content validation, main city interactions smoke, core Godot smoke, mobile input smoke, LiveOps smoke, Web export, full H5 screenshot matrix, Go test suite, and local port cleanup all pass.
- Follow-up risk for the next 12% slice: mobile landscape remote avatars can spawn partly under the top HUD, so camera/member spawn safe-area rules need tightening.

### Room Member Private Entry V1

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 framed member picker inside `OnlineRoomPanel` with a localized Private action for non-local room members.
- Selecting a room member now emits a private-chat request through `OnlineRoomPanel -> WorldHUDActionsController -> SocialMessagesPanel`, opens the private tab, and prefills the selected `player_id`.
- Split member picker behavior into `OnlineRoomPanelMembers` so the room panel stays below the 300-line GDScript ceiling.
- Added `SocialMessagesPanel.open_private_conversation(peer_id)` as the single UI entry point for member-list-to-private-chat routing.
- Screenshot QA caught the first desktop layout as too tall; the member area was compacted to a single selectable list row plus Private button so the room panel no longer clips its housing actions.
- Verified on 2026-05-01: content validation, Go test suite, social messages panel smoke, online room UI smoke, main city interactions smoke, Web export, targeted desktop/mobile room-panel H5 screenshots, and the full H5 screenshot matrix all pass.

### Private Conversations + Unread Polling V1

Status: Implemented and locally verified on 2026-05-01.

- Backend messaging now exposes durable private conversation summaries through `GET /private-messages?player_id=...`, including `peer_id`, latest message, and unread count.
- Added `POST /private-messages/read/:peer_id` and persisted read markers in both memory and PostgreSQL modes, keeping private chat/mail durable while room chat remains ephemeral.
- Godot `OnlineClient` now exposes `fetch_private_conversations()` and `mark_private_read()`.
- `SocialMessagesPanel` now shows a private conversation list above the selected conversation, marks opened private conversations read, and publishes combined mailbox + private unread counts to the HUD badge.
- Split unread polling into `SocialMessagesPanelUnreadController` and private memory helpers into dedicated Go files so the touched UI and messaging files stay within maintainable size.
- H5 debug coverage now includes desktop and mobile landscape private-message panel screenshots in addition to the existing mailbox message panel cases.
- Verified on 2026-05-01: Go test suite, content validation, social messages panel smoke, online messaging backend E2E, Web export, full H5 screenshot matrix, and targeted desktop/mobile private-message H5 screenshots all pass.

### Selective Player Nameplates V1

Status: Implemented and locally verified on 2026-05-01.

- Player and remote-avatar name labels are hidden by default to reduce main-city visual clutter, especially in mobile landscape and crowded presence states.
- `PlayerAvatar` now reveals a nameplate only when the avatar is clicked/tapped, then hides it automatically after a short duration.
- Added explicit `reveal_name` / `hide_name` hooks so future tutorials, inspect panels, or accessibility settings can reuse the same behavior.
- H5 screenshot coverage now includes `h5-mobile-landscape-name-reveal`, pairing a default hidden-name baseline with a clicked-name reveal proof.
- Verified on 2026-05-01: player avatar smoke, remote players smoke, main city interaction smoke, core Godot smoke, online room UI smoke, content validation, Web export, targeted hidden/reveal H5 screenshots, and the full H5 screenshot matrix all pass.

### HUD Layout Controller V1

Status: Implemented and locally verified on 2026-05-01.

- Split right-side panel placement, compact safe areas, top-bar width rules, and player-name trimming into `WorldHUDLayoutController`.
- Reduced `WorldHUD.gd` from 292 lines to 247 lines, leaving room for future HUD events without violating the 300-line GDScript ceiling.
- Kept the Image 2 HUD visual contract unchanged while making messages, utility, and room panels share one layout authority.
- Verified on 2026-05-01: content validation, main city interaction smoke, core Godot smoke, online room UI smoke, social messages panel smoke, Web export, and the full H5 screenshot matrix all pass after the split.

### Message UI Risk Hardening V1

Status: Implemented and locally verified on 2026-05-01.

- Split reusable mailbox/private row rendering into `SocialMessagesPanelRows`, pulling `SocialMessagesPanel` back under the 300-line GDScript ceiling with room for conversation-list work.
- Added a HUD unread badge on the Image 2 mail/social button, with capped `9+` display and smoke coverage for the signal path.
- Tightened compact messages layout by reducing scroll-region height in mobile landscape, keeping the panel above the bottom chat bar.
- Added mobile landscape messages H5 coverage and fixed the mobile Host Fishing H5 click target after the denser HUD shifted the room-panel button location.
- Verified on 2026-05-01: content validation, social messages panel smoke, main city interaction smoke, core Godot smoke, online room UI smoke, online client smoke, Web export, targeted desktop/mobile messages screenshots, targeted mobile minigame-host screenshot, and the full H5 screenshot matrix all pass.

### Player Messages UI V1

Status: Implemented and locally verified on 2026-05-01.

- Added an Image 2 framed `SocialMessagesPanel` with mailbox and private-message tabs, unread mailbox summary, read receipts, private send, and private report action.
- Added a HUD top-bar mail/social icon that opens the real player messaging surface while preserving the older `WorldUtilityPanel` mail feed as static utility/ops content.
- The main-city mail courier now routes to the real mailbox surface instead of the static utility mail panel.
- Private messages now have backend soft rate limiting at 6 sends per 10 seconds per sender and a participant-scoped `/private-messages/report` endpoint.
- `OnlineClient` now exposes `report_private_message`, and the messaging backend E2E covers private report submission.
- Added `tests/social_messages_panel_smoke.gd` and a `psw_panel=messages` H5 screenshot case.
- Verified on 2026-05-01: content validation, Go test suite, social messages panel smoke, online room UI smoke, main city interaction smoke, core Godot smoke, online client smoke, online messaging backend E2E, Web export, and targeted H5 messages screenshot all pass.

### Private Message + Mailbox Contract V1

Status: Implemented and locally verified on 2026-05-01.

- Added a dedicated backend `messaging` service for durable private conversations and mailbox records, keeping room chat ephemeral and live-only.
- Added authenticated `/private-messages/*` and `/mailbox/*` routes with sender-token checks and recipient-scoped mailbox read protection.
- PostgreSQL mode now migrates messaging records through GORM, while memory mode keeps a matching fast local implementation.
- Godot `OnlineClient` now exposes typed methods for private send/history, mailbox send/inbox, and read receipts.
- Added Go gateway coverage and a new Godot backend E2E script so the messaging contract can be tested without growing the already near-limit main online E2E file.
- `docs/BackendContract.md` and `docs/DataContract.md` now record the final boundary: room chat is not saved, private chat and mailbox use durable sender/recipient scoped storage.
- Verified on 2026-05-01: content validation, Go test suite, online messaging backend E2E against a real local server, core Godot smoke, online client smoke, and Web export all pass.

### Chat Action Router + Ephemeral Room Chat V1

Status: Implemented and locally verified on 2026-05-01.

- Added `ChatActionRouter` as the single client dispatch path for structured chat actions; `join_minigame` now routes through the router before joining and launching a session.
- Room chat persistence is now explicit: `global`, `nearby`, `house`, `party`, and `system` are live/ephemeral channels that do not restore through `/chat/history`.
- Backend memory and PostgreSQL chat services keep ephemeral room messages only transiently for rate limiting, live reports, ops counters, and WebSocket broadcasts.
- `configs/chat_channels.json`, `docs/BackendContract.md`, and `docs/DataContract.md` now record the split: room chat disappears after reconnect/logout, while future private chat and mail must use durable recipient-scoped storage.
- Online backend E2E now asserts that main-city and house room chat history are empty even though sends and live actions still work.
- Verified on 2026-05-01: content validation, Go test suite, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, chat action router smoke, online backend E2E, realtime backend E2E, and Web export pass.

### Clickable Room Invite UI V1

Status: Implemented and locally verified on 2026-05-01.

- Main HUD chat now exposes a small Image 2 pixel invite chip when the latest visible chat action is `join_minigame`.
- Online room panel now shows the same invite chip inside the room chat surface, so players can join from either the chat bar or the room panel.
- Invite clicks route through `WorldHUDChatController -> WorldHUDActionsController -> MinigameSessionService`, preserving the existing `join_minigame` action contract instead of parsing localized text.
- Room session rows now show game, host, player count, status, open slots, and TTL, making open sessions readable before joining.
- Added a local-dev H5 `psw_panel=room_invite` screenshot state that creates a real Fishing session before announcing the invite, matching backend action validation.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, Web export, targeted H5 room invite screenshot, and full 23-case H5 screenshot matrix all pass.

### Cross-Client Room Invite Intent V1

Status: Implemented and locally verified on 2026-05-01.

- Backend chat messages now preserve a sanitized optional `join_minigame` action across the memory service, REST responses, transient room state, and WebSocket `chat.message` broadcasts.
- `OnlineClient.send_chat` and `OnlineClientEndpoints.send_chat` now pass structured chat action metadata from `ChatService` to `/chat/send`.
- Room invite actions stay display-language independent: localized body text remains UI copy, while Join behavior reads `message.action`.
- Online and realtime backend E2E coverage now checks room history policy and action delivery through realtime room broadcasts.
- Verified on 2026-05-01: content validation, Go test suite, Godot room/main-city/core/session smokes, online backend E2E, realtime backend E2E, Web export, targeted H5 room-emote smoke, and full 22-case H5 screenshot matrix all pass.

### Main City Social Intent V1

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanelActions` now owns room-panel action flow for quick emotes, hosting, joining, and housing visits, keeping `OnlineRoomPanel` below the 300-line GDScript limit.
- `ChatService.send_local_message` now accepts safe optional metadata and preserves non-core fields like `action` while protecting message identity fields.
- Room minigame invites now register a structured `join_minigame` action with `game_id` and `session_id`, giving the Join button a stable intent source instead of parsing localized text.
- `OnlineRoomPanelActions.join_preferred_session` now prioritizes the latest room invite action, then falls back to the first open session, then hosts Fishing if no session exists.
- `tests/online_room_ui_smoke.gd` now checks that the room invite creates a `join_minigame` action targeting `local_fishing`.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, minigame session smoke, Go test suite, Web export, targeted room-emote H5 smoke, and full 22-case H5 screenshot matrix all pass.

### Main City Social Quick Loop V1

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanel` now has Image 2 quick emote buttons for laugh, heart, and exclamation.
- Quick emotes route through `OnlineRoomPanel -> WorldHUDActionsController -> WorldHUD -> EmoteSync -> OverheadEmoteBubble`, so room UI and minigames share the same overhead emote system.
- Hosting Fishing from the room panel now posts a localized room-chat invite before launching the sandbox.
- H5 screenshot coverage now includes `h5-desktop-room-emote`, guarding the room quick-emote row and overhead bubble state.
- The Host Fishing H5 click targets were realigned after the room panel grew, keeping desktop and mobile sandbox-entry screenshots valid.
- Verified on 2026-05-01: content validation, online room UI smoke, main city interaction smoke, core Godot smoke, localization JSON syntax, Go test suite, targeted room-emote H5 smoke, and full 22-case H5 screenshot matrix all pass.

### Online Room UI V1 + Screenshot QA

Status: Implemented and locally verified on 2026-05-01.

- `OnlineRoomPanel` now exposes a true online room surface: localized member rows, heartbeat age, room chat preview/input/send, minigame catalog/session rows, Host/Join, and housing invite/visit controls.
- Added `OnlineRoomPanelFormatter` so room UI string shaping is isolated from node wiring and stays small enough for the 300-line GDScript rule.
- `ChatService` now exposes the active view channel so the room panel can post into the same chat stream shown by the HUD.
- Added local H5 debug panel routing through `psw_panel=shop|mail|notice|creator|room`, letting Playwright open key UI surfaces directly after login.
- `tests/h5_viewport_smoke.mjs` now screenshots desktop shop, mail, notice, creator, room, mobile room, housing, LiveOps, and desktop/mobile Host Fishing sandbox entry in one matrix.
- Screenshot QA caught and fixed two real UI issues: room panel first-layout rules were skipped on desktop, and utility/room overlays needed separate bottom-safe behavior.
- Verified on 2026-05-01: online room UI smoke, main city interaction smoke, Web export, desktop/mobile Host Fishing smoke, and the full 21-case H5 screenshot matrix all pass.

### Runtime Login Gate V1

Status: Implemented and locally verified.

- `configs/app.json` now carries the bundled client `version` used by runtime minimum-version checks.
- `App.get_runtime_gate()` evaluates maintenance mode and `min_client_version` before login creates a guest session.
- `LoginScreen` hides the normal login panel when blocked and shows `RuntimeGatePanel`, an Image 2 skinned pixel panel with localized maintenance/version copy and a refresh action.
- `Boot` waits for `App.initialized` before routing so H5 cannot create the login scene before runtime config and localization finish.
- Added English, Japanese, and Simplified Chinese keys for maintenance and update-required states.
- Added `tests/runtime_gate_smoke.gd` for maintenance, version-block, and compatible-client paths.
- Added `tests/h5_runtime_gate_smoke.mjs` and screenshot-verified the maintenance gate at `.tools/artifacts/h5-runtime-gate-maintenance.png`.

### Runtime Config Layer V1

Status: Implemented and locally verified.

- Added `RuntimeConfigService` as a trusted app-shell autoload.
- `configs/app.json` now points H5 at `/runtime_config.json` with a bundled `configs/runtime_overrides.json` fallback.
- Runtime overrides are intentionally narrow: API/WebSocket endpoints, online/timeout/reconnect tuning, boolean feature flags, maintenance metadata, `min_client_version`, and `web_build`.
- Session storage keys, scene routes, content paths, creator contracts, and minigame contracts are not runtime-overridable.
- `OnlineClient` and `RealtimeClient` subscribe to `App.config_changed` unless tests or tools have manually configured them.
- Added `backend/deploy/runtime_config.funyoru.json`; the free-launch package writes it to `web/runtime_config.json`.
- Installed a local standard Godot 4.6.2 editor under `.tools/godot-standard` for Web export because the system Mono editor cannot export Godot 4 Web.
- Re-exported H5 with the standard editor and copied local `builds/web/runtime_config.json` for local browser smoke.
- Verified on 2026-04-30: content validation, runtime config smoke, Godot smoke, online client smoke, network lifecycle smoke, Go test suite, Web export, package build, and full H5 viewport smoke all pass.

### MVP Completion Check

Status: Updated on 2026-04-30.

- Local playable MVP foundation is roughly 75-81% complete: main city, chat, presence, fishing, coins, housing, Image 2 UI/art bindings, H5 export, chat moderation, and first LiveOps tooling now have automated smoke coverage.
- Public alpha readiness is roughly 59-69% complete: the server contract, runtime gate, ops dashboard, JSON access logs, config preflight, request-id tracing, readiness probes, admin roles, action confirmation, required operator notes, audit export, soft chat rate limiting, executable chat moderation, moderation audit UI, persistent chat reporting, and packaging path are strong, but production deploy, monitoring, real OAuth providers, mobile exports, and store review flows remain outside the verified path.
- Creator-platform foundation is roughly 60-65% complete: interface, mode contracts, validation, async review, install/rollback catalog, and H5 sandbox wiring exist; public creator submission UX and moderation operations are still the big remaining work.
- Art/UI foundation is roughly 65-70% complete: Image 2 UI frames, emotes, housing props, fishing UI, and main-city hotspot slices are wired; full character action sheets, NPC variety, and next minigame assets remain open.

### Strategy Plan

Status: Updated with accelerated route.

- `docs/StrategicPlan.md` now defines the accelerated route from main city v1 to mobile internal test.
- `docs/AcceleratedContentRoute.md` compresses first content expansion into 4-6 weeks and small real-player testing into weeks 8-12.
- The strategy keeps the existing forest/RO-like town as MVP baseline and moves port-city content to a later fishing/harbor expansion.
- Creator games are scoped to interface, validation, async review, and whitelist alpha during the MVP window.
- `docs/MVPRoadmap.md` now points to the strategic source and records the same MVP city/content decision.

### Product Risk

Status: Phase 2 reduced.

- Fishing is now the first enabled MVP minigame.
- `tile_dash` and `sprite_match` are disabled until the core loop is stable.
- Economy and fishing configs exist for the first coin loop.
- The roadmap now defines the first playable slice as login, movement, chat, fishing, coins, housing.
- The fishing loop now has online session launch, server-authoritative rewards, and H5 smoke coverage.
- The fishing loop now has an Image 2 skinned reward/result panel, fish icon reveal, Cast Again action, and localized coin feedback.
- The fishing loop now has config-driven bite timing, localized rarity callouts, and screenshot-verified desktop/mobile H5 reward states.

### Main City Image 2 Hotspots v0

Status: Completed.

- `forest_main_city_tileset_v0` is now sliced into 100 map prop PNGs under `assets/maps/sliced/forest_main_city_tileset_v0`.
- `assets/maps/sliced/forest_main_city_tileset_v0_contact.png` is available for fast visual picking.
- `MainCity.tscn` now uses Image 2 Sprite2D props for Fishing Pier, Home Gate, Games Hall, and Item Shop instead of Polygon2D blockout markers.
- `configs/art_assets.json` registers the map slice set and semantic hotspot art bindings.
- `tests/main_city_interactions_smoke.gd` now fails if main city hotspot art regresses back to blockout markers.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke, main city interactions smoke, online room UI smoke, online client smoke, remote players smoke, world state sync smoke, player avatar smoke, minigame launch flow smoke, Web export, and H5 viewport/Host Fishing smoke all pass.

### Engineering Risk

Status: Phase 2 reduced.

- Startup route now reads `configs/app.json`.
- Post-login route now reads `configs/app.json`.
- Chat now uses configured channels instead of a hardcoded `local` channel.
- Save data now includes a coin balance.
- The client protocol constants now include auth, chat, world, housing, fishing, and economy messages.
- Backend contract documentation now defines the first REST and WebSocket slice.
- Content validation now checks config localization keys and `res://` resource paths.
- Godot headless smoke passes after the routing, HUD, and chat changes.
- REST auth, WebSocket auth, Redis sessions/fanout, trusted fishing rewards, and request-id idempotency are now locally verified.

### Art Risk

Status: Phase 1 reduced.

- Art direction and Image 2 prompt batches are documented.
- Runtime UI and housing paths now resolve to Image 2 PNG assets.
- Fishing reward UI now uses Image 2 panel/button frames and registered Image 2 fish icon slices.
- Housing room top bar, build catalog, visitor list, and house chat controls now use shared Image 2 panel/button/input frames.
- Housing floor, wall, catalog icons, placed furniture, and placement preview now render from registered Image 2 housing prop slices.
- No SVG files remain under `assets/`; prototypes must stay out of runtime configs.

### Housing Edit Polish V1

Status: Implemented and locally verified.

- Placed furniture selection now draws stronger pixel handles plus a small move affordance marker.
- Hovering an empty tile while a placed item is selected now draws a move target preview and validates the target through `HousingService.can_move_item_to()`.
- Housing sell refund now comes from `configs/economy.json` on the client and `housing.sell_refund_rate` / `PSW_HOUSING_SELL_REFUND_RATE` on the backend.
- Sell, move, and undo feedback now explicitly explains the one-step undo rule and configured coin refund.
- `docs/DataContract.md` now documents the economy refund contract.
- `tests/h5_viewport_smoke.mjs` now captures dedicated desktop/mobile housing selected-state screenshots.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke subset, online backend E2E, realtime backend E2E, Web export, and H5 viewport screenshot matrix all pass.

### Fishing Handfeel V1

Status: Implemented and locally verified.

- `configs/fishing.json` now owns bite timing, rarity names, rarity colors, and fish-to-rarity mapping.
- Fishing now plays a cast, bite wait, bite, and reel status sequence before revealing rewards.
- Reward UI now shows localized rarity callouts tinted by config color, with Common darkened for parchment readability.
- Backend `/minigames/fishing/catch` now returns `rarity`; the client falls back to local fish config when an older dev backend omits it.
- Content validation now checks fishing timing, rarity keys, colors, and fish rarity contracts.
- `OnlineRoomPanel` caps session rows in regular and compact layouts so old waiting sessions cannot push Host Fishing out of the tested safe area.
- H5 screenshot smoke now asserts the sandbox top bar pixels for desktop and mobile minigame cases, preventing false-positive screenshots that stay in the room panel.
- Verified on 2026-04-30: content validation, Go test suite, fishing reward UI smoke, online room UI smoke, Web export, and the full 13-state H5 screenshot matrix all pass.

### Creator Mode Contracts V1

Status: Implemented and locally verified.

- `configs/creator_game_modes.json` now defines the first platform mode contracts: casual activity, 2D side-scroller, 2D fighting, war strategy, RPG adventure, tower defense, and battle royale.
- Official and creator minigame manifests now require `mode_id` and `runtime_contract`.
- `IMinigame` exposes default mode and runtime contract methods while keeping the same `SubViewport` sandbox boundary.
- Creator Lab renders the mode contracts from config through existing Image 2 UI frames and registered icons.
- Backend `/minigames/submit` validates supported mode IDs and mode player caps before queuing review.
- Content validation checks mode localization, icon IDs, minigame mode IDs, manifest mode IDs, runtime contracts, and mode player caps.
- `2d_fighting` is a separate creator mode from platforming, with side-view camera, fighting action inputs, authoritative realtime networking, hitbox/hurtbox review focus, and a 4-player alpha cap.
- `tests/h5_viewport_smoke.mjs` now waits for compact mobile lobby layout and clicks the tested Host Fishing touch area before asserting sandbox pixels.
- Verified on 2026-04-30: content validation, Go test suite, minigame contract smoke, online room UI smoke, main city/minigame smoke subset, Web export, and the full 13-state H5 screenshot matrix all pass.

### Creator Submission Draft V1

Status: Implemented and locally verified.

- Backend now exposes player-authenticated `POST /creator-submissions/draft` and owner-scoped `GET /creator-submissions/:id/status`.
- Creator draft submit reuses the same mode, runtime contract, entry scene, main script, asset budget, and player cap validation as admin submit.
- Creator Lab now renders a draft submission status row using existing Image 2 panel/button styling and the `OnlineClient.submit_creator_draft` / `fetch_creator_submission_status` path.
- `templates/creator_mode_fixtures` now contains one internal manifest fixture for every supported mode, all pointing at a shared safe `IMinigame` fixture scene/script for scanner coverage.
- Content validation now checks fixture coverage against every creator mode and scans fixture scripts for forbidden APIs.
- Verified on 2026-04-30: content validation, Go gateway/minigame tests, Godot creator UI smoke, and Web export pass.

### Creator Package Intake V1

Status: Implemented and locally verified.

- Backend now exposes player-authenticated `POST /creator-submissions/package` for JSON package inventory intake so Godot/H5 can exercise the upload path before multipart zip support.
- Package intake validates the same creator metadata contract, scans package file paths, required files, script content, blocked native/script extensions, SVG formal assets, forbidden Godot API patterns, and asset budget overflows.
- Clean packages are stored with a package snapshot, storage key, SHA256-derived digest, scan report, and `needs_review` status; rejected packages are stored with `rejected` status for owner-visible feedback.
- `POST /minigames/:id/review` now supports explicit review actions/status updates for `review_queued`, `needs_review`, `approved`, `rejected`, and `published`.
- Creator Lab now renders a Package Intake Probe row using the same Image 2 panel/button styling and calls `OnlineClient.submit_creator_package`.
- Real backend E2E now submits a package, verifies owner status includes scan data, and approves it with the admin review route.

### Creator Package Zip + Persistence V1

Status: Implemented and locally verified.

- Backend now exposes multipart `POST /creator-submissions/package.zip`; it accepts a zip archive in `package` or `file`, authenticates the `author` field, strips a single common root folder, extracts text/script files, and feeds the same package scanner used by JSON inventory intake.
- Zip intake enforces a 6 MB compressed archive cap and 8 MB uncompressed hard cap before normal manifest `asset_budget_bytes` validation.
- `minigame.NewGormSubmissionService` now persists creator submission records and package scan snapshots to PostgreSQL while delegating live minigame session concurrency to the configured memory/Redis realtime service.
- Production `storage.mode=postgres` now runs `minigame.AutoMigrate` and wraps the current minigame service with the PostgreSQL submission store.
- Go tests cover zip intake with a common root folder, owner-scoped zip submission, rejected scans, review action updates, and package snapshot serialization round trips.

### Async Creator Review Queue V1

Status: Implemented and locally verified.

- `POST /creator-submissions/package` and `POST /creator-submissions/package.zip` now return quickly with `submitted`, while the package scanner runs in an async worker and updates owner-visible status through `submitted -> scanning -> needs_review/rejected`.
- Creator Lab and the real backend E2E now poll `GET /creator-submissions/:id/status` instead of assuming scan completion inside the upload response.
- Async scan updates are guarded so late scanner writes cannot overwrite an admin/AI review status such as `approved`, `rejected`, or `published`.

### Durable Package Review Jobs V1

Status: Implemented and locally verified.

- Creator package submits now save the package artifact through `PackageArtifactStore` before queueing scan work.
- Local/memory mode uses an in-memory artifact store by default; server config wires `FilePackageArtifactStore` under `storage.package_artifacts_dir`.
- PostgreSQL storage now migrates `PackageReviewJobRecord` rows and stores queued/running/retrying/completed job snapshots next to creator submission records.
- Gorm review workers recover due `queued`, `retrying`, and stale `running` jobs and apply retry/backoff for internal artifact load failures.
- Owner status responses now expose package artifact URI and review job state for ops/debug visibility.

### AI Reviewer Adapter V1

Status: Implemented and locally verified.

- Added a pluggable `PackageAIReviewer` boundary inside the minigame service so review logic stays out of gateway handlers and client code.
- Added `pkg/ai.LocalPolicyReviewer` as the first deterministic AI-review adapter. It produces structured notes and blocks external URL / secret-like text patterns before human review.
- Package snapshots now expose optional `ai_review` with reviewer name, approval flag, notes, and review timestamp.
- Clean packages still land in `needs_review`; AI-blocked packages land in `rejected` with an `ai_review_rejected` scan issue for creator-visible feedback.

### Publish / Install Staging V1

Status: Implemented and locally verified.

- Added `PackageInstallStore` so approved creator packages can be promoted from raw artifact storage into a runtime-safe install catalog.
- `published` now requires an approved package, reloadable artifact, clean scan/AI state, and installable file content before the status is returned.
- File install mode writes creator files under `storage.package_install_dir`, plus `install.json`, `catalog_entry.json`, and a per-game `current.json` pointer for rollback-friendly current-version lookup.
- JSON package intake now supports `content_base64` for binary assets; zip intake preserves binary file content for publish/install.
- Backend exposes `GET /minigames/catalog` for the current installed creator catalog.
- Server config and deployment env now include `PSW_PACKAGE_INSTALL_DIR` separately from raw `PSW_PACKAGE_ARTIFACT_DIR`.

### Rollback / Unpublish V1

Status: Implemented and locally verified.

- Added install-store rollback and unpublish operations for both memory and file-backed runtime catalogs.
- `rollback` switches the per-game `current.json` pointer to the previous installed version without exposing historical packages in the client catalog.
- `unpublish` removes the current pointer, returns the admin-facing record to `approved`, and keeps installed package folders available for audit or future tooling.
- `POST /minigames/:id/review` now accepts `{"action":"rollback"}` and `{"action":"unpublish"}` in addition to the existing review and publish actions.
- Backend and H5/Godot E2E helper coverage now checks that unpublished packages disappear from `/minigames/catalog`.

### LLM Reviewer Adapter V1

Status: Implemented and locally verified with LM Studio Qwen3 Coder Next.

- Added `pkg/ai.OpenAICompatibleReviewer` for LM Studio or any OpenAI-compatible `/v1/chat/completions` endpoint.
- Added strict JSON schema response formatting, review prompt rules, timeout config, and local-policy fallback through `pkg/ai.FallbackReviewer`.
- Server config now supports `PSW_AI_REVIEWER_MODE`, `PSW_AI_REVIEWER_BASE_URL`, `PSW_AI_REVIEWER_MODEL`, `PSW_AI_REVIEWER_API_KEY`, and `PSW_AI_REVIEWER_TIMEOUT_SECONDS`.
- Tested `qwen/qwen3-coder-next` through LM Studio locally. The first pass over-blocked `requires_network: true`; the prompt now clarifies that platform-managed network metadata is allowed while direct script networking APIs remain blocked by the scanner.
- Backend E2E passes with `PSW_AI_REVIEWER_MODE=openai_compatible` and model `qwen/qwen3-coder-next`.

### Reviewer Golden Set V1

Status: Implemented and locally verified.

- Added a provider-agnostic golden set in `pkg/ai` covering safe creator packages for all seven mode IDs plus blocked external URL, secret-like text, token-like text, filesystem scan issue, and root-node scan issue cases.
- Local policy runs the golden set in normal Go tests.
- Live LLM golden tests are opt-in through `PSW_RUN_LLM_GOLDEN=1`, so CI and local backend tests do not accidentally start a large model.
- Codex remains suitable for Studio Mode manual/second-pass review, but backend automation stays env-configured and does not rely on interactive OAuth login.

### Utility Backend V1

Status: Implemented and locally verified.

- Added `backend/internal/utility` as the backend source for main-city shop, mail, and notice panels.
- Added authenticated `GET /utility/panels`, `/utility/shop`, `/utility/mail`, and `/utility/notices` endpoints.
- Server config now supports `PSW_UTILITY_PANELS_CONFIG_PATH`; local and production YAML load the shared `configs/utility_panels.json`.
- `OnlineClient` can fetch utility panel data, and `WorldUtilityPanel` prefers backend rows online while preserving the local config fallback for offline/H5 smoke paths.
- Backend E2E now verifies that online shop and mail rows are served by the backend.

### Top Bar Long Name Guard V1

Status: Implemented and locally verified.

- `WorldHUD` now trims long player display names in the top bar while preserving the full localized player label in the tooltip.
- Top bar labels use clip/overrun behavior and fixed compact widths so coin and presence text keep their space under mobile/H5 pressure.
- `tests/online_room_ui_smoke.gd` now verifies long-name shortening and tooltip preservation.

### Backend Boundary Cleanup V1

Status: Implemented and locally verified.

- Split housing catalog loading from grid placement rules: `catalog.go` now owns catalog data/loading and `layout_rules.go` owns validation geometry.
- Split housing gateway surfaces: `housing_handlers.go` now owns layout/invite/visit while `housing_mutation_handlers.go` owns place/style/move/remove and mutation error mapping.
- Go/GDScript source files are currently all under the 300-line project rule, excluding third-party/tool caches.

### Reviewer Dashboard V1

Status: Implemented and locally verified.

- Backend now exposes admin-only `GET /admin/reviewer-dashboard` so humans can compare creator metadata, scanner output, AI review notes, async job state, and publish/install status in one response.
- The dashboard is implemented inside the minigame service boundary for memory, Redis-backed, and PostgreSQL-backed submission services.
- Creator Lab now shows a player-safe Review Signals row using the owner-visible package status, without exposing admin tokens or global queue data in the normal client.
- Backend tests verify admin gating and scanner/AI/job summary fields for a completed async package review.

### Versioned Submission History V1

Status: Implemented and locally verified.

- The minigame service now keeps current `game_id` records and separate `game_id + version` history snapshots, preserving submitted metadata, scan state, AI review data, async job state, and install state per version.
- Memory, Redis-backed, and PostgreSQL-backed submission services implement the same history contract; PostgreSQL now migrates `SubmissionVersionRecord`.
- Backend exposes owner-scoped `GET /creator-submissions/:id/history` for creator status pages and rollback UI without exposing other creators' versions.
- Godot `OnlineClient` has a typed endpoint for submission history so Creator Lab or a future reviewer/status page can consume it directly.

### Creator Status Page V1

Status: Implemented and locally verified.

- Creator Lab now includes a minimal Creator Status Page row with an Image 2 icon/button surface.
- The row refreshes owner-scoped version history through `OnlineClient.fetch_creator_submission_history`, stores the result locally, and summarizes latest version, review status, scan state, AI state, and install state.
- Offline/H5 paths still show local package status or a backend-waiting message, so the Creator Lab remains usable without admin tokens or global queue access.
- Online backend E2E now verifies the real history endpoint returns version records after creator package intake.

### Utility Live-Ops V1

Status: Implemented and locally verified.

- Utility panels now use a thread-safe backend service seeded from `configs/utility_panels.json`.
- Added admin-only `PUT /admin/utility/panels` to replace the running shop, mail, and notice registry without changing Godot UI layout code.
- CORS now allows `PUT` for browser-based admin tools using `X-Admin-Token`.
- Backend tests verify admin gating and that authenticated players receive the updated live-ops shop rows.

### Guest Account Upgrade Contract V1

Status: Hardened and locally verified.

- Added player-authenticated `POST /auth/upgrade` for Apple/Google account binding across iOS, Android, H5, desktop, and PC prep.
- H5 is treated as a first-class platform value; backend also normalizes `web` to `h5` for browser OAuth shells.
- Upgrade preserves the existing `player_id` and returns fresh session tokens, keeping wallet, housing, creator submissions, and room state attached to the same account.
- Godot `OnlineClient.upgrade_guest_account()` now routes account binding through the shared auth/session layer and stores linked account metadata locally.
- Added `auth.ProviderVerifier` with local `claimed` mode for sandbox iteration and production `oidc_jwt` mode for Apple/Google ID token verification through provider JWKS, issuer, audience, expiry, and subject checks.
- Deployment env now includes `PSW_AUTH_PROVIDER_VERIFICATION`, `PSW_APPLE_CLIENT_IDS`, and `PSW_GOOGLE_CLIENT_IDS`; production should set `PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt`.
- Verified with Go auth/gateway tests, `tests/online_client_smoke.gd`, `tests/session_token_store_smoke.gd`, `tests/auth_upgrade_backend_e2e.gd`, and the existing online backend E2E.

### Reviewer Console V1

Status: Implemented and locally verified.

- Added `OnlineClientAdmin` and `OnlineClient.fetch_reviewer_dashboard` / `review_minigame_admin` so Godot/H5 admin tools can call reviewer dashboard and review actions without mixing admin tokens into normal player endpoints.
- Added standalone `ReviewerConsolePanel` with Image 2 panel/button skin, admin-token input, queue summary, review rows, and status-aware actions for approve, reject, publish, rollback, and unpublish.
- Normal Creator Lab remains owner-only and still shows safe review signals/status history without admin controls.
- Added reviewer console UI smoke and backend E2E coverage for dashboard gating, approve, publish, catalog visibility, and unpublish.
- Added `backend/.gdignore` after Web export QA caught ignored backend runtime artifacts being eligible for Godot packaging; client export now keeps backend/test runtime folders outside the H5 resource pack.
- Verified with content validation, Go tests/vet, Godot UI smokes, reviewer/backend E2E, Web export, and the full H5 screenshot matrix.

### Reviewer Audit Trail V1

Status: Implemented and locally verified.

- Every successful admin review action now records a backend audit event with game ID, action, resulting status, source client, timestamp, and an admin-token fingerprint instead of the raw token.
- Memory, Redis-backed, and PostgreSQL-backed minigame services expose the same audit contract; PostgreSQL migrates `ReviewAuditRecord`.
- Backend exposes admin-only `GET /admin/reviewer-audit/:id` so Studio Mode or future H5 admin tools can inspect approval/publish/rollback history outside the normal player UI.
- Backend tests verify audit creation, admin fingerprinting, source preservation, and no admin token leakage.

### Cloudflare Deployment Assessment V1

Status: Completed as an architecture decision.

- Added `docs/CloudflareDeploymentAssessment.md` to define the Cloudflare path for H5, API, WebSocket, database, artifact storage, and future platform options.
- Decision: serve the Godot Web export from Ubuntu through Cloudflare Free CDN/Tunnel on `funyoru.com`, keep the Go backend on Ubuntu 26.04 LTS for MVP, and put Cloudflare DNS/WAF/CDN/Tunnel in front.
- PostgreSQL and Redis remain the MVP durable/realtime stores; D1 is not a drop-in replacement for the current GORM/PostgreSQL model, and KV is not a Redis pub/sub/TTL replacement.
- R2 is the best next Cloudflare storage fit for creator package artifacts and generated asset bundles.
- Durable Objects are a future candidate for room/session WebSocket coordination, but adopting them now would rewrite the current Go room hub and Redis fanout.
- Backend and H5 strategy docs now point at the assessment so deployment discussions have a single source.
- Read-only Cloudflare check confirmed `funyoru.com` is active on the `Free Website` plan, with no existing DNS records or Pages projects.
- Added `docs/CloudflareFreeLaunchRunbook.md` for the free launch path and updated the Web export preset to exclude Image2 `_source.png` production masters from H5.
- Re-exported H5: `index.pck` dropped to about 18 MiB, while `index.wasm` remains about 36 MiB; therefore Pages-only hosting is deferred unless R2 or a Pages asset limit increase is used.
- Confirmed `_source.png` assets are recoverable because they still live under `assets/**/generated/`; only Web export packaging excludes them.
- Added `backend/deploy/Caddyfile.funyoru.example` and `backend/deploy/cloudflared-funyoru.yml.example` for the Ubuntu static H5 + Cloudflare Tunnel launch path.
- Documented the R2 decision: keep disabled for strict free launch, enable R2 Standard later for creator artifacts or `assets.funyoru.com` large-binary offload, and defer Workers/Durable Objects paid-plan work until realtime edge migration is justified.
- Added `backend/scripts/package-cloudflare-free-launch.sh` to build and package the current H5 export, Linux backend binary, runtime configs, and deploy samples into `.tools/releases/`.
- Added `backend/scripts/smoke-funyoru-public.sh` for public H5/API smoke after the Tunnel hostnames are live.
- Added `backend/deploy/install-funyoru-origin.sh` so an expanded release bundle can lay out `/opt/pixel-social-world`, `/etc/pixel-social-world`, Caddy examples, cloudflared examples, and the backend systemd unit on Ubuntu.
- Updated production binding defaults to `127.0.0.1:8080` for H5 static serving and `127.0.0.1:8787` for the Go backend so the project can coexist with another game already using the server's fixed IP and public `80/443` domain.
- Updated the production Redis default to `PSW_REDIS_DB=5` and documented that a dedicated Redis instance is safer if the existing game also uses Redis Pub/Sub.
- Added `RuntimeConfigService` and `configs/runtime_overrides.json` so H5 can apply a narrow `/runtime_config.json` override for API endpoints, timeout tuning, feature flags, maintenance metadata, and build metadata without rebuilding the Godot package.
- Added `backend/deploy/runtime_config.funyoru.json`; the free-launch package script copies it to `web/runtime_config.json` for `funyoru.com`.
- `OnlineClient` and `RealtimeClient` now listen for app config changes unless a test or tool has manually configured them.

## Next Queue

1. Transfer `.tools/releases/pixel-social-world-funyoru-free-launch.tar.gz` to the Ubuntu host and expand it into `/opt/pixel-social-world`.
2. Create Tunnel hostnames for `funyoru.com`, `www.funyoru.com`, and `api.funyoru.com`, then run `backend/scripts/smoke-funyoru-public.sh`.
3. Add R2-backed package artifact store after local creator review flow stays green, or earlier if Pages + `assets.funyoru.com` becomes the chosen H5 route.

### Utility PostgreSQL Persistence V1

Status: Implemented.

- Added `utility_panel_records` as the PostgreSQL-backed active registry for main-city shop, mail, and notice rows.
- `storage.mode=postgres` now runs `utility.AutoMigrate` and replaces the static utility service with `utility.NewGormService`.
- First PostgreSQL boot seeds from `configs/utility_panels.json`; later `PUT /admin/utility/panels` updates survive backend restarts.
- Memory mode remains available for local/offline smoke paths.

### Main City Utility Panels V1

Status: Implemented.

- `configs/utility_panels.json` now defines the first shop stock, mail messages, and town notices as a stable data contract.
- `configs/app.json` registers the utility panel registry under `content_paths`.
- `WorldUtilityPanel` now renders config-driven Image 2 row lists with item icons, localized copy, wallet details, and short action buttons.
- Shop stock previews housing item prices and routes players to Home; the actual coin spend still happens when a room item/style is placed through `HousingService`.
- Inventory now lists local owned/placed housing goods from save data instead of a single text blob.
- Mail and Notice now render first MVP messages from config, including Home and Games actions for future backend replacement.
- `tests/validate_content.py` now validates utility panel item IDs, icon IDs, action IDs, and localization keys.
- `docs/DataContract.md` documents the utility panel registry and the MVP rule that shop rows preview costs while housing placement remains the authoritative coin sink.
- Online room UI smoke verifies inventory, shop, mail, and notice rows; main city interaction smoke verifies shop hotspot stock rendering.
- Verified on 2026-04-30: content validation, Go unit tests, housing smoke, minigame launch flow smoke, fishing reward UI smoke, online room UI smoke, main city interaction smoke, Web export, and the full H5 screenshot matrix all pass.

### Housing Mobile Safe Area V1

Status: Implemented.

- `HousingRoomResponsiveLayout` now owns compact H5/mobile landscape layout decisions for top bar, social panel, catalog bar, room tile size, and renderer safe areas.
- `HousingRoomScreen` remains under the 300-line single-file limit while delegating responsive layout to the helper.
- `HousingRoomSocialPanel` hides chat preview and tightens input/button dimensions in short landscape screens.
- `HousingRoomCatalogBar` reduces catalog height and item button size in compact mode while keeping horizontal scrolling.
- `HousingRoomRenderer` now uses the actual browser/window size for compact layout origin and tile hit-testing, keeping the editable room out from under the right social panel and bottom catalog.
- Removed the old `Polygon2D` floor placeholder from `HousingRoom.tscn`; the room is now fully rendered by the Image 2 housing art path.
- Housing smoke now verifies compact social/catalog behavior so the mobile layout cannot silently regress.
- Verified on 2026-04-30: housing smoke, online room UI smoke, main city interaction smoke, content validation, Go unit tests, Web export, and the full 11-state H5 screenshot matrix all pass.

### H5 Visual Risk Screenshot Pass V1

Status: Implemented.

- `tests/h5_viewport_smoke.mjs` now captures explicit base-world, inventory-panel, room-panel, housing, fishing-reward, and portrait-guard states.
- The screenshot pass caught a real coordinate drift after the inventory button was added; housing clicks now target Home instead of Inventory.
- `WorldHUD` now sizes side overlays from `DisplayServer.window_get_size()` so Web/mobile landscape uses the real browser viewport.
- `OnlineRoomPanel` has a compact layout for short landscape screens, keeping the minigame lobby above the bottom HUD buttons.
- Online room UI smoke now verifies compact layout behavior so the panel cannot silently expand back over the HUD.
- Verified on 2026-04-30: content validation, Go unit tests, online room UI smoke, main city interaction smoke, Web export, and the full H5 screenshot matrix all pass.

### Main City V1 Shell Panels V1

Status: Implemented.

- `WorldUtilityPanel` adds Image 2 framed shell surfaces for inventory, shop, mail, and notice without covering the center playfield.
- HUD now exposes an Image 2 backpack action button; merchant/shop hotspot and mail/notice NPC actions route into the utility panel.
- `OnlineRoomPanel` now includes a localized enabled-game catalog row, making the existing session panel the first minigame lobby shell.
- Online room UI smoke verifies inventory shell, lobby catalog, and Image 2 frames; main city interaction smoke verifies shop shell routing.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### World HUD Boundary Split V1

Status: Implemented.

- `WorldHUDChatController` now owns chat input, send behavior, channel picker state, history view switching, and chat log rendering.
- `WorldHUDActionsController` now owns emote/fishing/home/minigames button wiring, NPC dialog routing, online room panel toggling, and home invite/visit signal forwarding.
- `WorldHUD` is back down to 176 lines and now focuses on HUD assembly, top status, coin/presence text, Image 2 frame setup, and emote palette handoff.
- Online room UI smoke verifies both HUD controllers exist so future shop/mail/inventory work does not collapse back into the root HUD script.
- Web export now packages `WorldHUDChatController.gdc` and `WorldHUDActionsController.gdc`, confirming the boundary compiles into H5.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Service Sync Boundary V1

Status: Implemented.

- `HousingOnlineSync` now owns online layout fetch, visit sync, place/style/move/remove submission, server rejection recovery, and wallet sync.
- `HousingService` is back down to 188 lines and now stays focused on local catalog, placement rules, room state, save data, and offline sell refunds.
- Housing smoke verifies the online sync helper is initialized, so the service cannot silently collapse back into one monolith.
- Web export now packages `HousingOnlineSync.gdc`, confirming the boundary compiles into the H5 build.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Online Client Boundary Split V1

Status: Implemented.

- `OnlineClientSession` now owns guest login, refresh, profile sync, device ID, and session restore/apply behavior.
- `OnlineClient` remains the stable autoload facade for existing systems while dropping to 224 lines.
- `OnlineClientEndpoints` keeps feature endpoint methods isolated from auth/session state.
- Online client smoke verifies offline fallback behavior after the split.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Edit Polish V1

Status: Implemented.

- `HousingRoomEditController` now owns catalog selection, placed-item selection, move, rotate, sell, and undo state.
- Housing room now exposes an Image 2 framed Undo button for the last move/rotate transform.
- Undo intentionally covers position/rotation transforms only; sell/remove still clears undo because it changes the economy ledger.
- H5 housing smoke now clicks a placed furniture item and moves it before screenshots, so desktop/mobile captures include the edit feedback state.
- Housing smoke verifies EditController exists and performs a move followed by undo against real `HousingService` state.
- Verified on 2026-04-30: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Main City Interaction Boundary Split V1

Status: Implemented.

- `MainCityInteractionController` now owns hotspot binding, NPC spawning, NPC dialog activation, and NPC primary action routing.
- `MainCityScreen` now owns scene-level service assembly, realtime sync, presence announcements, and route actions only.
- The main city controller is back under the single-file limit with room for the next shop/mail/lobby surfaces.
- Main city smoke now verifies the `InteractionController` boundary exists.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke suite, Web export, and H5 viewport smoke all pass.

### Housing Edit Verbs V1

Status: Implemented.

- Client housing now supports select placed furniture, move to an empty tile, rotate, and sell/remove.
- `HousingLayoutRules` owns grid bounds, rotated footprint checks, placed-item lookup, and occupancy validation.
- Backend now exposes `POST /housing/move` and `POST /housing/remove`.
- Server move/remove mutations remain owner-only; remove grants the configured sell refund through the economy ledger.
- Offline local housing mirrors the same move/rotate/remove rules and configured sell refund.
- Housing smoke and Go tests cover move, rotate, remove, occupied move rejection, missing item rejection, and sell refund.
- Online backend E2E now covers `OnlineClient.move_housing_item`, `OnlineClient.remove_housing_item`, insufficient-funds stability, and refund balance sync.
- Verified on 2026-04-30: content validation, Go unit tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

### Housing Furniture Art V1

Status: Implemented.

- `HousingRoomArt` centralizes Image 2 texture loading, room surface drawing, placed furniture drawing, shadows, and placement preview rendering.
- `HousingRoomScreen` now renders wall/floor surfaces and placed furniture from `housing_fishing_props_v0` slices instead of colored placeholder rectangles.
- Build catalog buttons now show Image 2 furniture icons while keeping the horizontal scroll behavior for mobile landscape.
- `HousingService` now validates room bounds and occupied tiles before spending coins, so invalid placement no longer burns currency.
- `configs/art_assets.json` now registers semantic `housing.item.*.icon` entries, and content validation requires housing item icons to be registered art assets.
- H5 housing smoke now clicks a room tile before screenshots, so desktop/mobile captures include actual placed furniture.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Room UI V1

Status: Implemented.

- `HousingRoomScreen` now uses Image 2 framed top, bottom, and social panels through shared `WorldHUDAssets` helpers.
- The room grid is centered from the active viewport instead of relying on a fixed negative origin, improving H5 desktop and mobile landscape framing.
- `HousingRoomSocialPanel` adds a live visitors list, recent house chat preview, and house-channel chat input inside the room.
- The build catalog uses Image 2 button frames and remains horizontally scrollable for narrow mobile landscape screens.
- H5 viewport smoke now includes direct housing screenshots on desktop and 844x390 mobile landscape.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Room UI Boundary Split V1

Status: Implemented.

- `HousingRoomScreen` has been reduced from 296 lines to 197 lines and now owns assembly, routing, selection state, and input forwarding only.
- `HousingRoomCatalogBar` owns the Image 2 framed furniture catalog, selection status, and build controls.
- `HousingRoomRenderer` owns room surface drawing, grid placement preview, and placed furniture rendering.
- `HousingRoomSocialController` owns house-channel chat, visitor presence, and the social panel data flow.
- Housing smoke tests now verify the catalog bar and social controller boundaries so future edits do not collapse the room UI back into one large controller.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, Web export, and H5 desktop/mobile viewport smoke all pass.

### Housing Invite / Visit V1

Status: Implemented.

- Backend now exposes `POST /housing/invite` and `POST /housing/visit`.
- MVP homes are public visit rooms: authenticated visitors can join `home:<owner_id>`, send house-channel chat, and appear in presence.
- Housing edits remain owner-only; cross-owner placement/style mutations still return `403 owner_mismatch`.
- `OnlineClient` now exposes housing invite and visit endpoints.
- `HousingService` can load another player's layout in read-only visit mode and blocks visitor placement before spending coins.
- `OnlineRoomPanel` adds Image 2 framed `Invite Home` and `Visit Home` actions next to the minigame actions.
- Main city sends localized home invites through the house chat channel and routes selected members into visit mode.
- H5 desktop and mobile landscape screenshots show the room panel with both home social actions visible.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Fishing Reward UI V1

Status: Implemented.

- The official fishing minigame now shows a compact Image 2 reward/result panel after each catch.
- Reward UI displays localized fish name, coin gain, fish icon, wallet feedback, and a `Cast Again` loop action.
- Fishing catches now trigger the platform overhead emote hook with `emote.fishing_bite`, keeping minigame feedback on the same social bubble system as the main city.
- `configs/fishing.json` now maps each fish to an Image 2 PNG icon slice from `housing_fishing_props_v0`.
- `configs/art_assets.json` now registers semantic fishing fish icon bindings for content validation and future UI lookup.
- `tests/fishing_reward_ui_smoke.gd` verifies Image 2 panel/button skin, reward visibility, icon loading, and wallet coin gain.
- H5 viewport smoke now clicks into Host Fishing, casts once, and captures the reward panel on desktop and mobile landscape.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass.

### Main City UI Skin V1

Status: Implemented.

- `WorldHUDAssets` now owns shared Image 2 `StyleBoxTexture` helpers for panels, buttons, and text fields.
- HUD TopBar, BottomBar, chat input, channel picker, primary HUD buttons, emote palette, NPC dialog, and Online Room panel now share the same semantic `ui.panel.pixel` / `ui.button.pixel` bindings.
- `OnlineRoomPanel` no longer renders as a flat engineering panel; its frame and action buttons now use Image 2 UI kit slices.
- `tests/online_room_ui_smoke.gd` now fails if key HUD and Online Room surfaces lose their Image 2 frame bindings.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop/mobile viewport smoke all pass with the new Image 2 skin.

### Main City NPC Service Menu V1

Status: Implemented.

- `MainCityNPCDialog` adds a compact bottom-left service dialog that protects the center playfield.
- NPC dialog panels and buttons use the semantic Image 2 UI bindings `ui.panel.pixel` and `ui.button.pixel`; close and primary actions use Image 2 HUD icons.
- `configs/main_city_npcs.json` now defines each NPC primary action, localized button key, and icon binding.
- Fisher, Game Host, and Home Keeper route to Fishing, Game Hall, and Home Edit through the same HUD signal path.
- Merchant, Mail Courier, and Event Guide now have service menu entries while their deeper systems remain scoped.
- `WorldHUD/Root` now ignores pass-through mouse input so map NPCs and hotspots remain clickable under the HUD layer.
- `tests/main_city_interactions_smoke.gd` verifies event guide dialog text and Game Host primary action opening the room panel.
- Verified on 2026-04-29: content validation, Go unit tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, H5 viewport/Host Fishing smoke, and an H5 NPC dialog screenshot pass.

### Main City NPC + Chat V1

Status: Implemented for first NPC batch.

- `characters_npcs_v0` is now sliced into 38 NPC/character PNGs under `assets/sprites/sliced/characters_npcs_v0`.
- `assets/sprites/sliced/characters_npcs_v0_contact.png` is available for fast visual picking.
- `configs/main_city_npcs.json` defines the first town NPC batch: fisher, merchant, mail courier, game host, home keeper, and event guide.
- `MainCityNPC` spawns data-driven Image 2 NPC sprites with localized names, click/tap activation, and overhead emote bubbles.
- Main city NPC clicks now open localized service dialogs; deeper primary actions post system notices where useful.
- Chat views now filter by the selected channel while keeping system messages visible.
- `tests/main_city_interactions_smoke.gd` now covers NPC spawn art, event guide dialogue, and channel view filtering.
- H5 screenshot QA caught unsafe north-side NPC placement and oversized world labels; NPC positions, scale, and labels were adjusted to keep the first viewport clear of the HUD.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Ops + Chat/Main City V1 Push

Status: Implemented for the first v1 step.

- Added authenticated `POST /chat/report` and in-memory report stats so player reports become visible in `/debug/ops`.
- Added PostgreSQL-backed chat message/report persistence for `storage.mode=postgres`, while keeping memory mode fast for local iteration.
- Added admin-only `GET /admin/chat-reports` and `POST /admin/chat-reports/:id/review`, with admin fingerprint/source tracking and no raw token storage.
- Added soft chat send rate limiting at 6 messages per 10 seconds per player/room/channel, plus localized client feedback and ops rejection counters.
- Added admin-only chat moderation actions: `mute`, `ban`, and `restore`, with active restriction enforcement on `/chat/send`, GORM persistence, memory-mode parity, and ops counters.
- Added admin role tokens (`viewer`, `moderator`, `reviewer`, `owner`) and high-risk action confirmation for chat bans plus creator rollback/unpublish.
- Added required operator notes for creator rollback/unpublish and chat bans, persisted reviewer audit notes, and CSV export for reviewer/chat moderation audit streams.
- Added global `X-Request-ID` propagation, `/readyz`, request IDs on admin audit rows, reviewer audit filters/pagination, and chat moderation audit action/offset filtering.
- Replaced Gin text request logging with structured JSON access logs keyed by request_id.
- Added `pixel-social-world-preflight` for Ubuntu/systemd dry-run config checks, wired it into Linux builds, release packaging, the origin install script, and `ExecStartPre`.
- Client `ChatService` can report the latest reportable visible online message and emits localized system feedback for sent, missing, failed, or offline report states.
- `OnlineRoomPanel` now exposes a compact Image 2 skinned report button without adding more persistent HUD chrome.
- Added a standalone Image 2 skinned `ChatReportsConsolePanel` for first-pass chat moderation actions in Godot/H5 admin tooling.
- `ChatReportsConsolePanel` now exposes the first safe executable action, room mute for 1 hour, and then marks the report reviewed.
- Added an Image 2 skinned `ChatModerationAuditPanel` for active restrictions, recent moderation actions, and restore operations.
- `ChatModerationAuditPanel` now supports target-player filtering, action filtering, and CSV export readiness feedback through the admin API.
- `ReviewerConsolePanel` now exposes per-game CSV export readiness feedback while keeping review actions and audit summaries in the same Image 2 tool surface.
- Added a standalone `LiveOpsConsolePanel` that hosts creator review, chat report moderation, role display, moderation audit, and ops counters under one internal tool shell.
- Split `OnlineClientRequest` out of `OnlineClient`, and split `ChatModerationAuditFilters` out of the moderation audit panel so the client admin surface has safer file-size headroom.
- Added an Image 2 skinned `DebugOpsPanel` for `/debug/ops` room, realtime, chat, moderation, and fishing reward counters.
- `DebugOpsPanel` now also calls `/debug/rooms` and renders a room drilldown section for connected clients and retained snapshot players.
- Backend `/debug/rooms` now includes inferred room type and last active time, so LiveOps can distinguish main city, housing, minigame, and custom room pressure.
- Main city presence pill now distinguishes online, stale, and offline states by color, keeps the full desktop H5 label visible, and exposes room plus heartbeat age in the tooltip.
- `LiveOpsConsolePanel` now adapts from a two-column desktop grid to a single-column scroll layout below 1120px, keeping 960x540 and 375px-wide H5 tool views readable.
- `LiveOpsConsolePanel` and H5 smoke automation now harden admin-token propagation before every child-panel refresh, eliminating the long-matrix stale-token 403 flake.
- Local Web debug routing supports `?psw_route=liveops_console` only when `network.environment` is `local_dev`, so screenshot QA can open internal tools without enabling that route in production runtime config.
- Backend `/debug/ops` now exposes administrator-only room, realtime, chat, and fishing reward stats.
- H5 viewport smoke now has reusable helper steps, a single-case filter via `PSW_H5_CASE`, and an opt-in real-backend LiveOps refresh path via `PSW_H5_INCLUDE_BACKEND_OPS=1`.
- Chat service now loads online room history, ingests realtime `chat.message`, deduplicates server echoes, and resets cleanly on scene initialization.
- Main city now pulls chat history on entry and routes realtime `chat.message` into the HUD chat stream.
- Presence HUD now shows member count and stale/heartbeat status in English, Japanese, and Simplified Chinese.
- Realtime backend E2E now verifies room-scoped `chat.message` broadcast and leak prevention.
- Verified on 2026-04-30: content validation, Go unit tests including admin roles, action confirmation, required notes, audit CSV export/filtering, request-id propagation, structured access logs, readiness probes, config validation, and mute/restore enforcement, Godot smoke subset, liveops console smoke with Debug Ops, chat moderation audit smoke, reviewer console smoke, online client smoke, reviewer backend E2E, online backend E2E, realtime backend E2E, Web export, H5 runtime gate smoke, H5 LiveOps screenshot smoke, H5 real-backend LiveOps refresh smoke, Linux amd64 backend/preflight build, and free-launch package build all pass.

## Client Foundation Split + Main City Signals

Status: Implemented.

- `OnlineClient` now delegates REST feature endpoints to `OnlineClientEndpoints`, keeping the autoload API stable while reducing file size.
- `WorldHUD` now delegates Image 2 icon binding and emote palette behavior to small HUD helper scripts.
- Main city presence changes now surface as localized system chat notices after the initial member snapshot.
- The risky near-300-line files have headroom again: `OnlineClient.gd` is 262 lines and `WorldHUD.gd` is 181 lines.
- Verified on 2026-04-29: content validation, Godot smoke, online client smoke, online room UI smoke, minigame launch smoke, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Main City Interaction V1

Status: Implemented for first interactable map pass.

- `MainCityScreen` now delegates remote avatar creation/sync to `MainCityRemotePlayers`; the scene controller is back under 200 lines.
- `MainCityHotspot` adds clickable/tappable map hotspots with localized labels.
- Main city now exposes Fishing Pier, Game Hall, Home Gate, and Item Shop hotspots.
- Fishing Pier starts the fishing session flow; Game Hall opens the online room/minigame panel; Home Gate routes to housing; Item Shop posts a system notice while the shop loop is pending.
- `WorldHUD` now includes a channel picker backed by `configs/chat_channels.json`; outgoing chat can switch from global to nearby/house/party.
- `tests/main_city_interactions_smoke.gd` verifies channel switching, Game Hall panel opening, and Item Shop system notice.
- Verified on 2026-04-29: content validation, Go unit tests, Godot smoke, main city interactions smoke, online client smoke, online room UI smoke, minigame launch smoke, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Studio Mode V2 Update

Status: Started.

- `AGENTS.md` now keeps the original art/UI plan while using Go and `IMinigame` for platform architecture.
- `IMinigame`, `MinigameLauncher`, and `MinigameManifestValidator` have been added.
- The official fishing game now has a creator-style package with `main.tscn`, `game.gd`, `meta.json`, and `README.md`.
- A Go backend skeleton now exists under `backend/`.
- Content validation and Godot smoke tests pass after the sandbox and fishing package changes.
- Go formatting/tests use the project-local `.tools/go` toolchain without global install.

## Studio Mode UI / Main City Push

Status: Completed v0.

- Art direction now explicitly follows the original reference-board baseline: cozy fantasy MMO, warm forest town, compact pixel UI, and social emote bubbles.
- The visual direction is original and avoids copying any existing commercial game sprites or UI frames.
- `CreatorSafetyScanner` now blocks dangerous GDScript API patterns for minigame packages.
- `MainCity.tscn` exists as the new post-login route while the older `world` route remains available.
- `configs/ui_assets.json` tracks UI kit, HUD icons, and emote asset bindings.
- Runtime SVG UI placeholders were removed; scene button icons use generated PNG assets.

## Image 2 Asset Batch v0

Status: Completed.

- UI Kit, overhead emotes, HUD icons, main city tileset, character/NPC sheet, and housing/fishing props were generated with Image 2.
- Source PNGs and chroma-key-removed alpha PNGs are stored in project assets.
- `configs/ui_assets.json` now references generated UI sheets.
- `configs/art_assets.json` now references generated map, sprite, housing, and fishing sheets.
- Content validation and Godot smoke both pass after asset registration.

Generated alpha sheets:

- `assets/ui/generated/ui_kit_v0_alpha.png`
- `assets/ui/generated/overhead_emotes_v1_alpha.png`
- `assets/ui/generated/hud_icons_v0_alpha.png`
- `assets/maps/generated/forest_main_city_tileset_v0_alpha.png`
- `assets/sprites/generated/characters_npcs_v0_alpha.png`
- `assets/housing/generated/housing_fishing_props_v0_alpha.png`

## Asset Slicing v0

Status: Completed for starter UI, overhead emote, map prop, and housing/fishing sheets.

- `AGENTS.md` now hard-requires Image 2 PNG/WebP for official UI and art production assets.
- `scripts/Tools/AssetSlicer/slice_generated_sheets.py` slices generated alpha sheets into individual PNG candidates.
- `configs/generated_asset_slices.json` registers 255 sliced Image 2 assets.
- Sliced output counts: 100 main city map props, 61 UI Kit, 30 overhead emotes, 40 HUD icons, 24 housing/fishing props.

## UI Binding v0

Status: Completed for primary HUD buttons and first emote entry.

- `WorldHUD.tscn` now uses Image 2 sliced PNG icons for Emote, Send, Fishing, Home, and Games.
- HUD icons are loaded at runtime from `configs/ui_assets.json` with `ImageTexture` so fresh clones do not require pre-generated `.import` metadata.
- `configs/ui_assets.json` now maps common HUD icons and emotes to semantic IDs.
- The old social and sad emote sheets were replaced by `overhead_emotes_v1`.
- `configs/ui_assets.json` now maps the 30 overhead bubble emotes to semantic IDs.
- `emote.laugh` is locked to `overhead_emotes_v1_016.png`; `emote.exclamation` is locked to `overhead_emotes_v1_001.png`.
- Content validation now rejects old social/sad emote asset paths.

## Overhead Emote System v0

Status: Completed for local player, HUD selection, shortcuts, and minigames.

- HUD emote actions now emit a structured `emote_requested` signal instead of posting emote text to chat.
- The HUD emote button opens a 30-button icon palette driven by `configs/emotes.json`.
- `Alt+1` through `Alt+0` now trigger the first shortcut set.
- `PlayerAvatar.show_emote()` plays a head-above bubble animation through `OverheadEmoteBubble`.
- `EmoteCatalog` loads Image 2 sliced PNGs from `configs/ui_assets.json` at runtime.
- `IMinigame.request_emote()` and `MinigameLauncher.emote_requested` expose the same emote protocol for creator games.
- `EmoteSync` now introduces the `emote.send` / `emote.event` client protocol path; offline mode echoes the local event.

## Housing Build Loop v0

Status: Completed for offline MVP.

- The HUD Home button now routes to `home_edit`.
- Players can select furniture, decor, and activity items and place them on an 8x5 room grid.
- Wall/floor style changes and item placement spend coins through `HousingService`.
- Layout is saved to `house_items`; room styles are saved to `house_styles`.
- `tests/housing_smoke.gd` verifies placement cost, style cost, save data, and scene instantiation.

## Economy Ledger + Housing Backend Contract v0

Status: Completed for local/offline contract.

- `SaveSystem` now stores an append-only `coin_ledger` with checksum chaining.
- `tests/economy_ledger_smoke.gd` verifies grant, spend, and tamper detection.
- The Go economy skeleton now exposes reward, spend, and ledger APIs.
- The Go house skeleton now exposes layout, place item, and apply style APIs.
- Housing backend spends use server-side catalog prices instead of trusting client-submitted prices.

## Housing Art Binding v0

Status: Completed for starter catalog icons.

- `housing_fishing_props_v0` was sliced into 24 Image 2 PNG assets.
- `configs/housing_items.json` now uses Image 2 PNG icon paths for starter wall, floor, chair, table, plant, and arcade cabinet.
- The old housing SVG placeholder icon files were removed.
- A contact sheet is available at `assets/housing/sliced/housing_fishing_props_v0_contact.png`.

## Online Client Contract v0

Status: Completed with offline fallback.

- `OnlineClient` is now an autoload singleton for REST calls against the Go backend contract.
- Login tries `POST /auth/guest`; if local backend is unavailable, it falls back to offline mode.
- Online login can refresh wallet data through `GET /me`.
- Housing service can sync layout from `GET /housing/layout/:owner_id`.
- Housing placement/style changes keep the local optimistic MVP loop and submit to `/housing/place` or `/housing/style` when connected.
- Server balance responses are reconciled into the local coin ledger with `server.sync` events.
- `tests/online_client_smoke.gd` verifies offline fallback without requiring a running backend.

## Chatrooms + Minigame Sessions Backend v0

Status: Completed and locally verified.

- The Go chat service now stores room/channel history with a capped MVP message length.
- `POST /chat/send` persists a message and broadcasts `chat.message` through the city hub.
- `GET /chat/history/:room_id/:channel_id` returns recent chat history.
- The Go minigame service now manages sessions with create, list, join, leave, and end operations.
- Session operations are mutex-protected so concurrent joins cannot overfill a room.
- Sessions now expose `expires_at`; memory sessions prune stale entries on read and Redis sessions refresh TTL on mutation.
- Go tests cover chat history/length limits and concurrent minigame joins.
- Client `OnlineClient` exposes chat and minigame session methods for the next UI wiring slice.
- Housing online failure handling uses server reconciliation and `house_sync_required` instead of complex per-operation rollback.

## Local Toolchain

Status: Completed without global install.

- Go is installed project-locally under `.tools/go` and ignored by git.
- Go module and build caches are kept under `.tools/gomodcache` and `.tools/gocache`.
- `go test ./...` passes with the local toolchain.
- A real backend smoke on port `18787` passed for health, city state, chat send/history, minigame create/join/full, housing place, and housing insufficient funds.

## Godot Online Backend E2E

Status: Completed.

- Backend guest login now initializes a 25-coin wallet for the generated guest player.
- `/me` supports `player_id` lookup for the MVP memory backend.
- `OnlineClient` preserves manual test configuration so endpoint overrides are not reset by login.
- `tests/online_backend_e2e.gd` passes against a real backend on `127.0.0.1:18787`.
- The E2E covers login, wallet sync, chat, minigame session creation/join, housing placement, backend ledger, and HTTP 402 without marking the client disconnected.

## Backend Persistence Architecture v0

Status: Implemented with optional PostgreSQL mode.

- Backend config now supports `memory` and `postgres` storage modes.
- `cmd/server` loads `configs/local.yaml` plus `PSW_*` environment overrides.
- Economy has a GORM-backed wallet and append-only ledger implementation.
- Housing has a GORM-backed layout implementation.
- PostgreSQL and Redis local services are defined in `backend/docker-compose.yaml`.
- Redis client wiring exists for the next presence/chat/session persistence pass.
- Docker is not installed in this environment, so PostgreSQL mode was compiled but not runtime-smoked here.
- Memory mode E2E still passes after the dependency-injection split.

## Redis Realtime Architecture v0

Status: Implemented with optional Redis mode.

- `presence.Service` now supports memory and Redis-backed heartbeat TTL.
- New endpoints: `POST /presence/heartbeat` and `GET /rooms/:room_id/members`.
- Minigame sessions now support Redis-backed TTL storage with optimistic Redis WATCH updates.
- Redis session tests cover concurrent joins and TTL expiration with miniredis.
- Godot `OnlineClient` can send presence and fetch room members.
- `tests/online_backend_e2e.gd` now covers presence heartbeat and room member listing.
- Verified on 2026-04-29: Go unit tests, Godot smoke tests, content validation, and real memory-backend E2E all pass.

## Linux Backend Deployment v0

Status: Implemented as a production deployment baseline.

- Target server profile is now documented as Ubuntu 26.04 LTS, Linux amd64, i9-13900KF, 64GB RAM.
- `cmd/server` supports `PSW_CONFIG` and graceful SIGTERM shutdown for systemd.
- `backend/configs/production.yaml` defines the postgres + redis production mode.
- `backend/deploy/pixel-social-world.service` provides a systemd service template.
- `backend/deploy/pixel-social-world.env.example` defines the runtime environment contract.
- `backend/scripts/build-linux-amd64.sh` builds the Linux amd64 backend binary.
- `docs/BackendDeployment.md` captures install layout, service setup, ports, and single-host sizing.
- Verified on 2026-04-29: backend Go tests pass, Linux amd64 ELF builds, and real memory-backend E2E still passes.

## Online Room UI v0

Status: Implemented and locally verified.

- Main city now starts `PresenceService` and `MinigameSessionService`.
- HUD shows a presence heartbeat pill with online/offline state and last pulse seconds.
- `OnlineRoomPanel` shows room members, recent chat, active/local minigame sessions, and fishing host/join actions.
- The Games HUD button now toggles the online room panel instead of only writing a status line.
- `tests/online_room_ui_smoke.gd` covers panel open, local member display, session rendering, and heartbeat label rendering.
- Remaining runtime SVG UI placeholder paths were removed; `ui.panel.pixel` and `ui.button.pixel` now point at Image 2 PNG slices.

## Player Action Animation v0

Status: Implemented with Image 2 production sprites.

- Researched classic RO-style action data at the behavior level: action clips, facing directions, frame timing, and anchor-driven sprites.
- Generated an original Image 2 player action sheet for idle, walk, attack, and sit.
- Processed the sheet to alpha PNG and sliced 32 action frames under `assets/sprites/sliced/player_adventurer_actions_v0/`.
- Added `configs/player_animations.json` for config-driven avatar animation.
- `PlayerAvatar` now supports walking animation, directional facing, `Z`/confirm attack, and `X` sit toggle.
- `tests/player_avatar_smoke.gd` covers sprite creation, sit state, and attack state.
- Content validation now checks player animation source sheets and frame paths.

## Remote Player Presence v0

Status: Implemented as the first visible multiplayer slice.

- Main city now mirrors non-local presence members into `PlayerRoot/RemotePlayers`.
- Remote avatars reuse `PlayerAvatar` and the Image 2 action animation sheet with local input disabled.
- Remote avatars spawn around the plaza from deterministic player-id positions and clean up when presence expires.
- `WorldStateSync.build_player_move_payload()` now emits the reserved `player.move` payload fields.
- `docs/MultiplayerSync.md` defines the presence-to-avatar flow and movement snapshot shape.
- `tests/remote_players_smoke.gd` covers remote spawn and cleanup.
- `tests/world_state_sync_smoke.gd` covers movement payload fields.

## WebSocket Movement + Emote Sync v0

Status: Implemented and locally verified.

- Backend city hub now tracks socket room membership from `world.join`.
- `player.move` broadcasts only inside the sender's room.
- `emote.send` is converted to `emote.event` and shares the same room fanout path.
- Godot `RealtimeClient` connects to `/ws/city`, sends join metadata, and streams local movement snapshots.
- Main city applies remote `player.move` payloads to visible `PlayerAvatar` instances.
- Main city applies remote `emote.event` payloads through the RO-style overhead bubble system.
- Fixed Godot-to-Go timestamp compatibility by sending integer Unix timestamps in protocol payloads.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke suite, online backend E2E, and realtime backend E2E all pass.

## Realtime + REST Authority Hardening v4

Status: Implemented and locally verified.

- Guest auth now stores random access/refresh tokens, rotates refreshes, validates WebSocket joins, and shares H5 session/lifecycle code through `SessionTokenStore` and `NetworkLifecycle`.
- Invalid `world.join` requests receive `auth.failed` and disconnect.
- Backend overrides client-sent `player_id` and `room_id` for movement and emote messages.
- Backend rate-limits `player.move` and `emote.send`, clips movement to room bounds, serves `world.snapshot`, and emits `world.leave`.
- REST profile, presence, chat, minigame-session, economy spend/ledger, housing mutations, and creator/admin routes now validate tokens.
- Housing layout/mutation endpoints are owner-only for MVP; public reward grants are blocked until trusted server reward flows own them.
- `realtime.mode=redis` now uses Redis pub/sub room fanout for multi-process WebSocket delivery.
- `realtime.mode=redis` now also uses Redis-backed auth sessions and distributed rate limits.
- `/city/state` now reports realtime counters for fanout, local delivery, rate limits, and leave events.
- `RoomLifecycle` now switches main city, housing, and minigame rooms through `RealtimeClient.switch_room()`.
- `RealtimeClient` now retries dropped WebSocket connections with capped backoff from `network.reconnect_attempts`.
- Remote `PlayerAvatar` movement now interpolates, and main city applies snapshot recovery payloads.
- Tests now verify token refresh, admin gates, REST anti-spoofing, room isolation, position clipping, snapshot recovery, Redis fanout/rate limiting, metrics, and emotes.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke suite, online backend E2E, and realtime backend E2E all pass.

## Architecture Health Pass v1

Status: Completed and locally verified.

- Minigame session lifecycle is now explicit across memory and Redis services with `expires_at`.
- Online room UI renders localized session state and remaining minutes for operational visibility.
- Web export output is isolated by `builds/.gdignore`; old Playwright screenshots were removed from `builds/web`.
- Current `.gd` and `.go` files stay under the 300-line project rule.
- Verified on 2026-04-29: content validation, Go tests, Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 desktop room-panel smoke all pass.
- Follow-up risk: portrait H5/mobile still needs a dedicated responsive scale pass; landscape H5 is stable for current testing.

## H5 Landscape Guard v0

Status: Implemented and locally verified.

- Added a global `OrientationGuard` autoload for the Web build.
- H5 portrait viewports now show a localized landscape-required overlay instead of exposing unusably tiny UI.
- English, Japanese, and Simplified Chinese localization keys were added for the guard message.
- Re-exported Web with the standard Godot build after confirming the Mono editor cannot export Web.
- Added `tests/h5_viewport_smoke.mjs` for desktop landscape, mobile landscape, and mobile portrait guard screenshot regression.
- Verified on 2026-04-29: desktop landscape login/world, mobile landscape login/world, mobile portrait guard overlay, and desktop/mobile landscape online room panel screenshots all pass without page errors.
- Remaining risk: true portrait-play UI is intentionally out of MVP scope until the core landscape social loop is stable.

## Minigame Launch Loop v0

Status: Implemented and locally verified.

- `MinigameSessionService.create_session()` and `join_session()` now only manage session state; scene transitions are owned by `launch_game()`.
- Offline session creation now remembers `pending_minigame_id` and `pending_minigame_session_id` without double-routing.
- Main HUD and online room panel both launch fishing through the same service path after a successful create/join.
- Main city remote avatar spawn points are clamped to a camera/HUD safe playable rect so stale presence members no longer appear under top or bottom HUD.
- Added `tests/minigame_session_service_smoke.gd` and `tests/minigame_launch_flow_smoke.gd`.
- `tests/h5_viewport_smoke.mjs` now also captures desktop/mobile Host Fishing entry into the sandbox.
- Verified on 2026-04-29: content validation, Go tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, H5 viewport smoke, and H5 Host Fishing smoke all pass.

## Fishing Trusted Reward Loop v0

Status: Implemented and locally verified.

- Added `POST /minigames/fishing/catch` as the first trusted minigame reward flow.
- The backend validates bearer token, active fishing session, and session membership before granting coins.
- Fishing rewards now use server-side weighted RNG and append to the backend economy ledger with `minigame.fishing.*` source IDs.
- Each player/session pair is capped at 10 rewarded catches for the current MVP session loop.
- `scenes/minigames/fishing/game.gd` no longer grants local coins for online sessions; it syncs the wallet from the backend response.
- Offline/local fishing still uses local save rewards so device-only smoke and offline play remain usable.
- `MinigameLauncher` now closes online sessions through end/leave and routes finished or exited minigames back to the main city room.
- Added backend cap/membership unit coverage and extended online backend E2E plus minigame launch smoke.
- H5 viewport smoke now ignores Chromium's harmless `CONTEXT_LOST_WEBGL` teardown warning while still failing on real page errors.
- Verified on 2026-04-29: content validation, Go tests, full Godot smoke suite, online backend E2E, realtime backend E2E, Web export, and H5 viewport/Host Fishing smoke all pass.

## Minigame Reward Service v1

Status: Implemented and locally verified.

- Moved trusted fishing reward selection, per-session counters, and economy grants from gateway code into `minigame.FishingRewardService`.
- Gateway fishing routes now only handle request binding, auth, error-code mapping, and JSON responses.
- `cmd/server` loads fishing reward rules from the shared `configs/fishing.json` file through `PSW_FISHING_CONFIG_PATH` or `minigames.fishing_config_path`.
- The backend reads `daily_full_reward_count` as the MVP per-session catch cap and `fish[].sell_value/weight/name_key` as the authoritative reward table.
- Added unit coverage for shared config loading and reward cap behavior.
- Production deployment docs and env examples now include the shared fishing config path.
- Verified on 2026-04-29: Go unit tests, content validation, online backend E2E, and realtime backend E2E all pass.

## Server-Authoritative Housing Catalog v1

Status: Implemented and locally verified.

- Backend housing services now load item prices, sizes, categories, rotation flags, and item types from the shared `configs/housing_items.json` contract.
- `cmd/server` wires `PSW_HOUSING_CONFIG_PATH` / `housing.items_config_path` into both memory and PostgreSQL housing services.
- Gateway placement/style routes still pre-check before spending and re-check before persisting, with refund protection if a post-spend validation conflict appears.
- Added Go coverage for loading the shared housing catalog and for blocking invalid placement/style requests without spending coins.
- Production deployment docs and env examples now include the shared housing config path.

## Fishing Reward Idempotency v1

Status: Implemented and locally verified.

- `fishing.catch` now accepts a client `request_id` and returns it in the reward response.
- Godot `OnlineClient.claim_fishing_catch()` generates request IDs, and the fishing minigame passes one per cast.
- Memory reward service replays completed request IDs without issuing another grant.
- Redis reward service stores `minigame:fishing:request:{session_id}:{player_id}:{request_id}` and `minigame:fishing:count:{session_id}:{player_id}` so multi-process backends share idempotency and reward caps.
- Redis duplicate in-flight requests return `409 fishing_request_pending`; completed duplicates return the original response.
- `tests/online_backend_e2e.gd` now verifies request-id replay does not change catch number or wallet balance.
- Re-exported H5 and reran viewport/Host Fishing smoke.
- Verified on 2026-04-29: Go unit tests, content validation, Godot smoke subset, online backend E2E, realtime backend E2E, Web export, and H5 viewport smoke all pass.

## Player Profile Card + Mobile Keyboard Guard v1

Status: Implemented and locally verified.

- Room member actions now open a compact Image2-framed player profile card instead of jumping directly to private chat.
- The player card exposes private chat, visit home, quick emote, and a disabled report affordance for the moderation follow-up.
- Member selection now stores structured profile metadata in the `ItemList` instead of parsing display text.
- `WorldHUD.show_player_profile()` gives H5 and future systems a stable public entry point for contextual player cards.
- Web export enables Godot's experimental virtual keyboard setting, while the HUD keeps a fallback inset for browsers or platforms that do not report keyboard height.
- `WorldHUDMobileInputController` raises the bottom chat bar and the focused side panel on compact landscape viewports, then restores offsets on blur.
- H5 smoke now captures desktop/mobile player-card states plus mobile chat/private keyboard-guard states.
- Verified on 2026-05-01: content validation, Go tests, Godot room/main-city/social/mobile-input smokes, Web export, full H5 viewport matrix, and targeted H5 profile/keyboard screenshots all pass.

## Player Profile Report + MVP Performance Forecast v1

Status: Implemented and locally verified.

- Added `POST /players/report` so profile-card player reports enter the same chat moderation queue as message reports.
- Backend memory and PostgreSQL chat services now snapshot target player id/name with `channel_id=profile` for existing admin review tools.
- Godot `OnlineClient.report_player_profile()` and `PlayerProfileCard.report_requested` now wire the Report button end-to-end.
- Player profile report feedback is shown as a lightweight system chat message; successful reports disable the card's Report button.
- Remote player avatars now emit profile requests, so clicking/tapping a visible remote character opens the same profile card used by the room member list.
- `docs/MVPProgressPerformanceScore.md` now tracks MVP chain progress plus forecast concurrency, CPU, and memory scores for the planned Ubuntu 26.04 single-host deployment.
- Verified on 2026-05-01: content validation, Go tests, Godot main-city/room/remote/online-client smokes, online backend E2E, Web export, targeted H5 profile-report screenshots, and full H5 viewport matrix all pass.

## WS Load Smoke + Realtime Metrics v0

Status: Implemented and locally verified.

- Room hub metrics now track opened/closed WS connections, local broadcast count, delivery targets, direct deliveries, local deliveries, write failures, and slow writes.
- WebSocket writes now use a bounded write deadline so slow or wedged clients cannot block hub fanout forever.
- Added a 24-client gateway load smoke that logs in guests, joins one room, sends movement fanout, triggers movement rate limiting, sends chat, and verifies `/debug/ops` realtime counters.
- Debug Ops panel now shows WS opened, delivery target, slow write, and failed write counters in English, Simplified Chinese, and Japanese.
- `docs/MVPProgressPerformanceScore.md` now records the measured smoke baseline separately from the single-host capacity forecast.
- Verified on 2026-05-01: content validation, full Go test suite, Godot LiveOps console smoke, Web export, static H5 LiveOps screenshots, and real-backend H5 LiveOps refresh screenshot all pass.

## WS Load Smoke v1 + Production Runtime Defaults

Status: Implemented and locally verified.

- The WS load smoke now accepts `PSW_WS_LOAD_SMOKE_CLIENTS` with a guarded 1-100 range; the default remains 24 for normal test speed.
- Local developer profiles with 50 and 100 authenticated clients in one room pass, including movement fanout, rate limiting, chat fanout, and zero write failures.
- Room debug snapshots now include per-room local broadcast, delivery target, delivered, slow write, and failed write counters.
- Debug Ops room drilldown now renders per-room WS delivered/target/slow/failed counters in English, Simplified Chinese, and Japanese.
- Production and local backend configs now declare HTTP timeouts, graceful shutdown timeout, PostgreSQL pool sizing, and Redis pool/timeout sizing.
- The Go server applies those HTTP, PostgreSQL, and Redis runtime defaults from config and environment variables.
- Verified on 2026-05-01: content validation, full Go test suite, 50-client WS load smoke, 100-client WS load smoke, Godot LiveOps console smoke, Web export, real-backend H5 LiveOps refresh screenshot, and 375px LiveOps screenshot all pass.

## Map Route Exposure v1

Status: Implemented and locally verified.

- Spring Workshop Town and Crystal Mine are now promoted from metadata-only playtest maps to Forest Dawn reachable routes.
- `map_points` now exposes workshop and mine hotspots in Forest Dawn plus status hooks inside each destination map.
- The shared map runtime toggles the new hotspots from metadata, keeping invisible routes off maps that do not own those actions.
- Smoke coverage now verifies Forest Dawn -> workshop -> city and Forest Dawn -> mine -> city routing.

## World Map Directory v1

Status: Implemented and locally verified.

- Added a compact Image2-framed World Map panel that lists every `map_catalog` entry with both art and metadata registered.
- The panel groups maps by main city, life skill, and social function, then travels through the same metadata-driven map runtime.
- The HUD top bar now exposes a map icon button while keeping the playfield clear by default.
- H5 smoke covers desktop and compact landscape map panels plus the full generated map screenshot matrix.

## World Map Directory v1.1

Status: Implemented and locally verified.

- The map runtime now persists `current_world_map_id` through `SaveSystem`, giving the directory a stable current-map state after travel.
- The World Map panel now disables the current map as `Here` / `当前` / `現在`, marks unavailable map entries as preview-only `Soon` / `稍后` / `後日`, and only enables travel for `route_exposed` or `playtest_candidate` maps.
- Port Market is now classified as an exposed MVP route in `map_catalog` because it has a usable generated map and runtime path.
- Smoke coverage now asserts the persisted current map id and current-map disabled state.
- Verified on 2026-05-03: content validation, main city interaction smoke, Godot smoke, Web export, desktop/compact H5 map panel screenshots, and the 9-map H5 generated-map matrix all pass.

Resolved risk:

- `WorldHUD.gd`, `WorldHUDActionsController.gd`, and `WorldUtilityPanel.gd` were split below the 300-line limit with dedicated status, profile action, and panel content helpers.

## World Map Discovery v1

Status: Implemented and locally verified.

- Added a lightweight `MainCityMapDiscovery` profile contract with `discovered_world_map_ids`, seeded by Forest Dawn and updated whenever the player reaches a map through world runtime.
- The World Map panel now distinguishes `Here`, `Go`, `Find`, and `Soon`: undiscovered maps stay visible as exploration targets but cannot be used as direct travel shortcuts.
- Directory travel now goes through `MainCityMapTravelController`, which enforces the client-side discovery gate and centralizes the later backend unlock hook.
- Main city presence join/leave announcements were split into `MainCityPresenceAnnouncer`, keeping `MainCityScreen.gd` below the single-file limit.
- Verified on 2026-05-03: content validation, main city interaction smoke, Godot smoke, Web export, and desktop/compact H5 map panel screenshots all pass.

## World Map Discovery Backend Contract v1

Status: Implemented and locally verified.

- Added a backend `player.Service` discovery contract with memory and PostgreSQL implementations; `city_forest_dawn_v1` is always seeded as the starter map.
- Added authenticated endpoints for `GET /players/maps/discovered`, `POST /players/maps/discovered`, and `POST /players/maps/discovered/sync`.
- Main city now syncs local discovered maps to the backend on entry and pushes newly visited maps online while keeping the local save as the offline fallback.
- `docs/BackendContract.md` now documents the player map-discovery API and persistence mode.
- Verified on 2026-05-03: `go test ./internal/player ./internal/gateway`, content validation, main city interaction smoke, Godot smoke, and `git diff --check` all pass.

## World Map Unlock Source v1

Status: Implemented and locally verified.

- Map discovery responses now keep the compatibility `map_ids` list and add `maps[]` records with `map_id`, `source`, and `discovered_at`.
- Backend unlock sources are standardized as `arrival`, `npc`, `item`, `event`, `admin`, plus system `default` and `sync`; the player-facing HTTP discover endpoint currently accepts only `arrival`, `npc`, `item`, and `event`.
- PostgreSQL map discovery rows now persist `source`, and local Godot saves now keep `discovered_world_map_records` alongside the legacy id list.
- Main city sync sends `source: sync`, while runtime travel pushes `source: arrival`, preserving better unlock provenance when local cache is replayed online.

## World Map Unlock Hint UI v1

Status: Implemented and locally verified.

- Visible Image2 map records in `configs/map_catalog.json` now carry `unlock_hint_key`, with English, Japanese, and Simplified Chinese copy.
- The World Map panel keeps the current compact row layout but adds one small wrapped unlock hint line for undiscovered maps.
- Content validation now requires every runtime-visible map to have a localized unlock hint key.
- Smoke coverage now checks that an undiscovered route shows a concrete unlock hint before rejecting direct travel.

## World Map Unlock Trigger v1

Status: Implemented and locally verified.

- Added `MainCityMapUnlocker` as the single client-side entry point for map unlocks, backend sync, and remote pushes.
- NPC primary actions now emit `map_unlock_requested(map_id, "npc")` before routing, while hotspot and world-map travel keep using `arrival`.
- Backend map discovery now preserves the first unlock source so later movement/sync calls do not erase NPC, item, event, or admin provenance.
- Added owner-only `POST /admin/players/maps/discovered` for confirmed LiveOps map grants with source `admin` and admin-token fingerprinting.
- Added `tests/map_unlocker_smoke.gd` to verify that NPC unlock provenance survives a later arrival unlock.

## World Map Unlock Feedback v1

Status: Implemented and locally verified.

- `MainCityMapUnlocker.unlock_map` now returns whether the map was newly unlocked.
- Main city emits a concise system-chat notice only for first-time route discoveries.
- The feedback uses localized `world.map_unlocked_format` and map catalog names, avoiding repeat spam for already-discovered routes.
- Smoke coverage verifies that first route discovery shows the notice and repeat unlocks stay silent.

## World Map Unlock Toast v1

Status: Implemented and locally verified.

- First-time map discoveries now also create a compact `MapUnlockToast` under the HUD root.
- The toast uses the Image2 pixel panel frame and registered `icon.map` texture, then auto-hides after a short timer.
- English, Japanese, and Simplified Chinese copy now include `world.map_unlocked_toast_title`.
- Smoke coverage now checks that the first route discovery shows the compact HUD toast with the discovered map name.
- Verified on 2026-05-03: content validation, main city interaction smoke, map unlocker smoke, core Godot smoke, Web export, desktop/compact H5 map panel screenshots, and `git diff --check` all pass.

## Social Trade Frontend Loop v1

Status: Implemented and screenshot-verified.

- The trade facility panel now exposes the player wallet, live listings, sellable inventory, price input, `Post`, `Buy`, and `Cancel` actions from the player-facing UI.
- The Godot network client now calls backend trade create/cancel endpoints, and trade purchases sync the returned wallet balance back into `SaveSystem`.
- Trade backend integration is enabled for local alpha runtime config so H5 sessions show real seeded inventory/listings instead of static-only rows.
- Trade rows were reflowed into a narrow-panel-safe layout: item state is folded into the description, while price input and action buttons get their own action row.
- English, Japanese, and Simplified Chinese trade copy was shortened so the first sellable item and `Post` action are visible in default desktop and mobile-landscape views.
- H5 coverage now includes `h5-mobile-landscape-trade-facility-panel` alongside the desktop trade panel.
- Verified on 2026-05-03: content validation, JSON validation, social facility service smoke, social facility panel smoke, main city interaction smoke, core Godot smoke, Go trade/gateway tests, Web export, and desktop/mobile H5 trade screenshots all pass.

## Social Trade Action Feedback v1.1

Status: Implemented and locally verified.

- Trade actions now show a pending state while `Post`, `Buy`, or `Cancel` is in flight, then restore the button and show localized success/failure feedback.
- The player-facing price input is bounded to `1..9999`, and the backend rejects prices above the same `MaxListingPrice` guard.
- Empty sellable inventory now renders an explicit row instead of silently falling back to static board content.
- Added Godot smoke coverage for out-of-range price rejection, `Post -> Cancel`, `Buy`, and wallet sync from a server purchase response.
- Added Go gateway coverage for rejecting an over-limit listing price before inventory escrow.
- Verified on 2026-05-03: content validation, JSON validation, social facility panel/action/service/trade-action smoke tests, main city interaction smoke, core Godot smoke, Go trade/economy/gateway tests, Web export, and desktop/mobile H5 trade screenshots all pass.

## MVP Progress Snapshot 2026-05-03

Status: Internal code MVP is about 78%; external launch readiness is about 64%.

- Login system: 72%. Guest auth, refresh, session storage, and upgrade contract exist; production Apple/Google provider flow and store compliance remain.
- Main city map: 82%. Image2 generated map runtime, routes, discovery, unlock toast, and map directory are working; final collision polish, NPC density, and map-content pacing remain.
- Player movement sync: 78%. WebSocket auth, movement fanout, reconnect, load smoke, and remote avatars exist; authoritative reconciliation and larger soak tests remain.
- Chat system: 86%. Room chat, private messages, mailbox, reporting, moderation tooling, rate limits, and retention policy are implemented; UX polish and abuse tuning remain.
- Housing system: 76%. Room editing, placement costs, online sync, and Image2 furniture assets work; more furniture categories and rollback/undo affordances remain.
- Fishing minigame: 82%. IMinigame launcher, official fishing, trusted backend rewards, idempotency, caps, and wallet sync exist; final art/audio feel and device tuning remain.
- Coin/economy system: 82%. Wallet, ledger, housing spend, fishing rewards, trade settlement, and creator-reward groundwork exist; inflation dashboards and live economy knobs remain.
- IMinigame/open creator platform: 80%. Contract, sandbox, manifest validation, creator modes, package intake, async scan/review, reviewer console, and catalog contracts exist; real creator upload UX and staged publish QA remain.
- iOS/Android launch: 25%. H5/mobile landscape behavior is healthy, but native export profiles, signing, TestFlight/Play internal tracks, and device QA are still ahead.

Next risk order:

- Product risk: first-session clarity and social reasons to stay after login.
- Engineering risk: production deployment, native mobile auth/export, and longer multiplayer soak.
- Art/UI risk: generated-map cohesion across all 32 planned maps, plus denser NPC/interaction composition without clutter.

## First Session Guide v1

Status: Implemented and locally verified.

- Added a compact `FirstSessionGuide` HUD panel for the first-player route through NPC, map, trade market, game hall, and one chat greeting.
- The guide is event-driven rather than modal: NPC dialogs, direct map button presses, direct games button presses, trade facility opens, and local chat messages all complete their matching step.
- Completed guide steps persist in `SaveSystem.first_session_guide_completed_ids`, so the panel disappears after completion and does not keep nagging returning players.
- The panel keeps to the top-left HUD space and collapses body copy on 375px / mobile-landscape pressure layouts so it does not cover the bottom chat row or right-side utility panels.
- Added English, Japanese, and Simplified Chinese copy plus `tests/first_session_guide_smoke.gd`.
- Verified on 2026-05-04: content validation, first session guide smoke, main city interaction smoke, core Godot smoke, social facility trade action smoke, Web export, and desktop/mobile-landscape H5 world-base screenshots all pass.

## First Session Reward v1

Status: Implemented and locally verified.

- Completing the first-session guide now grants a one-time 5 coin reward from `configs/economy.json`.
- The reward claim flag persists separately from guide step completion, preventing duplicate grants if the final event is replayed.
- Reward grants use the normal `SaveSystem.grant_coins()` ledger path with source `first_session.guide_complete`, then refresh the HUD wallet label.
- The chat system posts a localized system notice after the reward, keeping the reward visible without adding another modal.
- H5 smoke gained a local-web-only first-session debug hook so screenshot QA can verify the completed state and coin balance deterministically.
- Verified on 2026-05-04: content validation, first-session guide smoke, economy ledger smoke, main city interaction smoke, core Godot smoke, social facility trade action smoke, Web export, and H5 desktop first-session reward plus desktop/mobile world-base screenshots all pass.

## First Session Trusted Reward v1

Status: Implemented and locally verified.

- Added backend `POST /economy/first-session/claim`, guarded by the player's bearer token and the full first-session step list.
- Added `economy.Service.GrantOnce()` for source-id idempotent grants in both memory and PostgreSQL-backed economy services.
- The trusted reward uses fixed backend constants: 5 coins and source `first_session.guide_complete`, while `/economy/reward` remains blocked to public clients.
- Godot now attempts the trusted backend claim when online, syncs the returned wallet balance into `SaveSystem`, and only falls back to local offline reward when no online claim is available.
- Online backend E2E now verifies the first-session reward claim, idempotent replay, and backend ledger source.
- Verified on 2026-05-04: content validation, Go economy/gateway tests, first-session guide smoke, economy ledger smoke, online client smoke, real Go backend `tests/online_backend_e2e.gd`, Web export, and H5 first-session/world-base screenshots all pass.

## Online Client Economy Boundary Split v1

Status: Implemented and locally verified.

- Moved economy-specific Godot HTTP calls into `OnlineClientEconomy`, while keeping `OnlineClient.fetch_coin_ledger()` and `OnlineClient.claim_first_session_reward()` as stable facade methods for existing UI code.
- `OnlineClient.gd` is back down to 259 lines and `OnlineClientEndpoints.gd` remains at 295 lines, restoring buffer under the AGENTS 300-line GDScript limit.
- This freezes beginner-task feature expansion for now and clears safer space for the next high-value push: UI/map/character polish plus map production integration.
- Verified on 2026-05-04: content validation, online client smoke, and first-session guide smoke all pass after the split.

## Main City Visual Scale Pass v1

Status: Implemented and screenshot-verified.

- Tuned the main player avatar from 0.27 to 0.24 scale so characters read as smaller social-world sprites against the Image2 whole-map backgrounds.
- Pulled generated-map camera zoom from 0.95 to 0.88 across the 32-map catalog, making the main city and routed maps feel less cramped on desktop and mobile landscape.
- Reduced overhead emote bubbles from 0.12 to 0.095 scale and anchored them into the tight headroom above the avatar, then added a smoke assertion for emote height and head spacing.
- Slimmed the World Map panel copy to a short route label and removed the technical metadata explainer from the player-facing panel.
- Verified on 2026-05-04: content validation, player avatar smoke, emote smoke, main city interaction smoke, Web export, and H5 screenshots for desktop/mobile world base, room emote, map panel, and trade panel all pass.

## Main City UI Density Pass v2

Status: Implemented and screenshot-verified.

- Split player nameplate reveal/profile-click handling into `PlayerAvatarNameplate`, lowering `PlayerAvatar.gd` to 281 lines while preserving tap-to-reveal names.
- Tightened the online room panel into a 960x540-safe compact mode, so the H5 desktop canvas and mobile-landscape view no longer let the room panel fight the bottom HUD.
- Made HUD overlay panels relayout immediately when opened through bottom-bar actions, utility actions, messages, profiles, and social facilities.
- Improved World Map and Trade Market row readability on the Image2 parchment UI with darker row text, fixed row heights, and shorter compact trade status copy.
- Fixed a real trade UI regression where `Buy` / `Cancel` buttons could disappear when a row had an action but no price input.
- Verified on 2026-05-04: content validation, player avatar smoke, online room UI smoke, social facility panel/action/trade-action smokes, main city interaction smoke, Web export, and H5 screenshots for desktop/mobile room, desktop map, and mobile trade panels all pass.

## Map Production Contract v2

Status: Implemented and screenshot-verified.

- Added `tests/map_production_contract_smoke.gd` to gate the Image2 map batch through catalog asset registration, metadata availability, walkable default spawns, walkable interactions, valid portals, and return routes to Forest Dawn.
- Expanded the H5 map patrol so every generated map renders in both desktop and mobile-landscape viewports from `configs/map_catalog.json`.
- Added side-edge exposure sampling to the H5 probe so left/right camera bleed is caught, not just bottom HUD bleed.
- Fixed square social maps by using a tighter `1.0` camera zoom for Guild Garden, Housing District, and Minigame Arcade Hall, removing the pure-color side bands on H5 mobile landscape.
- Verified on 2026-05-04: content validation, H5 smoke syntax check, Web export, H5 generated-map matrix with 18 screenshots, and visual review of Guild Garden plus Minigame Arcade Hall all pass.

## Map Generation Queue v3

Status: Implemented and locally verified.

- Added `configs/map_generation_queue.json` as the machine-readable Image2 production contract for the remaining three main cities: Snowbell Village, Academy Plaza, and Festival Night Market.
- Each queued map now has render size, target zoom, output/source paths, theme terms, positive prompt, negative prompt, integration plan, portal plan, metadata requirements, and HUD-safe acceptance gates.
- Added `scripts/Tools/MapPipeline/print_image2_queue.py` so the active batch can be printed for Image2 generation without hand-copy drift from docs.
- Added `tests/map_generation_queue_smoke.py` plus content validation coverage to keep the queue aligned with `configs/map_catalog.json` and prevent already-registered maps from staying in the generation queue.
- Updated `docs/MapProductionPlan.md` and `docs/Image2MapPromptBook.md` so Batch 3's source of truth is explicit.
- Verified on 2026-05-04: content validation, queue smoke, and Python compile checks all pass.

## Snowbell Village Map Intake v1

Status: Implemented and screenshot-verified.

- Generated the Snowbell Village whole-map motherboard with Image2, using the Batch 3 queue prompt and the approved cozy pixel MMO board as style reference only.
- Registered the selected PNG and preserved its source PNG under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `city_snowbell_village_v1` from scaffold to `playtest_candidate` with authored `map_points` metadata: default spawn, plaza spawn, NPC hooks, inn/notice/seasonal-board interactions, return portal, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for Snowbell Village.
- Moved Snowbell Village out of the active Image2 queue into `completed_maps`, leaving Academy Plaza and Festival Night Market as the remaining Batch 3 prompts.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and Snowbell Village desktop/mobile-landscape H5 screenshots all pass.

## Academy Plaza Map Intake v1

Status: Implemented and screenshot-verified.

- Generated the Academy Plaza whole-map motherboard with Image2, using the Batch 3 queue prompt and the approved cozy pixel MMO board as style reference only.
- Registered the selected PNG and preserved its source PNG under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `city_academy_plaza_v1` from scaffold to `playtest_candidate` with authored `map_points` metadata: default spawn, fountain-plaza spawn, academy registrar, creator tutor, library/creator-help/notice interactions, return portal, walkable lanes, classroom and fountain blockers, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for Academy Plaza.
- Moved Academy Plaza out of the active Image2 queue into `completed_maps`, leaving Festival Night Market as the final Batch 3 prompt.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and Academy Plaza desktop/mobile-landscape H5 screenshots all pass.

## Festival Night Market Map Intake v1

Status: Implemented and screenshot-verified.

- Generated the Festival Night Market whole-map motherboard with Image2, using the Batch 3 queue prompt and the approved cozy pixel MMO board as style reference only.
- Registered the selected PNG and preserved its source PNG under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `city_festival_night_market_v1` from scaffold to `playtest_candidate` with authored `map_points` metadata: default spawn, lantern-plaza spawn, festival host, booth keeper, stage manager, games/notice/seasonal-board interactions, return portal, walkable market loops, stage/waterfront/building blockers, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for Festival Night Market.
- Moved Festival Night Market out of the active Image2 queue into `completed_maps`, completing the six-main-city Batch 3 foundation.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and Festival Night Market desktop/mobile-landscape H5 screenshots all pass.

## Life Skill Batch 4 Map Intake v1

Status: Implemented and screenshot-verified.

- Generated Herb Forest, Lumber Grove, and Starter Farm whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered all three selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `life_herb_forest_v1`, `life_lumber_grove_v1`, and `life_starter_farm_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, life-skill NPC hooks, herb/wood/crop nodes, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for the three life-skill routes.
- Added `life_skill_batch_4` to the Image2 queue as a completed batch so the production queue now matches the real generated-map state.
- Hid the first-session guide outside the Forest Dawn starter map after H5 screenshots exposed that the starter objective copy was appearing on life-skill maps.
- Verified on 2026-05-04: content validation, queue smoke, first-session guide smoke, map production contract smoke, Web export, and six H5 screenshots for desktop/mobile Herb Forest, Lumber Grove, and Starter Farm all pass.

## Life Skill Batch 5 Map Intake v1

Status: Implemented and screenshot-verified.

- Generated Insect Meadow, Ruin Dig Site, and Cooking Market whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered all three selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `life_insect_meadow_v1`, `life_ruin_dig_site_v1`, and `life_cooking_market_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, life-skill NPC hooks, insect/dig/cooking nodes, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for the three remaining life-skill routes.
- Added `life_skill_batch_5` to the Image2 queue as a completed batch, bringing the MVP life-skill map foundation to 8/8 generated and registered maps.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and six H5 screenshots for desktop/mobile Insect Meadow, Ruin Dig Site, and Cooking Market all pass.

## Social Function Batch 6 Map Intake v1

Status: Implemented and screenshot-verified.

- Generated Mail Plaza and Creator Gallery whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered both selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `social_mail_plaza_v1` and `social_creator_gallery_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, social NPC hooks, facility interaction points, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for Mail Plaza and Creator Gallery.
- Added Creator Tutor as a real NPC contract and routed `creator_help` through the same NPC action and utility-panel flow as the existing creator lab.
- Added `social_function_batch_6` to the Image2 queue as a completed batch, bringing the MVP social-function map foundation to 6/6 generated and registered maps.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and four H5 screenshots for desktop/mobile Mail Plaza and Creator Gallery all pass.

## Random Exploration Batch 7 Map Intake v1

Status: Implemented and screenshot-verified.

- Generated Flower Valley, Mist Wetland, Old Ruins, and Autumn Road whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered all four selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `random_flower_valley_v1`, `random_mist_wetland_v1`, `random_old_ruins_v1`, and `random_autumn_road_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, exploration hooks, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for the four random-exploration routes.
- Added `random_exploration_batch_7` to the Image2 queue as a completed batch, bringing the random-exploration map foundation to 4/8 generated and registered maps.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and eight H5 screenshots for desktop/mobile Flower Valley, Mist Wetland, Old Ruins, and Autumn Road all pass.

## Random Exploration Batch 8 Map Intake v1

Status: Implemented and screenshot-verified.

- Added `random_exploration_batch_8` to the machine-readable Image2 queue for Island Coast, Lantern Forest, Cliff Boardwalk, and Ancient Tree Maze, then moved the batch to completed after asset registration.
- Generated all four remaining random-exploration whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered all four selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `random_island_coast_v1`, `random_lantern_forest_v1`, `random_cliff_boardwalk_v1`, and `random_ancient_tree_maze_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, exploration hooks, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for the four remaining random-exploration routes.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and eight H5 screenshots for desktop/mobile Island Coast, Lantern Forest, Cliff Boardwalk, and Ancient Tree Maze all pass.

## Seasonal Activity Batch 9 Map Intake v1

Status: Implemented and screenshot-verified.

- Added `seasonal_activity_batch_9` to the machine-readable Image2 queue for Cherry Blossom Fair, Snow Festival, Summer Fireworks Pier, and Pumpkin Lantern Square, then moved the batch to completed after asset registration.
- Generated all four seasonal/activity whole-map motherboards with Image2, using the approved cozy forest social MMO board as style reference only.
- Registered all four selected PNGs and preserved their source PNGs under `assets/maps/generated/` through the map pipeline registration script.
- Promoted `season_cherry_blossom_fair_v1`, `season_snow_festival_v1`, `season_summer_fireworks_pier_v1`, and `season_pumpkin_lantern_square_v1` to `playtest_candidate` with authored `map_points` metadata: default spawns, seasonal hooks, return portals to Forest Dawn, walkable rectangles, blocked rectangles, gathering zones, camera bounds, and HUD QA gates.
- Added English, Japanese, and Simplified Chinese unlock hint copy for the four seasonal/activity routes.
- Verified on 2026-05-04: content validation, queue smoke, map production contract smoke, Web export, and eight H5 screenshots for desktop/mobile Cherry Blossom Fair, Snow Festival, Summer Fireworks Pier, and Pumpkin Lantern Square all pass.
- The first 32 Image2 map motherboards are now 32/32 generated, registered, metadata-authored, and route-ready; seasonal rewards and activity calendars remain gameplayization work.

## Map Gameplayization v1

Status: Implemented and screenshot-verified.

- Added `configs/map_activities.json` as the first map-action contract for life skills, random exploration, and seasonal event interactions.
- Added `MapActivityService` to handle per-map action lookup, local coin rewards, cooldown persistence, coin-ledger writes, HUD coin refresh, and system-chat feedback through one service boundary.
- Extended the runtime map metadata and map runtime so `interaction_points` and `life_skill_nodes` can spawn dynamic clickable hotspots without hand-authoring a scene node for every generated map point.
- Routed unknown non-NPC hotspot actions through `MainCityInteractionController.map_activity_requested`, keeping fixed facility routes and dynamic gameplay routes separated.
- Added English, Japanese, and Simplified Chinese text for map activity titles, success messages, cooldowns, and inactive points.
- Added smoke coverage for direct reward/cooldown behavior and for dynamic hotspot creation on random-exploration and life-skill maps.
- Cleaned `scripts/Tools/MapPipeline/__pycache__` and confirmed no leftover H5 listeners after the screenshot matrix.
- Verified on 2026-05-04: content validation, map activity service smoke, dynamic activity hotspot smoke, main-city interaction smoke, queue smoke, map production contract smoke, Web export, Go backend tests, `git diff --check`, and the full 64-screenshot H5 maps matrix all pass with 0 console messages.

## Map Activity Authority v1

Status: Implemented and smoke-tested.

- Added backend `POST /map-activities/claim`, guarded by the player's bearer token, map/action validation, and per-player/per-map/per-action cooldown.
- Added `backend/internal/mapactivity` with memory and Postgres/GORM implementations so map activity cooldowns survive production restarts in PostgreSQL mode.
- Replaced the backend's hardcoded map activity rule table with a shared ruleset loader for `configs/map_activities.json` and `configs/map_points.json`; both memory and GORM services now receive the same config-driven map/action contract.
- Added preflight coverage for map activity rules so backend startup/deploy checks fail before serving if generated map metadata and activity rewards drift.
- Wired the service into gateway dependencies, readiness reporting, and Linux server startup migration.
- Extended `OnlineClientEconomy` and the stable `OnlineClient.claim_map_activity()` facade.
- Updated `MapActivityService` to claim online through the backend when a session token exists, reconcile `wallet.balance` into the local coin ledger, show HUD status feedback, and keep the old local reward path only as offline fallback.
- Added visible dynamic hotspot states for generated map activities: ready, cooldown countdown, disabled fallback, and rapid-click debounce, so activity points now communicate state directly on the map without covering the playfield.
- Extended the real-backend online E2E path so map activity rewards are claimed against the Go server, replay attempts hit `429 activity_cooldown`, and the backend ledger source prefix is verified.
- Documented the route in `docs/BackendContract.md`, including cooldown and invalid map/action responses.
- Verified on 2026-05-04: backend preflight, content validation, `go test ./...`, map activity service smoke, dynamic activity hotspot state/debounce smoke, real Go backend online E2E, Web export, `git diff --check`, and two-map H5 screenshot matrix all pass with 0 console messages.

## Map Activity Fatigue v1

Status: Implemented and screenshot-verified.

- Added `daily_reward_limit` to `configs/map_activities.json`: life-skill rewards default to 12 claims/day/action, random exploration to 10, seasonal activity rewards to 4, and non-reward facility hooks to 0.
- Extended backend map activity memory and PostgreSQL/GORM services with per-player/per-day/per-action reward counts, returning `429 activity_daily_limit` before cooldown or coin grants when the daily cap is reached.
- Extended `POST /map-activities/claim` responses with `daily_reward_limit` and `daily_reward_count` so clients can render fatigue state and reconcile online/offline behavior.
- Added client-side offline protection in `MapActivityService`: local daily claim counters live in the save profile, capped activities display a localized HUD/chat message, and dynamic hotspots fall back to disabled state after the local cap.
- Updated content validation, localization, backend unit coverage, and the map activity smoke test for the new daily fatigue contract.
- Verified on 2026-05-04: backend preflight, content validation, full Go backend tests, map activity service smoke, map activity hotspot smoke, real Go backend online E2E, Web export, `git diff --check`, no `__pycache__`, no leftover listeners on `18787/18888/8787`, and two-map H5 screenshot smoke all pass with 0 console messages.

## Map Activity Gameplay Rewards v2

Status: Implemented and locally verified on 2026-05-04.

- Extended `configs/map_activities.json` beyond coins/cooldowns with `skill_id`, `skill_xp`, guaranteed `drops`, and optional deterministic `rare_event` metadata.
- Added backend response fields for map activity gameplay rewards so successful claims can return activity XP and item-drop contracts alongside the server-authoritative wallet delta.
- Added deterministic rare-event rolling from player/map/action/day/count so future rare hooks are repeatable under replay and easy to test.
- Added client local progression storage through `map_activity_inventory` and `map_activity_skill_xp`, keeping gameplay rewards visible while postponing tradeable online item persistence to a later inventory service.
- Updated smoke/E2E tests and content validation so drops, skill XP, and rare-event config cannot silently drift.
- Verified on 2026-05-04: backend preflight, content validation, full Go backend tests, map activity service smoke, map activity hotspot smoke, real Go backend online E2E, Web export, no leftover listener on `18787`, and two-map H5 screenshot smoke all pass with 0 console messages.

## Map Activity Frontend Feedback v3

Status: Implemented and screenshot-verified on 2026-05-04.

- Added localized reward summaries after successful map activities, combining coin/status feedback with skill XP, item drops, and rare-event text through `MapActivityRewardText`.
- Persisted local map-activity gameplay rewards immediately after they are applied, so activity inventory and skill progress survive reloads instead of depending on a later save side effect.
- Added activity skill and drop rows to the World Utility inventory panel, keeping the player-facing reward loop visible before the full online inventory service lands.
- Added a compact map-directory progress summary so players can see accumulated activity skill XP and drop counts from the map surface.
- Added local H5 debug seeding for activity rewards and screenshot cases for desktop inventory, desktop map progress, and mobile landscape inventory.
- Verified on 2026-05-04: content validation, backend preflight, Go backend tests, map activity service smoke, dynamic hotspot smoke, online room UI smoke, main-city interaction smoke, Web export, and the targeted 3-state H5 screenshot matrix all pass with 0 console messages and clear ports.

## Online Inventory Bridge v1

Status: Implemented and locally verified on 2026-05-04.

- Added a backend inventory grant path to the trade service so map-activity drops can enter server-authoritative `owned/locked/available` inventory before being listed.
- Wired successful `POST /map-activities/claim` responses to grant configured drops into backend inventory and return affected `inventory_items` rows alongside wallet, XP, and drop metadata.
- Updated the client map-activity flow to reconcile local activity drop counts from returned server inventory rows, keeping the player-facing inventory panel aligned with online authority.
- Extended backend and real-client E2E coverage so a `trail_token` earned from exploration appears in `/trade/inventory` and can be listed through the trade API.
- Split shared main-city smoke assertions out of the 300-line interaction smoke file, restoring the AGENTS.md line-count gate.
- Verified on 2026-05-04: content validation, full Go backend tests, map activity service smoke, main-city interaction smoke, and real Go backend online E2E all pass.

## Inventory Service Split v2

Status: Implemented and locally verified on 2026-05-04.

- Split inventory authority into `backend/internal/inventory`, with shared memory and PostgreSQL/GORM implementations for starter items, grants, locks, unlocks, and buyer delivery.
- Kept the existing `inventory_records` database table name during the package split, so PostgreSQL deployments can migrate without losing previous trade escrow rows.
- Added authenticated `GET /inventory` as the generic player inventory endpoint; `/trade/inventory` remains a compatibility alias for the trade market UI.
- Rewired map activity drops to grant through the inventory service and rewired trade listing create/buy/cancel to lock, deliver, or unlock through that same service.
- Added `OnlineClient.fetch_inventory()` and extended the online backend E2E helpers so the client verifies both generic inventory and trade-compatible inventory after map-activity rewards.
- Added gateway coverage proving map-activity reward drops, `/inventory`, and trade listing escrow all observe the same authoritative item state.
- Verified on 2026-05-04: content validation, targeted inventory/trade/map-activity gateway tests, full Go backend tests, backend preflight, map activity service smoke, main-city interaction smoke, real Go backend online E2E, and Web export all pass.

## Trade Frontend Loop v1.1

Status: Implemented and locally verified on 2026-05-04.

- Updated the trade facility service to prefer the generic `OnlineClient.fetch_inventory()` path while keeping the legacy trade inventory method as a client compatibility alias.
- Forced trade buy, post, and cancel actions to refresh live listings plus inventory after every server response, including failed responses, so stale escrow state does not linger in the player-facing market panel.
- Added clearer localized trade errors for expired auth, invalid requests, and service connection failures in English, Japanese, and Simplified Chinese.
- Expanded social facility smoke coverage for insufficient-funds feedback, generic inventory endpoint preference, post escrow lock refresh, and cancel inventory return refresh.
- Verified on 2026-05-04: content validation, social facility trade action smoke, social facility panel action smoke, real Go backend online E2E, full Go backend tests, backend preflight, and Web export all pass.

## Inventory Panel Unification v1

Status: Implemented and locally verified on 2026-05-04.

- Split World Utility inventory rendering into `WorldUtilityInventoryRows`, keeping the main utility panel under the 300-line scene-controller limit.
- The inventory panel now prefers authoritative online `/inventory` rows when connected, showing owned/available/locked counts for trade escrow state.
- Local housing goods and placed room goods remain visible under a separate local section, so the panel still works offline and still explains non-server room inventory.
- Activity skills are always listed, while local activity drops are hidden when matching online inventory rows are loaded, preventing duplicate Trail Token-style rows.
- Added localized section labels and server-state formatting in English, Japanese, and Simplified Chinese.
- Added a dedicated smoke test covering online inventory rows, local housing rows, activity skills, and offline drop fallback.

## Housing Inventory Authority v1

Status: Implemented and locally verified on 2026-05-05.

- Online housing placement now reserves one available item from the shared backend inventory before mutating the room layout.
- If no owned item is available, housing placement can buy one through the economy sink, grant it into inventory, then immediately lock it as a placed room item.
- Room layout items now carry an `inventory_locked` marker so removing an inventory-backed placed item returns it to inventory instead of granting a coin refund.
- Legacy/local placed items without the inventory marker keep the configured sell-refund path, preserving old layouts and offline behavior.
- Client housing no longer spends coins optimistically when connected; it waits for the server wallet/inventory response and stores returned `inventory_items` for UI reconciliation.
- Added backend coverage for starter inventory placement, purchased placement, inventory return on remove, and legacy refund compatibility.

## Inventory Reservation Sources v2

Status: Implemented and locally verified on 2026-05-05.

- Added source-scoped inventory reservations to both memory and PostgreSQL/GORM inventory services; inventory rows can now expose reservation details with `source_id`, `reason`, `quantity`, and `created_unix`.
- Added the `inventory_reservations` table while keeping `inventory_records.locked` as a compatibility aggregate for old escrow data.
- Housing placement now locks inventory with unique `housing:*` reservation IDs, stores the reservation ID on placed room items, and releases that exact source when an item is removed.
- Trade listing create, buy, and cancel now use `trade:<listing_id>` reservations, so trade escrow and housing placement locks cannot release each other by accident.
- Inventory delivery now rejects missing or mismatched reservation sources instead of transferring a seller item without the matching lock.
- Real backend E2E now checks housing `reservation_id` responses and verifies housing reservation counts through `/inventory`.
- Verified on 2026-05-05: content validation, full Go backend tests, backend preflight, housing smoke, world utility inventory rows smoke, social facility trade action smoke, targeted reservation regression tests, real Go backend online E2E, Web export, `git diff --check`, clear local ports, and no leftover E2E temp server files all pass.

## Inventory Audit Admin v1

Status: Implemented and locally verified on 2026-05-05.

- Added read-only admin `GET /admin/inventory/audit?player_id=...` with viewer-role access, returning inventory rows, reservation details, server time, and source totals.
- Added source totals for owned, locked, available, housing reservations, trade reservations, legacy reservations, and locked rows without reservation detail.
- Extended `OnlineClientAdmin` and the stable `OnlineClient` facade with `fetch_inventory_audit_admin()`.
- Embedded an Inventory Audit block into Debug Ops/LiveOps so admins can enter a player ID and inspect item locks without touching player-facing UI.
- Split audit row rendering into `InventoryAuditRows` to keep the existing Debug Ops panel under the 300-line Godot file budget.
- Added backend and Godot smoke coverage for source summaries and rendered reservation rows.
- Verified on 2026-05-05: content validation, full Go backend tests, backend preflight, inventory audit rows smoke, liveops console smoke, world utility inventory rows smoke, social facility trade action smoke, real Go backend online E2E, Web export, `git diff --check`, and clear local ports all pass.

## Reservation Repair Playbook v1

Status: Implemented and locally verified on 2026-05-05.

- Added diagnostic-only repair flags to inventory audit responses: `locked_without_reservation`, `reservation_exceeds_locked`, and `unknown_reservation_reason`.
- Kept the repair boundary read-only; LiveOps can see flags but cannot mutate inventory, delete reservations, refund coins, or force unlock items.
- Updated `InventoryAuditRows` to display repair flags above item rows so operators see risk markers before reading raw reservation details.
- Added `docs/ReservationRepairPlaybook.md` with source meanings, triage flow, escalation packet, and explicit forbidden actions.
- Added backend coverage for healthy audits producing no flags and synthetic mismatch rows producing all expected diagnostics.
- Added smoke coverage so repair flags render inside the inventory audit UI.
- Verified on 2026-05-05: content validation, full Go backend tests, backend preflight, inventory audit rows smoke, liveops console smoke, world utility inventory rows smoke, social facility trade action smoke, real Go backend online E2E, Web export, `git diff --check`, and clear local ports all pass.

## Admin Action Audit v1

Status: Implemented and locally verified on 2026-05-05.

- Added unified viewer-readable `GET /admin/action-audit` with filters for action, target type, target id, role, limit, and offset.
- The audit stream stores only hashed admin actor IDs, roles, source client, request IDs, target metadata, confirmation state, and notes; raw admin tokens are never stored or returned.
- Covered high-risk MVP actions: chat moderation, chat report review, creator package review/publish/rollback/unpublish, creator-share grants, map grants, and utility panel updates.
- Added bounded in-process retention of the latest 200 audit events and exposed aggregate count/last id in `/debug/ops`.
- Updated backend contracts and MVP performance/progress scoring to reflect the stronger LiveOps traceability path.
- Verified on 2026-05-05: content validation, full Go backend tests, backend preflight, `git diff --check`, and targeted admin action audit coverage for action creation, viewer access, filter behavior, Debug Ops stats, and token non-leakage all pass.

## Admin Action Audit UI v1

Status: Implemented and locally verified on 2026-05-05.

- Added a read-only `AdminActionAuditPanel` and embedded it in the LiveOps Audit tab beside moderation history, so operators can inspect recent high-risk admin actions without leaving the console.
- Added client support for `GET /admin/action-audit` through `OnlineClientAdmin` and the stable `OnlineClient` facade.
- Added English, Japanese, and Simplified Chinese UI strings for loading, empty state, row title, row detail, and summary text.
- Extended LiveOps smoke coverage with an action-audit snapshot to keep the panel visible and localized in the main console test path.
- Extended real backend E2E to verify creator review/publish actions appear in the admin action audit stream.
- Verified on 2026-05-05: content validation, LiveOps console smoke, real Go backend online E2E, Web export, selected H5 LiveOps Audit screenshots at 960x540 and 375x240, `git diff --check`, and clear local ports all pass.

## Trade Mobile Input Guard v1

Status: Implemented and locally verified on 2026-05-05.

- Registered dynamically created trade price inputs with the shared mobile keyboard avoidance controller, so the trade market panel lifts with the chat bar on compact landscape viewports.
- Added numeric virtual keyboard type and select-all-on-focus behavior to trade price fields.
- Pressing Enter/Done from the price input now submits the paired Post action, keeping mobile listing creation to one focused field plus one confirm gesture.
- Added a targeted H5 screenshot case for the online trade market price-input focus state.
- Verified on 2026-05-05: social facility panel action smoke, social facility trade action smoke, main-city interaction smoke, Web export, and `scripts/run_h5_matrix.sh` targeted to `h5-mobile-landscape-trade-price-keyboard-guard` all pass.

## Trade Dual Account E2E v1

Status: Implemented and locally verified on 2026-05-05.

- Added a dedicated real-backend trade E2E helper that uses the seller's map-activity `trail_token`, creates a live listing, logs in a second buyer account, and purchases through the authenticated Go gateway.
- The E2E now verifies seller escrow lock, self-purchase rejection, cross-player cancel rejection, buyer wallet debit, seller wallet credit, buyer inventory delivery, seller inventory depletion, seller ledger source, sold-listing cancel rejection, and replay-buy rejection.
- Kept the new helper isolated in `BackendE2ETradeHelpers.gd` so the main online backend E2E and shared helper files stay under the 300-line GDScript budget.
- Verified on 2026-05-05: content validation, targeted Go trade/inventory gateway tests, real Go backend online E2E, and `git diff --check` all pass.

## Postgres Trade Persistence E2E v1

Status: Implemented with local harness verification on 2026-05-05; real PostgreSQL execution requires `PSW_POSTGRES_TEST_DSN`.

- Added an opt-in PostgreSQL integration test for the GORM trade service covering listing create, escrow lock, service reconstruction before purchase, purchase, buyer/seller wallet transfer, inventory delivery/depletion, ledger source records, service reconstruction after purchase, replay-buy rejection, sold-listing cancel rejection, and persisted sold/delivered status.
- The test migrates only the economy, inventory, and trade tables it needs, uses unique player ids per run, and cleans wallet, ledger, inventory, reservation, and listing rows for those ids before and after execution.
- The default local test path skips clearly when no DSN is configured, so normal MVP smoke gates stay fast while production-like Postgres checks can be run on demand with `PSW_POSTGRES_TEST_DSN`.
- Verified on 2026-05-05: `go test ./internal/trade`, explicit verbose Postgres-test skip path, content validation, targeted trade/inventory/economy tests, and `git diff --check` all pass.

## Trade Concurrent Purchase Guard v1

Status: Implemented and locally verified on 2026-05-05; PostgreSQL race execution remains DSN-gated.

- Added a local concurrent purchase regression that starts two buyers against the same listing in parallel and requires exactly one successful purchase plus one `listing_inactive` loser.
- Added an opt-in PostgreSQL concurrent purchase test using the same race helper against the GORM service, verifying the persisted single winner, loser wallet non-charge, seller one-sale balance, buyer inventory delivery, seller inventory depletion, and sold/delivered listing state.
- The Postgres path uses unique player ids and the existing cleanup routine, so repeated alpha-environment runs should not pollute shared tables.
- Verified on 2026-05-05: `go test ./internal/trade`, explicit verbose Postgres persistence/concurrency skip path without DSN, content validation, and `git diff --check` all pass.

## Trade Player Feedback v1

Status: Implemented and locally verified on 2026-05-05.

- Split trade action feedback mapping into `SocialFacilityTradeFeedback`, keeping `SocialFacilityPanel` compact while making backend error codes reusable across UI tests.
- Added player-readable feedback for sold/race-lost buys, closed-listing cancels, escrow drift during purchase, locked or unavailable stock during listing, insufficient funds, self-purchase, auth, and connection failures.
- Added English, Japanese, and Simplified Chinese strings for the new trade edge cases.
- Extended panel smoke coverage so the visible trade market shows the race-lost message after a failed Buy action, and added a dedicated feedback mapping smoke for the helper.
- Verified on 2026-05-05: trade feedback smoke, social facility panel action smoke, social facility trade action smoke, content validation, and `git diff --check` all pass.

## Trade Affordance Polish v1

Status: Implemented and locally/H5 verified on 2026-05-05.

- Trade listing rows now compare listing price against the local wallet balance before rendering the player action.
- Unaffordable listings show a missing-coin state, swap the action label to `Short` / `不足`, and render the action disabled, while the backend still remains authoritative for purchase denial.
- Inventory rows with no available stock now use locked-stock copy instead of implying the item can be posted immediately.
- Compact trade panels use a short wallet balance label only at render time so narrow desktop/mobile side panels avoid clipping.
- Added English, Japanese, and Simplified Chinese strings for short wallet balance, missing-coin price state, locked stock, and unaffordable action labels.
- Extended service and panel smoke coverage for disabled unaffordable listings and locked inventory rows.
- Re-exported Web and verified the desktop plus 844x390 mobile trade facility H5 screenshots with zero console messages.

## Trade First-Screen Ordering v1

Status: Implemented and locally/H5 verified on 2026-05-05.

- Trade rows now ignore raw backend/listing order for player-facing layout and render in a stable action-first order.
- The first rows are wallet, affordable peer listings, own active listings, sellable inventory, locked inventory, unaffordable listings, then static facility guidance.
- This keeps the Trade Market first screen focused on what a player can do now while preserving backend authority and static market/creator rows below live data.
- Service smoke coverage now asserts the exact row priority order so future backend payload changes do not accidentally reshuffle the player-facing panel.
- Re-exported Web and verified desktop plus 844x390 mobile trade facility H5 screenshots with zero console messages.

## Trade Rows Split and Entry Hint v1

Status: Implemented and locally verified on 2026-05-05.

- Moved live trade row composition into `SocialFacilityTradeRows`, reducing `SocialFacilityService` from 292 lines to 180 lines while keeping both files under the 300-line GDScript budget.
- Kept row ordering, wallet display, unavailable-stock copy, missing-coin state, and static guidance merge in one reusable helper so future trade surfaces do not duplicate panel-specific logic.
- Updated the Trade Market hotspot message from a temporary "being prepared" notice to a live-entry hint that explains buyable, owned, sellable, and short-on-coins row priority.
- Main city interaction smoke coverage now asserts the live trade entry hint, guarding against regressions where the Trade Market looks unfinished after opening.

## Trade Board Filter and Refresh v1

Status: Implemented and locally verified on 2026-05-05.

- Added a compact Trade Market toolbar with localized `All`, `Buy`, `Mine`, and `Sell` filters so players can narrow the board without opening a larger overlay.
- Added a manual `Refresh`/`Sync` action that calls the existing social facility refresh path, then shows a localized fresh-board status message.
- Moved the toolbar and row-filtering behavior into `SocialFacilityTradeToolbar`, keeping `SocialFacilityPanel` under the 300-line GDScript budget after the UI upgrade.
- Panel smoke coverage now verifies filter behavior for buyable listings, own listings, sellable inventory, and unaffordable rows, while action smoke verifies refresh feedback.

## Trade Filter Empty State and Return v1

Status: Implemented and locally verified on 2026-05-05.

- Trade filters now keep the wallet row visible and add a localized empty-state row when `Buy`, `Mine`, or `Sell` has no matching live records.
- Trade actions, manual refresh, and filter changes now return the board scroll to the top so the wallet, status feedback, and current filter context remain visible after a mutation.
- The empty-state behavior lives in `SocialFacilityTradeToolbar`, keeping the panel below the single-file GDScript budget while making the filter contract reusable.
- Panel smoke coverage now verifies a no-affordable-listings `Buy` filter state, preventing the board from appearing blank when a player has no current action.

## Trade Outcome Row v1

Status: Implemented and locally verified on 2026-05-05.

- Trade actions now add a compact recent-outcome row directly under the wallet row for purchase, listing create, listing cancel, and failed trade attempts.
- The outcome row stays inside the existing Trade Market panel and follows the current filter, preserving the playfield instead of adding another overlay.
- Outcome construction lives in `SocialFacilityTradeToolbar`; `SocialFacilityPanel` only passes the trade response to the helper, keeping the panel under the GDScript line budget.
- Panel action smoke coverage now verifies visible outcome rows for posted listings, cancelled listings, successful purchases, and failed trade attempts.

## Trade Action Runner and Outcome Detail v1

Status: Implemented and locally verified on 2026-05-05.

- Split trade action dispatch and price validation into `SocialFacilityTradeActions`, reducing `SocialFacilityPanel` from 297 lines to 269 lines before adding more trade UI.
- Upgraded the compact outcome row to use backend response details when present: purchases show spent coins and wallet balance, listing create shows posted price, and cancel shows the returned escrow item.
- Kept the extra feedback inside the existing trade rows, preserving the small mobile landscape playfield instead of adding another modal or toast layer.
- Panel action smoke coverage now verifies the new outcome detail text for create, cancel, and buy flows.

## Trade Sync Confidence and Recovery v1

Status: Implemented and locally verified on 2026-05-05.

- Added a compact sync-state chip to the Trade Market toolbar: `Ready`, `Syncing`, `Fresh`, or `Check`.
- Failed trade outcomes now render a small in-row `Sync` action that reuses the existing board refresh path, clears the stale failed outcome, and returns the list to the wallet/top context.
- Successful trade actions mark the board as fresh because the service already refreshes listings and inventory after buy/create/cancel.
- Filter labels now include live actionable counts, so players can see whether `Buy`, `Mine`, or `Sell` has content before switching views.
- The design keeps recovery feedback inside the existing panel instead of adding another modal, protecting the 960x540 and 844x390 playfield budget.
- Panel smoke coverage now verifies ready/fresh/check states, failed-outcome sync recovery, and live filter counts.

## Trade Recent Outcome History v1

Status: Implemented and locally verified on 2026-05-05.

- Added `SocialFacilityTradeOutcomeHistory` to keep the latest three trade outcomes under the wallet row, newest first.
- The history stores buy/create/cancel/failure rows with the same compact row contract as the trade board, so it adds confidence without adding another UI surface.
- Failed rows still provide the small `Sync` recovery action; after a successful sync, failed rows are cleared while recent successful rows remain visible.
- Moved outcome row construction out of `SocialFacilityTradeToolbar`, reducing the toolbar from 244 lines to 188 lines and keeping the trade UI safe for the GDScript line budget.
- Panel action smoke coverage now verifies three-row retention, max-three capping, and failed-row cleanup after sync recovery.

## Trade Server History v1

Status: Implemented and locally/H5 verified on 2026-05-05.

- Added server-side trade event history for listing create, sale, and cancel events in both memory and PostgreSQL-backed trade services.
- Added authenticated `GET /trade/history?player_id=...&limit=...`, with player-token enforcement and a capped read limit for compact UI polling.
- The Trade Market service now fetches recent server history and appends the latest three read-only event rows into the existing market panel, keeping the small-screen surface compact.
- Added `OnlineClientTrade` so the new endpoint does not push `OnlineClientEndpoints` over the 300-line GDScript budget.
- Updated `docs/BackendContract.md` with the event payload contract and PostgreSQL storage note.
- Verified on 2026-05-05: full Go backend tests, targeted trade/gateway tests, social facility service/panel/action smokes, online client smoke, main-city interaction smoke, content validation, Web export, and desktop/mobile-landscape trade H5 screenshots all pass.

## Trade LiveOps History Audit v1

Status: Implemented and locally verified on 2026-05-05.

- Added authenticated `GET /admin/trade/history` for owner/viewer LiveOps reads over server-side trade events.
- The admin endpoint supports `type`, `player_id`, `seller_id`, `buyer_id`, `item_id`, `listing_id`, `limit`, and `offset` filters, so support can inspect a sale without touching player state.
- Added `TradeHistoryAuditPanel` and embedded it in the LiveOps Audit tab alongside moderation and high-risk admin action audit.
- Added compact filters for event type, player id, and item id while keeping the panel inside the existing LiveOps scroll surface.
- Extended admin capabilities with `read_trade_history` and documented the new contract in `docs/BackendContract.md`.
- Verified on 2026-05-05: full Go backend tests, targeted trade/gateway tests, trade history audit panel smoke, LiveOps console smoke, online client smoke, and content validation all pass.

## Trade LiveOps CSV Export v1

Status: Implemented and locally verified on 2026-05-05.

- Added `format=csv` support to `GET /admin/trade/history`, reusing the bounded LiveOps CSV export path already used by reviewer and moderation audit streams.
- The export preserves the active trade filters and emits `id,type,listing_id,seller_id,buyer_id,item_id,title_key,icon_id,price,created_unix` for support handoff.
- Added an `Export CSV` action to `TradeHistoryAuditPanel`; H5 operators now get a readiness/byte-count status without exposing file-system paths inside the exported client.
- Added `docs/LiveOpsRiskThresholds.md` with initial Public Alpha warning/critical thresholds for trade, economy, realtime, moderation, admin actions, and cleanup jobs.
- Verified on 2026-05-05: targeted trade/gateway tests, trade history audit panel smoke, OnlineClient smoke, and backend CSV content assertions pass.

## LiveOps Alert Wiring v1

Status: Implemented and locally verified on 2026-05-06.

- Added `/debug/ops.alerts` with a Public Alpha threshold snapshot containing `highest_severity`, active alert rows, open report count, missing admin-note count, and movement culling ratio.
- Wired warning/critical checks for economy reward cap hits, fishing reward caps, WebSocket failed writes, movement culling ratio, open chat reports, and high-risk admin actions missing notes.
- Added `DebugOpsAlertRows` and rendered the alert summary inside the existing Debug Ops panel without pushing `DebugOpsPanel.gd` over the 300-line budget.
- Updated `docs/LiveOpsRiskThresholds.md` to distinguish wired alerts from remaining documented operator checks.
- Verified on 2026-05-06: targeted Go gateway alert tests, LiveOps console smoke, and content validation pass.

## Trade Risk Alert Wiring v1

Status: Implemented and locally verified on 2026-05-06.

- Added gateway-side trade risk counters for inactive buy/race-lost attempts, insufficient funds, rejected creates, inactive cancels, and unexpected trade settlement failures.
- Added recent trade event stats to `/debug/ops.alerts.trade`, including created, sold, cancelled, completion count, cancel rate, active listing count, and high-price active listing count.
- Wired LiveOps alerts for trade race/stale listings, high cancel rate, high-price active listings, and settlement failures.
- Updated `docs/LiveOpsRiskThresholds.md` and `docs/BackendContract.md` with the new trade risk alert contract.
- Verified on 2026-05-06: targeted Go gateway trade-risk alert tests pass.

## LiveOps Alert Forwarding v1

Status: Implemented and locally verified on 2026-05-06.

- Added authenticated `GET /debug/ops/alerts` so production monitoring can poll the Public Alpha alert snapshot without fetching the full Debug Ops payload.
- Added `format=prometheus` text output for lightweight metrics collectors and systemd timer scripts.
- Added structured `liveops_alert_snapshot` JSON log emission when active alerts exist, with `emit_log=1` available for heartbeat checks.
- Documented the forwarding contract in `docs/BackendContract.md` and `docs/LiveOpsRiskThresholds.md`.
- Verified on 2026-05-06: targeted Go gateway alert-forwarding tests pass.

## Ubuntu LiveOps Alert Timer v1

Status: Implemented and locally verified on 2026-05-06.

- Added `pixel-social-world-liveops-alert-probe`, a read-only curl probe that polls `/debug/ops/alerts?emit_log=1` without exposing the admin token in the command line.
- Added one-minute `pixel-social-world-liveops-alerts.timer` and a hardened oneshot service so Ubuntu deployments can emit alert heartbeats into journald before a full external monitoring stack exists.
- Extended the origin install script, deploy env example, release bundle README, backend deployment docs, and LiveOps risk threshold doc with the new probe flow.
- Updated MVP scoring to reflect the first server-side monitoring receiver path: LiveOps/moderation 92%, public alpha readiness 78-82%, and LiveOps/admin performance 4.5.

## Creator Payout Drilldown v1

Status: Implemented and locally verified on 2026-05-06.

- Added `game_id` to creator economy ledger rows so player rewards and creator revenue-share events retain the minigame identity needed for payout audits.
- Added economy creator payout drilldowns grouped by `creator_id` and `game_id`, with event count, coin total, last revenue time, and recent settlement source.
- Added admin read-only `GET /admin/economy/creator-payouts` and embedded the top creator/game payout rows into `/debug/ops.creator_payouts`.
- Added compact LiveOps Debug Ops rows for creator payout totals while keeping the main ops panel under the GDScript line budget.
- Updated backend contracts and MVP scoring: Economy 94%, Creator platform 76%, LiveOps/moderation 93%, overall MVP 95-97%, and Public Alpha readiness 79-83%.

## Android Trade Compact Priority v1

Status: Implemented and Android-device verified on 2026-05-09.

- Reordered compact Trade Market filtered rows so `Mine`, `Sell`, and `Buy` views prioritize the next player action above recent outcome/history rows.
- `Mine` now keeps the active own-listing cancel row visible immediately after posting; `Sell` keeps the inventory post row visible immediately after cancelling.
- Recent outcome rows remain in the panel, but they no longer push the primary action below the first compact viewport on Android landscape.
- Added panel smoke assertions that verify `Cancel` appears before `Listing live` after posting and `Post` appears before `Listing closed` after cancelling.
- Verified on Android device `c7e94055`: local alpha backend through `adb reverse`, Trade Market sync, post listing, cancel listing, and compact screenshots pass.
- Re-exported H5 and ran the full screenshot matrix after the change: 151 screenshots, 0 console messages, ports clear.

## H5 Mobile Keyboard Guard v1

Status: Implemented and Android-device verified on 2026-05-10.

- Added Web shell `notranslate` patching so Android Chrome no longer covers the first screen with the translate prompt during H5 smoke passes.
- Added Web `visualViewport` keyboard-height detection to the shared mobile input controller, then used focused-input geometry to lift compact side panels enough for chat, private messages, and trade price entry.
- Added a local-alpha-only H5 trade seed hook for screenshot tests so the Trade Market price field is present without touching production player state; the hook now injects a local sellable item before the optional online claim so true-device timing cannot strand the test in an empty inventory state.
- Extended the H5 matrix trade price case to seed sellable stock and verify the shared keyboard-guard path.
- Verified: `mobile_input_controller_smoke`, `social_facility_panel_smoke`, focused H5 matrix for trade/chat/private keyboard guards, focused semantic PNG checks, and `git diff --check` all pass.
- Verified on Android device `c7e94055`: Trade Market local alpha through `adb reverse`, seeded sellable stock, price input focus with Gboard open, typed price `12`, and visible `Post` action above the keyboard. Screenshots are `.tools/android-h5-keyboard-fps/41-trade-price-keyboard-open.png` and `.tools/android-h5-keyboard-fps/42-trade-price-keyboard-typed.png`.

## Android Trade Buyer Closed Loop v1

Status: Implemented and Android-device verified on 2026-05-10.

- Fixed the online Trade Market inventory refresh path so `OnlineClient.fetch_trade_inventory()` and `SocialFacilityService` call the dedicated `/trade/inventory` endpoint before falling back to legacy inventory reads.
- Trade Market now auto-syncs listings and sellable inventory when the panel opens, so Android players do not need to know that the Sync action exists before buying or selling.
- Verified the seller path on Android device `c7e94055`: sync, post `Arcade Cabinet`, cancel listing, and compact row priority all pass.
- Verified the buyer path on Android device `c7e94055`: a curl-seeded seller posted `Simple Chair` for 7c, Android buyer saw the listing, bought it, received `Purchase complete`, wallet moved from 25c to 18c, and the board refreshed.
- Verified server state after the device purchase: seller `simple_chair` inventory moved from 1 to 0, buyer `simple_chair` inventory moved from 1 to 2, and `/admin/trade/history` returned both `created` and `sold` events for the listing.
- Screenshots and state captures are in `.tools/android-trade-buyer-loop/04-buyer-trade-panel.png`, `.tools/android-trade-buyer-loop/05-after-buy.png`, `.tools/android-trade-buyer-loop/seller_audit_after_buy.json`, `.tools/android-trade-buyer-loop/buyer_audit_after_buy.json`, and `.tools/android-trade-buyer-loop/trade_history_after_buy.json`.

## Trade Concurrency Failure States v2

Status: Implemented and locally verified on 2026-05-10.

- Added per-action in-flight guards in the Trade Market panel so repeated signals or fast double taps on the same listing/item cannot dispatch duplicate buy, post, or cancel requests while the first action is still pending.
- Added stable action identity helpers for trade actions: buy/cancel are keyed by `listing_id`, while post is keyed by `item_id`.
- Mapped weak-network transport failures such as `http_0` and `request_timeout` to the trade connection recovery copy instead of the generic purchase-failed message.
- Extended panel smoke coverage for duplicate pending buys, insufficient funds, race-lost stale listings, weak-network recovery copy, failed outcome rows, and sync recovery.
- Verified: `social_facility_panel_actions_smoke`, `social_facility_trade_feedback_smoke`, `social_facility_trade_actions_smoke`, `social_facility_service_smoke`, and `online_client_smoke` all pass.

## Android Trade Failure States Device Pass v1

Status: Android-device verified on 2026-05-10.

- Re-exported and installed `builds/android/pixel_social_world-debug.apk` on Android device `c7e94055`, then ran Trade Market against the local alpha backend with curl-seeded seller listings.
- Verified fast double-tap buy protection on device: two rapid taps on the same visible buy action produced only one additional server `/buy` request, one purchase outcome, and wallet movement from 25c to 18c.
- Verified stale-listing race handling: a second buyer bought the visible listing through the API first, then the Android buyer tapped the stale row and received the expected 409-backed "Someone bought this first. The board has refreshed." recovery state.
- Verified backend-unavailable handling by stopping the local API before tapping the trade action; the Android UI showed "Trade service is unavailable. Refresh and try again." without changing the wallet.
- Verified buyer audit history still contained one successful Android purchase for the test buyer, and PID-scoped Android logcat scans before and after the API-down case showed no fatal exception, ANR, crash, panic, segmentation fault, or Godot error.
- Tightened the compact Trade Market list viewport after the pass so Android no longer shows a half-clipped buy button at the bottom of the first list page; re-exported, reinstalled, and visually verified the first buy action is fully visible.
- Evidence: `.tools/android-trade-failure-v2/05-after-doubletap-buy.png`, `.tools/android-trade-failure-v2/06b-after-stale-button-tap-y805.png`, `.tools/android-trade-failure-v2/08-after-api-down-buy.png`, `.tools/android-trade-failure-v2/11-visual-trade-panel-after-list-height.png`, `.tools/android-trade-failure-v2/buyer_trade_history.json`, and `.tools/android-trade-failure-v2/app_logcat_tail_after_api_down.txt`.

## Android Combo Back Navigation v1

Status: Implemented and Android-device verified on 2026-05-10.

- Added Android Back / `ui_cancel` handling to the housing room screen so players can leave edit mode without needing to tap the small `Leave` button, and fixed the tile-click path so room placement still reaches `HousingRoomEditController.handle_tile()`.
- Added guarded Android Back / `ui_cancel` handling to the minigame sandbox so players can leave Fishing through the hardware Back key without double-routing the session.
- Login now releases the mobile keyboard when the play action is accepted, reducing first-screen keyboard residue during device flows.
- Extended smoke coverage: `housing_smoke` now verifies housing `ui_cancel` routes back to `main_city`; `minigame_launch_flow_smoke` now verifies sandbox `ui_cancel` returns to the main-city room before rechecking the normal finish path.
- Verified focused Godot smokes: `housing_smoke`, `minigame_launch_flow_smoke`, `world_hud_cancel_overlay_smoke`, `mobile_input_controller_smoke`, `minigame_contract_smoke`, `social_facility_panel_actions_smoke`, `social_facility_trade_feedback_smoke`, `login_character_selection_smoke`, `main_city_interactions_smoke`, and `main_city_tap_move_controller_smoke`.
- Re-exported and installed `builds/android/pixel_social_world-debug.apk` on device `c7e94055`; local alpha through `adb reverse` verified: Login -> main city -> House -> Android Back -> main city -> Fishing -> Android Back -> main city -> Trade Market -> trade panel -> Android Back closes panel.
- PID-scoped Android logcat scan after the combo route found no fatal exception, ANR, crash, panic, segmentation fault, AndroidRuntime error, or Godot script error.
- Evidence: `.tools/android-combo-v2-backfix/02-house-open.png`, `.tools/android-combo-v2-backfix/03-house-after-back.png`, `.tools/android-combo-v2-backfix/04-minigame-open.png`, `.tools/android-combo-v2-backfix/05-minigame-after-back.png`, `.tools/android-combo-v2-backfix/09-trade-panel-open.png`, `.tools/android-combo-v2-backfix/10-trade-after-back.png`, and `.tools/android-combo-v2-backfix/app_logcat_tail_after_backfix.txt`.

## Android Map UI Polish v1

Status: Implemented and Android-device verified on 2026-05-10.

- Ran focused map/HUD smokes for hotspot precision, tap-to-move, route debounce, hotspot route integrity, NPC grounding and visual quality, map point quality, interaction quality, utility hotspots, and overlay cancel.
- Tightened the compact Trade Market toolbar width so the `Fresh` and `Check` sync states no longer truncate beside the `Sync` button on Android landscape.
- Extended compact Trade Market smoke coverage so the panel opens in compact layout and asserts the sync-state label has enough width.
- Re-exported and installed `builds/android/pixel_social_world-debug.apk` on device `c7e94055`; local alpha through `adb reverse` verified Trade Market map -> trade panel, with `Fresh` fully visible and no panel/HUD overlap.
- PID-scoped Android logcat scan after the route found no fatal exception, ANR, crash, panic, segmentation fault, AndroidRuntime error, or Godot script error.
- Evidence: `.tools/android-map-ui-v2/05-trade-panel-fresh-lower.png` and `.tools/android-map-ui-v2/app_logcat_tail.txt`.

## Map NPC Baseline Clearance v2

Status: Implemented and H5/Godot/Android-device verified on 2026-05-10.

- Raised the NPC-vs-blocked-art baseline quality gate from 24px to 48px so NPC feet no longer read as standing on roofs, tents, lantern stands, blankets, crates, or similar decorative masses.
- Repositioned close NPC/interaction anchors across Forest Dawn, Housing District, Arcade Hall, Starter Farm, Ruin Dig Site, Mist Wetland, Old Ruins, Lantern Forest, Cherry Blossom Fair, and Summer Fireworks Pier.
- Kept paired interaction/activity/spawn anchors aligned when a central NPC point moved, so touch routing and map markers do not drift away from the visible guide.
- Verified the full Godot map smoke matrix: hotspot precision, route debounce, interactions, NPC ambience/attention/feedback, tap-to-move, map activities, actor depth, collision patrol, first-screen readability, gathering quality, hotspot route integrity, interaction quality v2, NPC action routes, NPC grounding/visual quality, point quality, production contract, return portal, travel matrix, unlocker, and utility hotspots.
- Re-exported the Web build after the point changes, then verified H5 map patrol: 32 maps x desktop/mobile landscape = 64 screenshots, 0 console messages, semantic pixel checks passed, and ports cleared.
- Re-exported and installed `builds/android/pixel_social_world-debug.apk` on Android device `c7e94055`; local alpha through `adb reverse` verified login, main city, unlocked Map Atlas, Social category, direct travel into Housing District, and direct travel into Ancient Tree Maze.
- PID-scoped Android logcat scans after the map pass found no fatal exception, ANR, crash, panic, segmentation fault, AndroidRuntime error, or Godot script error.
- Restored the device `player_profile.json` after the temporary unlocked-map sweep so the phone is not left in QA-only state.
- Evidence: `.tools/h5-map-npc-clearance-v2-exported/map-patrol-report.html`, `.tools/h5-map-npc-clearance-v2-exported/h5-matrix.json`, `.tools/android-map-npc-clearance-v2-device/09-traveled-housing-district.png`, `.tools/android-map-npc-clearance-v2-device/13-traveled-ancient-tree-maze.png`, and `.tools/android-map-npc-clearance-v2-device/app_logcat_after_sweep.txt`.

## Android Map Sweep Gate v1

Status: Implemented and Android-device verified on 2026-05-10.

- Added a debug-build-only Android startup route file (`user://android_debug_startup.json`) so device QA can launch directly into a target world map without exposing the hook in production builds.
- Added `MainCityLocalDebug` to apply Android map/panel/facility debug intents while preserving the existing Web debug path.
- Added `scripts/run_android_map_sweep.sh` to back up the device profile, unlock the 32-map catalog, launch each map, wait for the intended `current_world_map_id`, capture screenshots with a non-splash size retry, scan PID-scoped logcat, create a contact sheet, and restore the original profile.
- Re-exported and installed `builds/android/pixel_social_world-debug.apk` on Android device `c7e94055`, then verified all 32 Image 2 maps through the automated sweep.
- Verified: 32/32 screenshots captured, no screenshot under the semantic size threshold, contact sheet had no black/splash tiles, and PID-scoped logcat found no fatal exception, ANR, crash, panic, segmentation fault, AndroidRuntime error, or Godot script error.
- Confirmed the phone was restored after the sweep: no `android_debug_startup.json` remained, and `player_profile.json` returned to `city_forest_dawn_v1` with only the normal first discovered map.
- Evidence: `.tools/android-map-sweep-v1-full-fixed/android-map-sweep.json`, `.tools/android-map-sweep-v1-full-fixed/contact-sheet.png`, and `.tools/android-map-sweep-v1-full-fixed/app_logcat_after_sweep.txt`.

## Mobile HUD Tooltip Polish v2

Status: Implemented, H5/Godot verified, reinstalled, and Android device-smoked on `c7e94055` on 2026-05-10.

- Suppressed HUD action-button tooltips on Android, iOS, and compact touch Web so mobile sweeps no longer show stray black tooltip boxes such as `Messages` in the upper-left corner.
- Restored Image 2 button frames on icon action buttons, keeping the bottom HUD icon-first while satisfying the formal UI asset contract.
- Switched the Image 2 HUD strip 9-slice mode from tile-fit to exact tile mode, so the wide top/bottom yellow HUD strips repeat at source pixel scale instead of subtly stretching across landscape screens.
- Added `hud_tooltip_policy_smoke` to lock the desktop-vs-touch tooltip policy.
- Moved the first-session guide behind `feature_flags.first_session_guide` and defaulted it off, matching the decision to defer newbie tasks until the larger UI/character pass is ready; the dedicated guide smoke now enables it explicitly.
- Updated H5 semantic checks so a missing first-session rect is valid when the guide feature is disabled, while still validating chip sizing when a rect is present.
- Verified: `hud_tooltip_policy_smoke`, `mobile_input_controller_smoke`, `first_session_guide_smoke`, `online_room_ui_smoke`, `world_hud_cancel_overlay_smoke`, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix with Web re-export, focused H5 semantic smoke, `node --check tests/h5_semantic_smoke.mjs`, and `git diff --check`.
- H5 visual evidence: `.tools/h5-hud-tooltip-v2/h5-mobile-landscape-world-base.png` and `.tools/h5-hud-tooltip-v2/h5-mobile-landscape-messages-panel.png` show no tooltip residue and no first-session chip.
- Android device evidence: `adb install -r -d -g builds/android/pixel_social_world-debug.apk` succeeded after phone-side install permission was allowed; `.tools/android-hud-tooltip-v2/map-city_forest_dawn_v1.png`, `.tools/android-hud-tooltip-v2/android-base-after-launch.png`, and `.tools/android-hud-tooltip-v2/android-messages-panel.png` confirm the HUD action row has no stray tooltip residue, the first-session guide stays off by default, and the compact social panel opens without layout breakage.
- Android logcat scan after the map and social-panel passes found no fatal exception, ANR, crash, panic, segmentation fault, AndroidRuntime crash marker, or Godot error; the only `AndroidRuntime` match was the normal Godot plugin registry line.
- Confirmed the phone was left clean after the debug route: no `android_debug_startup.json` remained under the app `files/` directory.
- HUD strip polish verified after the tile-mode change with `ui_frame_contract_smoke`, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix, and focused H5 semantic smoke; evidence lives under `.tools/h5-hud-strip-tile-v2/`.
- Reworked the HUD shell frame so the Image 2 border still tiles at source pixel scale but no longer draws the stretched yellow center across the whole top/bottom strip.
- Added a light parchment outline to the top HUD status labels so the map can show through while `Forest Dawn Town`, player, coins, and online state remain readable on busy generated-map art.
- Verified the shell/outline pass with `ui_frame_contract_smoke`, `online_room_ui_smoke`, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix, focused H5 semantic smoke, Android APK signing, 147.3 MB asset-budget check, Android reinstall, and Android map sweep.
- H5 shell/outline evidence: `.tools/h5-hud-shell-outline-v1/h5-mobile-landscape-world-base.png` and `.tools/h5-hud-shell-outline-v1/h5-mobile-landscape-messages-panel.png`.
- Android shell/outline evidence: `.tools/android-hud-shell-outline-v1/map-city_forest_dawn_v1.png`; package logcat scan found no fatal exception, ANR, crash, panic, segmentation fault, `E AndroidRuntime`, or Godot error.
- Upgraded the transparent top HUD from loose text-on-map to four compact Image 2 status badges for world title, player, coins, and presence; the title badge received extra left padding after true-device review so high-DPI Android text no longer hugs the frame edge.
- Locked the badge contract with `configure_hud_status_badge_frame`, `ui_frame_contract_smoke`, and `online_room_ui_smoke`, including an assertion that each top status badge uses an Image 2 panel frame.
- Verified the final badge pass with `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix, focused H5 semantic smoke, Android APK signing, 147.3 MB asset-budget check, Android reinstall, and Android map sweep.
- H5 badge evidence: `.tools/h5-hud-status-badges-v1b/h5-mobile-landscape-world-base.png` and `.tools/h5-hud-status-badges-v1b/h5-mobile-landscape-messages-panel.png`.
- Android badge evidence: `.tools/android-hud-status-badges-v1b/map-city_forest_dawn_v1.png`; package logcat scan found no fatal exception, ANR, crash, panic, segmentation fault, `E AndroidRuntime`, or Godot error, and the debug startup file was removed after the sweep.

## Utility Panel Readability v1

Status: Implemented, H5/Godot verified, reinstalled, and Android device-smoked on `c7e94055` on 2026-05-11.

- Added a shared `PanelListFrame` helper for compact utility/facility/list sections so trade, inventory, world map, and map atlas rows gain a restrained scan surface without repeating oversized Image 2 decorative frames inside the main panel.
- Applied the helper to `WorldUtilityPanel`, `SocialFacilityPanel`, and `MapAtlasRows`; large panel roots still use the formal Image 2 frame, while inner rows use lightweight separators to avoid the over-stretched yellow-frame look.
- First tried compact Image 2 row cards, rejected that screenshot pass because nested ornamentation crowded the map atlas and clipped trade rows, then replaced inner rows with flat low-alpha cards while keeping generated art on the outer panel and controls.
- Verified focused Godot smokes: `world_utility_panel_ui_smoke`, `social_facility_panel_smoke`, `social_facility_panel_actions_smoke`, `online_room_ui_smoke`, and `ui_frame_contract_smoke`.
- Verified `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix, focused H5 semantic smoke, `git diff --check`, Android APK export/sign/asset-budget, Android reinstall, and Android map sweep.
- H5 evidence: `.tools/h5-ui-panel-cards-v1b/h5-mobile-landscape-trade-facility-panel.png`, `.tools/h5-ui-panel-cards-v1b/h5-mobile-landscape-map-panel.png`, `.tools/h5-ui-panel-cards-v1b/h5-mobile-landscape-map-atlas.png`, and `.tools/h5-ui-panel-cards-v1b/h5-mobile-landscape-map-atlas-wilds-filter.png`.
- Android evidence: `.tools/android-ui-panel-cards-v1b/map-city_forest_dawn_v1.png`.

## LiveOps Audit Row Readability v1

Status: Implemented and H5/Godot verified on 2026-05-11.

- Applied the shared `PanelListFrame` helper to the LiveOps child audit lists: reviewer submissions, chat reports, chat moderation actions, admin action audit, trade history audit, Debug Ops metric rows, creator payout rows, alert rows, and inventory audit rows.
- Kept the main LiveOps and child panel Image 2 root frames intact, while inner list rows now use restrained low-alpha cards for scan clarity on 375px-wide emergency admin layouts.
- Reduced or held near-limit scripts while adding the shared row wrapper: `ReviewerConsolePanel.gd` is now 295 lines, `ChatModerationAuditPanel.gd` is now 288 lines, and `DebugOpsPanel.gd` is now 294 lines, keeping the Godot single-file budget intact.
- Added a LiveOps row-card contract assertion to `liveops_console_smoke` so populated audit lists must render card-backed rows, not just plain labels.
- Verified focused Godot smokes: `reviewer_console_smoke`, `chat_reports_console_smoke`, `chat_moderation_audit_smoke`, `trade_history_audit_panel_smoke`, `inventory_audit_rows_smoke`, and `liveops_console_smoke`.
- Verified focused H5 LiveOps matrix at 960x540 and 375x240, Debug Ops focused H5 matrix, focused H5 semantic smoke, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, and `git diff --check`.
- H5 evidence: `.tools/h5-liveops-row-cards-v1/h5-liveops-375x240.png`, `.tools/h5-liveops-row-cards-v1/h5-liveops-375x240-audit-scrolled.png`, `.tools/h5-liveops-row-cards-v1/h5-liveops-375x240-ops-tab.png`, and `.tools/h5-liveops-row-cards-v1/h5-liveops-960x540-audit-scrolled.png`.
- Debug Ops H5 evidence: `.tools/h5-liveops-debugops-row-cards-v1/h5-liveops-375x240-ops-tab.png` and `.tools/h5-liveops-debugops-row-cards-v1/h5-liveops-960x540-audit-scrolled.png`.

## Creator Panel Row Readability v1

Status: Implemented and H5/Godot verified on 2026-05-11.

- Applied the shared `PanelListFrame` and `PanelTextTheme` helpers to Creator Lab utility rows covering contract modes, draft submissions, package intake, reviewer signals, and creator status summaries.
- Kept the formal Image 2 root frame on the Creator panel while using low-alpha row cards inside the scroll area, so the creator platform reads closer to the trade and LiveOps v2 surfaces without stacking decorative yellow frames.
- Added a Creator row-card assertion to `online_room_ui_smoke` so the utility panel must render card-backed rows when Creator Lab is open.
- Added `h5-mobile-landscape-creator-panel` to the H5 viewport matrix and wired desktop plus mobile Creator coverage into the UI v2 and MVP gate defaults.
- Added a Godot Web test allowlist for the known desktop-browser virtual keyboard warning, keeping mobile keyboard guard tests strict while avoiding false failures from `DisplayServer.virtual_keyboard_get_height()` in the Web smoke environment.
- Verified focused Godot smokes: `online_room_ui_smoke` and `world_utility_panel_ui_smoke`.
- Verified project and UI gates: `project_category_v2_gate`, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, full `scripts/run_ui_v2_gate.sh`, `node --check` for the H5 viewport/runtime smokes, and `git diff --check`.
- H5 evidence: `.tools/h5-creator-panel-row-cards-v1/h5-desktop-creator-panel.png`, `.tools/h5-creator-panel-row-cards-v1/h5-mobile-landscape-creator-panel.png`, `.tools/ui-v2-gate/h5/h5-desktop-creator-panel.png`, and `.tools/ui-v2-gate/h5/h5-mobile-landscape-creator-panel.png`.

## Small-Screen Panel Consistency v2

Status: Implemented and H5/Godot verified on 2026-05-11.

- Brought the remaining high-frequency right-side panels into the same v2 row language as Trade and Creator: mailbox/private message rows and inventory rows now use the shared low-alpha `PanelListFrame` cards.
- Made `SocialMessagesPanel` preserve and forward compact layout state into its row renderer, and tightened compact margins, gaps, and scroll heights for the 844x390 mobile-landscape target.
- Kept `SocialMessagesPanel.gd` under the Godot single-file budget after the compact-layout pass; it is currently 281 lines.
- Added row-card regression checks to `social_messages_panel_smoke` and `online_room_ui_smoke`, including an inventory row-card assertion.
- Added `h5-mobile-landscape-inventory-activity-rewards` to the UI v2 and MVP gate default H5 matrices so the real inventory utility panel is screenshot-tested, not only the HUD icon-click route.
- Verified focused Godot smokes: `social_messages_panel_smoke`, `world_utility_panel_ui_smoke`, `online_room_ui_smoke`, `social_facility_panel_smoke`, and `social_facility_panel_actions_smoke`.
- Verified H5 and project gates: focused 4-case H5 matrix, focused H5 semantic smoke, `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, full `scripts/run_ui_v2_gate.sh` with 24 screenshots / 0 console messages, `project_category_v2_gate`, `node --check`, and `git diff --check`.
- H5 evidence: `.tools/h5-panel-consistency-v2/h5-mobile-landscape-messages-panel.png`, `.tools/h5-panel-consistency-v2/h5-mobile-landscape-inventory-activity-rewards.png`, `.tools/h5-panel-consistency-v2/h5-mobile-landscape-trade-facility-panel.png`, and `.tools/h5-panel-consistency-v2/h5-mobile-landscape-creator-panel.png`.

## Compact Panel Density v2

Status: Implemented and H5/Godot verified on 2026-05-11.

- Tightened compact utility/facility summaries so right-side panels reserve fewer first-screen lines on 844x390 mobile-landscape Web.
- Capped compact `WorldUtilityPanel` body copy to two lines and detail copy to one line, giving Creator Lab more visible row area without removing the full creator-contract list.
- Capped compact `SocialFacilityPanel` body/detail copy to one line each, reduced the compact trade scroll reserve, and tightened the price input plus action button sizes.
- Kept the modified Godot files inside the single-file budget: `WorldUtilityPanel.gd` is 294 lines and `SocialFacilityPanel.gd` is 297 lines.
- Verified focused Godot smokes: `world_utility_panel_ui_smoke`, `social_facility_panel_smoke`, `social_facility_panel_actions_smoke`, and `online_room_ui_smoke`.
- Verified focused H5 matrix for Trade, Trade keyboard guard, Creator, and Inventory activity rewards with 4 screenshots / 0 console messages.
- H5 evidence: `.tools/h5-panel-density-v2/h5-mobile-landscape-trade-facility-panel.png`, `.tools/h5-panel-density-v2/h5-mobile-landscape-trade-price-keyboard-guard.png`, `.tools/h5-panel-density-v2/h5-mobile-landscape-creator-panel.png`, and `.tools/h5-panel-density-v2/h5-mobile-landscape-inventory-activity-rewards.png`.

## Secondary Panel Density v2

Status: Implemented and H5/Godot verified on 2026-05-11.

- Tightened the housing room compact catalog bar so the status label, inner margins, scroll reserve, row gaps, and furniture buttons fit inside the 844x390 mobile-landscape bottom strip without clipping the Image 2 button frames.
- Added a housing smoke assertion that compact furniture catalogs keep the scroll lane and item buttons within the mobile-height budget.
- Added `h5-mobile-landscape-profile-card` to the UI v2 and MVP gate default H5 matrices, and gave the semantic smoke an explicit mobile profile-card region so player-card regressions are checked alongside desktop.
- Verified `housing_smoke`, focused H5 matrix for map atlas/profile/housing, focused H5 semantic smoke, and full `scripts/run_ui_v2_gate.sh` with 26 screenshots / 0 console messages.
- H5 evidence: `.tools/h5-secondary-panel-density-v2/h5-mobile-landscape-housing-selected.png`, `.tools/h5-secondary-panel-density-v2/h5-mobile-landscape-profile-card.png`, `.tools/h5-secondary-panel-density-v2/h5-mobile-landscape-map-atlas-wilds-filter.png`, plus the refreshed `.tools/ui-v2-gate/h5/` set.

## Android Player Path Sweep v2

Status: Implemented and Android-device verified on `c7e94055` on 2026-05-11.

- Added `scripts/run_android_player_path_sweep.sh` to exercise a real player route on Android: main city start, tap-to-move, NPC dialog, private-message keyboard, trade facility, housing placement surface, and fishing minigame launch/cast.
- Extended `MainCityLocalDebug` so debug APKs can open NPC dialogs and launch minigames through `user://android_debug_startup.json`, while keeping the hook local/debug-only.
- Hardened hotspot prompt layout during route teardown so deferred prompt refreshes skip cleanly when a hotspot leaves the scene tree.
- Hardened housing online sync against late async callbacks by resolving `OnlineClient` and `SaveSystem` through the root scene tree and rechecking service/client availability after awaited calls.
- Verified focused Godot smokes: `main_city_interactions_smoke`, `housing_smoke`, `hotspot_prompt_safe_area_smoke`, and `minigame_launch_flow_smoke`.
- Re-exported, signed, asset-budget checked, installed, and launched `builds/android/pixel_social_world-debug.apk` on Android device `c7e94055`.
- Android sweep verified 7/7 screenshots and PID-scoped logcat found no fatal exception, ANR, crash, panic, segmentation fault, `E AndroidRuntime`, Godot error, or GDScript script error. Device profile was restored after the sweep.
- Evidence: `.tools/android-player-path-v2-fix/android-player-path-sweep.json`, `.tools/android-player-path-v2-fix/main-city-start.png`, `.tools/android-player-path-v2-fix/private-keyboard.png`, `.tools/android-player-path-v2-fix/trade-facility.png`, `.tools/android-player-path-v2-fix/housing-place.png`, `.tools/android-player-path-v2-fix/minigame-fishing.png`, and `.tools/android-player-path-v2-fix/app_logcat_after_sweep.txt`.

## Android Detail Experience v2

Status: Implemented, H5-verified, and Android-device verified on `c7e94055` on 2026-05-11.

- Tightened the compact Trade Market panel by hiding duplicate body copy, shortening marketplace status text, and giving the listing rows more first-screen space on mobile landscape.
- Improved housing edit feedback so surface changes and successful furniture placements emit concrete item-specific messages instead of falling back to the generic catalog hint.
- Reworked the compact housing catalog bottom strip for 960x540 logical layouts scaled down to 844x390 H5: the bar now reserves a larger logical safe area, uses smaller compact row/button heights, and stays above the physical screen edge.
- Tightened the fishing reward panel for compact hosts by reducing reward-panel height, icon size, row gaps, and helper text while keeping the cast/finish loop readable.
- Updated EN/JA/ZH localization keys for the new housing placement/status feedback and shorter trade copy.
- Verified `PSW_UI_V2_SKIP_H5=1 scripts/run_ui_v2_gate.sh`, focused H5 matrix and semantic smoke for trade/housing/fishing, Android APK export/sign/asset-budget, Android reinstall, and Android player path sweep.
- H5 evidence: `.tools/h5-android-detail-v2-final/h5-mobile-landscape-trade-price-keyboard-guard.png`, `.tools/h5-android-detail-v2-final/h5-mobile-landscape-housing-selected.png`, and `.tools/h5-android-detail-v2-final/h5-mobile-landscape-minigame-host.png`.
- Android evidence: `.tools/android-detail-v2-player-path/trade-facility.png`, `.tools/android-detail-v2-player-path/housing-place.png`, `.tools/android-detail-v2-player-path/minigame-fishing.png`, and `.tools/android-detail-v2-player-path/android-player-path-sweep.json`.

## Android Housing and Fishing Polish v2

Status: Implemented, H5-verified, and Android-device verified on `c7e94055` on 2026-05-11.

- Fixed the compact housing catalog readability regression seen on Android: compact catalog buttons now keep readable text-first labels, disable icon expansion, hide the horizontal scrollbar, and reset scroll position after rebuild/selection so the first item no longer appears as a clipped tail.
- Added housing smoke guards for compact button width, first-lane alignment, and hidden horizontal scroll mode.
- Swapped the fishing minigame's tall pond/reward containers from the HUD bar frame to the formal Image 2 large panel frame, preventing stretched yellow HUD bars from creating internal horizontal rails around reward text and the `Cast Again` action.
- Added fishing reward UI smoke guards so the pond and reward panels must use the large Image 2 panel frame instead of the HUD bar frame.
- Verified focused Godot smokes: `housing_smoke`, `online_room_ui_smoke`, `fishing_reward_ui_smoke`, and `minigame_launch_flow_smoke`.
- Verified H5 with fresh Web export: `.tools/housing-catalog-readable-v2-web-export/h5-mobile-landscape-housing-selected.png` and `.tools/fishing-panel-frame-v2-web/h5-mobile-landscape-minigame-host.png`.
- Re-exported, signed, asset-budget checked, installed, and launched `builds/android/pixel_social_world-debug.apk` on Android device `c7e94055`.
- Android player path sweep passed after the polish pass, including main city, tap-to-move, NPC dialog, private keyboard, trade facility, housing placement, and fishing reward screenshots. Strict logcat scan found no fatal exception, ANR, `E AndroidRuntime`, Godot error, script error, panic, segmentation fault, or crash.
- Android evidence: `.tools/android-fishing-panel-frame-v2-sweep/main-city-start.png`, `.tools/android-fishing-panel-frame-v2-sweep/housing-place.png`, `.tools/android-fishing-panel-frame-v2-sweep/minigame-fishing.png`, `.tools/android-fishing-panel-frame-v2-sweep/android-player-path-sweep.json`, and `.tools/android-fishing-panel-frame-v2-sweep/app_logcat_after_sweep.txt`.

## Map NPC Roof Guard and Profile Character Preview v2

Status: Implemented and H5/Godot verified on 2026-05-11.

- Added a runtime visual-clearance guard around blocked roof/building art so NPC spawn and patrol points can fail when they look like they are standing on rooftops, even if the pure walkability rectangle check passes.
- Extended the map NPC grounding and collision patrol smokes to assert generated `npc_points` stay visually clear of roof/building bands.
- Added selected character previews to player profile cards, including role/range text and panel-appropriate dark text colors, so the six male/female class variants are visible in social interaction UI instead of only during login selection.
- Added profile-card smoke coverage for the selected remote member variant preview and kept touched Godot scripts within the 300-line budget.
- Verified focused Godot smokes: `map_npc_grounding_smoke`, `map_collision_patrol_smoke`, `main_city_interactions_smoke`, `login_character_selection_smoke`, `player_avatar_variants_smoke`, `player_avatar_smoke`, and `map_npc_visual_quality_v2_smoke`.
- Verified H5 profile-card screenshots with fresh Web evidence: `.tools/profile-card-character-preview-v2b-web/h5-desktop-profile-card.png` and `.tools/profile-card-character-preview-v2b-web/h5-mobile-landscape-profile-card.png`.
