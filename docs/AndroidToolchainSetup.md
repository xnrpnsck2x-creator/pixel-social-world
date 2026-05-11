# Android Toolchain Setup

Status: Required before the first Android device export.

This project keeps Android signing secrets outside the repository. Use this
document to prepare the local machine or CI runner, then verify with:

```bash
scripts/check_mobile_export_readiness.sh
```

## Current Verified Local Layout

The current Mac has been verified with Homebrew-managed command-line tools:

```bash
brew install openjdk@21 android-commandlinetools android-platform-tools

export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="/opt/homebrew/opt/openjdk@21/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

yes | env JAVA_HOME="$JAVA_HOME" ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" PATH="$PATH" sdkmanager --licenses
env JAVA_HOME="$JAVA_HOME" ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" PATH="$PATH" \
  sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.1" \
  "cmake;3.10.2.4988404" "ndk;28.1.13356709"
```

`scripts/check_mobile_export_readiness.sh` auto-detects this Homebrew JDK and
SDK root, so the shell profile does not need global Java changes just to run the
project scan.

## Android Studio Layout

Use Android Studio for the first setup pass, then keep the CLI paths stable:

```bash
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
```

Add the exports to the shell profile only after confirming the paths exist.

## Required Components

Install these through Android Studio SDK Manager or the command-line tools:

- Android SDK Platform matching the Godot preset target SDK: `platforms;android-35`.
- Android SDK Build-Tools: `build-tools;35.0.1`.
- Android SDK CMake: `cmake;3.10.2.4988404`.
- Android NDK: `ndk;28.1.13356709`.
- Android SDK Platform-Tools, which provides `adb`.
- Android SDK Command-line Tools, which provides `sdkmanager`.
- A usable Java runtime. Android Studio's bundled JBR is acceptable if it is on
  PATH or selected in Godot's Android export settings.

## Verification Commands

Run these before opening Godot's export UI:

```bash
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
PATH="$JAVA_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

"$JAVA_HOME/bin/java" -version
keytool -help >/dev/null
adb version
env JAVA_HOME="$JAVA_HOME" ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" PATH="$PATH" sdkmanager --list_installed
scripts/check_mobile_export_readiness.sh
```

The readiness script should no longer report missing Java, `adb`, `sdkmanager`,
SDK root, Android 35 platform, build-tools 35.0.1, or SDK licenses after this
step.

## Local Debug APK Export

Use the Android device preflight wrapper before handing a build to a phone:

```bash
PSW_ANDROID_PREFLIGHT_INSTALL=1 scripts/run_android_device_preflight.sh
```

The preflight wrapper runs the mobile export readiness scan, the map quality v2
gate, the local debug APK exporter, and then installs/launches the APK when
`PSW_ANDROID_PREFLIGHT_INSTALL=1` is set. Use
`PSW_ANDROID_PREFLIGHT_EXPORT=0` for a faster no-export check while iterating.

The lower-level export wrapper is still available when only a package rebuild is
needed. Use it instead of writing debug signing values into `export_presets.cfg`:

```bash
scripts/export_android_debug_local.sh
```

The wrapper generates a local Android debug keystore if needed, injects
`GODOT_ANDROID_KEYSTORE_DEBUG_*` environment variables for the current process,
and exports `builds/android/pixel_social_world-debug.apk` through Godot's
Android exporter. After export it prunes development-only payload directories
from the APK (`tests`, `tools`, `.tools`, `docs`, `android`, `builds`), then
runs `zipalign` and `apksigner verify` so the local device-test package stays
clean while keeping production and test working files in the workspace.

With one authorized Android device connected, install and launch the latest
debug package with:

```bash
scripts/install_android_debug_local.sh
```

If multiple devices are connected, set `ANDROID_SERIAL` before running the
installer.

## Release Signing

Create or select a release keystore outside the repo:

```bash
keytool -genkeypair -v \
  -keystore "$HOME/.pixel-social-world/android-release.keystore" \
  -alias pixel-social-world-release \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Use environment variables or Godot's export UI for signing values. Do not commit
keystore paths, aliases, passwords, Apple team IDs, provisioning profiles, or
store tokens into the repository.

Minimum local environment for the current readiness scan:

```bash
export ANDROID_RELEASE_KEYSTORE="$HOME/.pixel-social-world/android-release.keystore"
export ANDROID_RELEASE_KEYSTORE_USER="pixel-social-world-release"
```

Keep password values in the local shell, a password manager, or CI secret store.

## Expected State Before Device Test

- `scripts/check_mobile_export_readiness.sh` has no Android toolchain failures.
- `scripts/run_android_device_preflight.sh` passes before device handoff.
- iOS/Android signing values are provided externally.
- `export_presets.cfg` still contains no signing credentials.
- `Godot --export-pack "Android"` passes before attempting a full APK/AAB export.
- `scripts/export_android_debug_local.sh` can produce a signed local debug APK
  with no development-only payload directories inside the package.
- `scripts/install_android_debug_local.sh` can install and launch the debug APK
  once a device is connected and authorized.
