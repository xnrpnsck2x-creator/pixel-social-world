# Mobile Export Readiness

Status: Toolchain and store-branding scan added on 2026-05-07.

This document tracks the gap between the current H5 MVP and the first iOS/Android
device build. The project logic is pre-device ready, and the current Mac now has
the Android command-line toolchain needed for local debug APK exports. Native
release exports still need external signing values.

## Current Local Result

Run:

```bash
scripts/check_mobile_export_readiness.sh
```

Observed on the current machine:

- Godot project config is set for the mobile renderer and 960x540 landscape base.
- Godot 4.6.2 binary and matching export templates are present.
- Web, iOS, and Android export presets now exist. Native presets contain only
  non-secret package/build metadata; signing values remain outside the repo.
- Full Xcode is installed at `/Applications/Xcode.app`; the readiness script can
  use it without changing the global `xcode-select` setting.
- iOS export is still blocked by signing configuration, not by SDK availability
  on this machine.
- Android command-line tooling is now installed locally via Homebrew:
  `openjdk@21`, Android command-line tools, platform-tools, `platforms;android-35`,
  `build-tools;35.0.1`, `cmake;3.10.2.4988404`, `ndk;28.1.13356709`,
  and accepted SDK licenses.
- Android export is now blocked by signing configuration only for release builds;
  the readiness scan no longer reports Android toolchain failures.
- Local debug APK export uses `scripts/export_android_debug_local.sh`, which keeps
  debug signing values out of `export_presets.cfg` and injects them through
  Godot's documented `GODOT_ANDROID_KEYSTORE_DEBUG_*` environment variables.
  The wrapper also strips development-only APK payload paths after export and
  re-aligns/re-signs the APK before verification.
- Android device handoff now uses `scripts/run_android_device_preflight.sh`,
  which runs the mobile export readiness scan, the map quality v2 gate, and the
  local debug APK exporter before a phone install is attempted.
- iOS and Android signing values are intentionally not stored in the repo.
- Dedicated MVP app icon and splash assets now exist under
  `assets/branding/generated/`. They are PNG outputs derived from the approved
  Image 2 forest dawn city motherboard and registered in
  `configs/store_branding.json` plus `configs/art_assets.json`.
- Latest scan result after Android SDK setup: 0 failures and 4 warnings. The
  warnings are external signing values only: iOS Team ID, iOS bundle override,
  Android release keystore path, and Android release keystore alias.
- Native preset parse check passed with Godot `--export-pack` for both iOS and
  Android after the branding assets were wired. The generated temporary PCKs and
  logs are under `.tools/native-preset-parse/`.

## Required Before Real Device

1. Install or select full Xcode, then confirm:
   - `scripts/check_mobile_export_readiness.sh` finds the Xcode developer
     directory, or run it with `PSW_XCODE_DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
   - `xcodebuild -version` succeeds under that developer directory.
   - `xcrun --sdk iphoneos --show-sdk-version` succeeds under that developer directory.
2. Android command-line SDK tools are installed on this Mac. If preparing a new
   machine, use `docs/AndroidToolchainSetup.md`, then confirm:
   - Java runtime is usable.
   - `ANDROID_HOME` or `ANDROID_SDK_ROOT` points to the SDK.
   - `adb` and `sdkmanager` are on PATH.
  - `platforms;android-35`, `build-tools;35.0.1`, `cmake;3.10.2.4988404`,
     `ndk;28.1.13356709`, and SDK license files exist.
3. Configure signing outside the repo:
   - iOS team ID and bundle ID through local environment or Godot editor export UI.
   - Android release keystore path, alias, and passwords through local environment
     or Godot editor export UI.
4. Before store submission, review whether the MVP derived icon/splash should be
   replaced by dedicated Image 2 branding renders. The current assets are valid
   for local export wiring and device-test readiness.

## Local Verification Commands

```bash
scripts/check_mobile_export_readiness.sh
PSW_ANDROID_PREFLIGHT_EXPORT=0 scripts/run_android_device_preflight.sh
./.tools/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "iOS" .tools/native-preset-parse/ios-main.pck
./.tools/godot-standard/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "Android" .tools/native-preset-parse/android-main.pck
scripts/export_android_debug_local.sh
! unzip -l builds/android/pixel_social_world-debug.apk | grep -E 'assets/(tests|tools|\.tools|docs|android|builds)/'
```

With one authorized Android device attached:

```bash
PSW_ANDROID_PREFLIGHT_INSTALL=1 scripts/run_android_device_preflight.sh
```

Set `PSW_ANDROID_PREFLIGHT_EXPORT=0` for a fast local gate that does not rebuild
the APK, or `PSW_ANDROID_PREFLIGHT_MAP_SKIP_H5=0` when the H5 map screenshot
subset should run inside the same preflight.

## Non-Negotiables

- Do not commit production signing secrets.
- Do not write bundle secrets, keystore passwords, Apple team secrets, or store
  tokens into `export_presets.cfg`.
- Keep H5 smoke and semantic screenshot gates passing before every native export.
- Keep official app icon/splash assets as Image 2 PNG/WebP outputs, not SVG
  placeholders.
