#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
JAVA_HOME_VALUE="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
ANDROID_SDK_ROOT_VALUE="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}}"
ANDROID_BUILD_TOOLS_VERSION="${ANDROID_BUILD_TOOLS_VERSION:-35.0.1}"
ANDROID_BUILD_TOOLS_DIR="${ANDROID_BUILD_TOOLS_DIR:-$ANDROID_SDK_ROOT_VALUE/build-tools/$ANDROID_BUILD_TOOLS_VERSION}"
ZIPALIGN_BIN="$ANDROID_BUILD_TOOLS_DIR/zipalign"
APKSIGNER_BIN="$ANDROID_BUILD_TOOLS_DIR/apksigner"
DEBUG_KEYSTORE="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/Library/Application Support/Godot/keystores/debug.keystore}"
DEBUG_KEYSTORE_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
DEBUG_KEYSTORE_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
OUTPUT_PATH="${1:-$ROOT_DIR/builds/android/pixel_social_world-debug.apk}"
PRUNE_PATTERNS=(
	"assets/tests/*"
	"assets/tools/*"
	"assets/.tools/*"
	"assets/docs/*"
	"assets/android/*"
	"assets/builds/*"
	"assets/.godot/imported/*_source*"
	"assets/assets/maps/generated/*_source.png.import"
	"assets/assets/ui/generated/*_source.png.import"
	"assets/assets/sprites/generated/*_source.png.import"
	"assets/assets/housing/generated/*_source.png.import"
	"assets/.godot/imported/launch_splash_forest_dawn_v1_*"
	"assets/assets/branding/generated/launch_splash_forest_dawn_v1_*.png"
	"assets/assets/branding/generated/launch_splash_forest_dawn_v1_*.png.import"
	"assets/.godot/imported/city_forest_dawn_v1_candidate_a*"
	"assets/.godot/imported/city_forest_dawn_v1_candidate_b*"
	"assets/.godot/imported/city_forest_dawn_v1_candidate_c*"
	"assets/.godot/imported/city_forest_dawn_v1_candidate_d*"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_a.png"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_b.png"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_c.png"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_d.png"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_a.png.import"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_b.png.import"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_c.png.import"
	"assets/assets/maps/generated/city_forest_dawn_v1_candidate_d.png.import"
)

if [[ "$OUTPUT_PATH" != /* ]]; then
	OUTPUT_PATH="$ROOT_DIR/$OUTPUT_PATH"
fi

if [[ ! -x "$GODOT_BIN" ]]; then
	printf 'Godot binary is not executable: %s\n' "$GODOT_BIN" >&2
	exit 1
fi
if [[ ! -x "$JAVA_HOME_VALUE/bin/java" ]]; then
	printf 'Java runtime is not executable: %s/bin/java\n' "$JAVA_HOME_VALUE" >&2
	exit 1
fi
if [[ ! -d "$ANDROID_SDK_ROOT_VALUE/platform-tools" ]]; then
	printf 'Android SDK platform-tools directory is missing under: %s\n' "$ANDROID_SDK_ROOT_VALUE" >&2
	exit 1
fi
if [[ ! -x "$ZIPALIGN_BIN" ]]; then
	printf 'Android zipalign is not executable: %s\n' "$ZIPALIGN_BIN" >&2
	exit 1
fi
if [[ ! -x "$APKSIGNER_BIN" ]]; then
	printf 'Android apksigner is not executable: %s\n' "$APKSIGNER_BIN" >&2
	exit 1
fi

mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
if [[ ! -f "$DEBUG_KEYSTORE" ]]; then
	"$JAVA_HOME_VALUE/bin/keytool" -genkeypair -v \
		-keystore "$DEBUG_KEYSTORE" \
		-storepass "$DEBUG_KEYSTORE_PASSWORD" \
		-keypass "$DEBUG_KEYSTORE_PASSWORD" \
		-alias "$DEBUG_KEYSTORE_USER" \
		-keyalg RSA \
		-keysize 2048 \
		-validity 10000 \
		-dname "CN=Android Debug,O=Android,C=US"
fi

env \
	JAVA_HOME="$JAVA_HOME_VALUE" \
	ANDROID_HOME="$ANDROID_SDK_ROOT_VALUE" \
	ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT_VALUE" \
	GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE" \
	GODOT_ANDROID_KEYSTORE_DEBUG_USER="$DEBUG_KEYSTORE_USER" \
	GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DEBUG_KEYSTORE_PASSWORD" \
	PSW_ANDROID_DEBUG_EXPORT_PATH="$OUTPUT_PATH" \
	PATH="$JAVA_HOME_VALUE/bin:$PATH" \
	"$GODOT_BIN" --headless --editor --path "$ROOT_DIR" --script "$ROOT_DIR/tools/export_android_debug_local.gd"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
RAW_APK="$TEMP_DIR/pixel-social-world-debug-raw.apk"
ALIGNED_APK="$TEMP_DIR/pixel-social-world-debug-aligned.apk"

cp "$OUTPUT_PATH" "$RAW_APK"
/usr/bin/zip -qd "$RAW_APK" "${PRUNE_PATTERNS[@]}" || true
"$ZIPALIGN_BIN" -f -p 4 "$RAW_APK" "$ALIGNED_APK"
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DEBUG_KEYSTORE_PASSWORD" \
	JAVA_HOME="$JAVA_HOME_VALUE" \
	PATH="$JAVA_HOME_VALUE/bin:$PATH" \
	"$APKSIGNER_BIN" sign \
		--ks "$DEBUG_KEYSTORE" \
		--ks-key-alias "$DEBUG_KEYSTORE_USER" \
		--ks-pass env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
		--key-pass env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD \
		"$ALIGNED_APK"
mv "$ALIGNED_APK" "$OUTPUT_PATH"

if unzip -l "$OUTPUT_PATH" | grep -E 'assets/(tests|tools|\.tools|docs|android|builds)/' >/dev/null; then
	printf 'Debug APK still contains development-only payload paths.\n' >&2
	exit 1
fi
JAVA_HOME="$JAVA_HOME_VALUE" PATH="$JAVA_HOME_VALUE/bin:$PATH" "$APKSIGNER_BIN" verify --verbose "$OUTPUT_PATH"
"$ROOT_DIR/scripts/check_android_asset_budget.sh" "$OUTPUT_PATH"
printf 'Android debug APK pruned, aligned, and signed: %s\n' "$OUTPUT_PATH"
