# Native Release Handoff Runbook

Date: 2026-05-12

Status: Local contract ready. Strict signing and store upload remain release
machine tasks because production credentials must stay outside the repository.

## Scope

This runbook is the handoff path from the current H5/Android-device verified
MVP to signed native release candidates.

It covers:

- Local no-secret export readiness.
- Android release signing handoff.
- iOS release signing handoff.
- True-device soak evidence.
- Release stop conditions and rollback.

## Non-Negotiables

- Do not commit production signing secrets.
- Do not store Apple Team ID, provisioning profile values, signing identities,
  keystore paths, aliases, passwords, store tokens, API keys, DSNs, or private
  service credentials in `export_presets.cfg`.
- Keep release signing values in environment variables, local keychain state,
  the Godot editor on the release machine, or `/etc/pixel-social-world/backend.env`.
- Keep generated production/test artifacts out of source control unless they are
  explicit lightweight evidence summaries.
- A failed strict release check means stop the upload flow and return to the
  last passing commit.

## Local Gate Before Any Native Release Candidate

Run these from the repository root before using release credentials:

```bash
scripts/check_mobile_export_readiness.sh
scripts/check_ios_release_readiness.sh
scripts/check_android_release_readiness.sh
PSW_ANDROID_RELEASE_FORMAT=aab scripts/check_android_release_readiness.sh
scripts/check_native_release_handoff.sh
scripts/check_store_publish_handoff.sh
scripts/run_project_category_v2_gate.sh
```

Expected local result:

- `check_mobile_export_readiness.sh` may warn about missing external signing
  values, but must report zero failures.
- `check_ios_release_readiness.sh` must pass in default mode with signing values
  unset.
- `check_android_release_readiness.sh` must pass in default mode with signing
  values unset.
- `PSW_ANDROID_RELEASE_FORMAT=aab scripts/check_android_release_readiness.sh`
  must pass through the dedicated `Android Play AAB` preset before a Google
  Play upload.
- `check_native_release_handoff.sh` must pass and prove strict mode fails closed
  when signing values are absent.
- `check_store_publish_handoff.sh` must pass and prove strict store publish
  mode fails closed when App Store Connect / Google Play Console values are
  absent.
- `run_project_category_v2_gate.sh` must pass without skipping Android runtime
  budget evidence on this development machine.

## Android Strict Release Handoff

Required environment variables on the release machine:

```bash
export ANDROID_RELEASE_KEYSTORE="/absolute/path/outside/repo/pixel-social-world-release.keystore"
export ANDROID_RELEASE_KEYSTORE_USER="<release-alias>"
export ANDROID_RELEASE_KEYSTORE_PASSWORD="<store-password>"
export ANDROID_RELEASE_KEY_PASSWORD="<key-password>" # optional when it matches store password
export PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1
```

Strict readiness command:

```bash
PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1 scripts/check_android_release_readiness.sh
```

Acceptance:

- The keystore path is absolute and outside the repository.
- `keytool` can read the configured alias.
- `zipalign`, `apksigner`, Java, and Android build-tools are available.
- `export_presets.cfg` still contains no signing values.

If Google Play requires an AAB for the first public build, run:

```bash
PSW_ANDROID_RELEASE_FORMAT=aab scripts/check_android_release_readiness.sh
```

The committed `Android` preset remains the APK/debug-device path. The committed
`Android Play AAB` preset is the Google Play upload path and must stay green in
AAB mode before any Play Console release.

## iOS Strict Release Handoff

Required environment variables on the release machine:

```bash
export IOS_TEAM_ID="<apple-team-id>"
export IOS_BUNDLE_ID="com.pixelsocialworld.app"
export IOS_CODE_SIGN_IDENTITY_RELEASE="<apple-distribution-identity>"
export IOS_PROVISIONING_PROFILE_UUID_RELEASE="<profile-uuid>" # or use the specifier below
export IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE="<profile-specifier>"
export PSW_IOS_RELEASE_SIGNING_REQUIRED=1
```

Strict readiness command:

```bash
PSW_IOS_RELEASE_SIGNING_REQUIRED=1 scripts/check_ios_release_readiness.sh
```

Acceptance:

- Full Xcode is selected or discoverable.
- `xcodebuild`, iphoneos SDK, `codesign`, and `security` are usable.
- The release signing identity exists in the local keychain.
- Either provisioning profile UUID or provisioning profile specifier is set.
- `export_presets.cfg` still contains no Team ID, signing identity, or
  provisioning profile values.

## Android Candidate Evidence

Debug/device evidence remains the current local proof path until release signing
is configured:

```bash
scripts/export_android_debug_local.sh
scripts/check_android_asset_budget.sh builds/android/pixel_social_world-debug.apk
PSW_ANDROID_STABILITY_DURATION_SECONDS=600 scripts/run_android_stability_probe.sh
scripts/check_android_runtime_budget.sh .tools/android-stability-soak-v1/android-stability-report.json
scripts/run_android_device_regression.sh
```

Required evidence files:

- `.tools/android-stability-render-throttle-v1/android-stability-report.json`
- `.tools/android-stability-soak-v1/android-stability-report.json`
- `.tools/android-regression-render-throttle-v1/android-device-regression.json`
- `.tools/project-category-v2-gate/project-category-v2-summary.json`

Release-mode Android evidence must repeat the same route categories after the
signed artifact is produced: launch, login, presence/WebSocket, main city,
tap-to-move, NPC dialog, private keyboard, Trade Market post/cancel, housing
placement, fishing reward, package-scoped logcat scan, and runtime budget check.

## iOS Candidate Evidence

Preset parse proof without signing:

```bash
./.tools/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "iOS" .tools/native-preset-parse/ios-main.pck
```

After strict signing passes, the iOS release candidate must receive a true-device
smoke before TestFlight upload:

- Launch and landscape orientation.
- Guest login and session restore.
- Main city walk/tap route.
- Chat and private-message input.
- Trade Market post/cancel.
- Housing placement.
- Fishing cast/reward.
- Crash log and console scan.

## Evidence Manifest

For every native release candidate, keep a local evidence folder under
`.tools/native-release-handoff/<date-or-commit>/` with:

- Build commit SHA.
- `scripts/check_native_release_handoff.sh` output.
- `scripts/run_project_category_v2_gate.sh` output.
- Android/iOS strict readiness output when signing env exists.
- Android/iOS device screenshots or video captures.
- Runtime budget reports.
- Package names, versions, build numbers, and artifact checksums.

Do not put keystore files, provisioning profiles, passwords, or store tokens in
the evidence folder.

## Stop Conditions

Stop the release flow immediately when any of these occur:

- A local readiness script reports a failure.
- Strict signing env is missing or partial.
- A signing value appears in committed config.
- Android runtime budget fails CPU, memory, swap, growth, or sample coverage.
- Device smoke finds crash, ANR, `E AndroidRuntime`, Godot error, script error,
  panic, segmentation fault, or failed login/presence/trade/housing/fishing route.
- iOS export requires a manual project edit that is not captured in repo docs.
- Store provider auth, privacy, or signing data is unclear.

Rollback target is the last commit where:

```bash
scripts/check_native_release_handoff.sh
scripts/run_project_category_v2_gate.sh
```

both passed.
