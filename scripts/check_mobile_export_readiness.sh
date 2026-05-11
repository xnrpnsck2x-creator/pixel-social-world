#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${PSW_GODOT_BIN:-$ROOT_DIR/.tools/godot-standard/Godot.app/Contents/MacOS/Godot}"
EXPORT_PRESETS="$ROOT_DIR/export_presets.cfg"
PROJECT_FILE="$ROOT_DIR/project.godot"
ANDROID_TARGET_SDK="${PSW_ANDROID_TARGET_SDK:-35}"
ANDROID_BUILD_TOOLS_VERSION="${PSW_ANDROID_BUILD_TOOLS_VERSION:-35.0.1}"
ANDROID_CMAKE_VERSION="${PSW_ANDROID_CMAKE_VERSION:-3.10.2.4988404}"
ANDROID_NDK_VERSION="${PSW_ANDROID_NDK_VERSION:-28.1.13356709}"

fail_count=0
warn_count=0

pass() {
	printf '[pass] %s\n' "$1"
}

warn() {
	warn_count=$((warn_count + 1))
	printf '[warn] %s\n' "$1"
}

fail() {
	fail_count=$((fail_count + 1))
	printf '[fail] %s\n' "$1"
}

has_project_value() {
	local pattern="$1"
	grep -Eq "$pattern" "$PROJECT_FILE"
}

has_preset_platform() {
	local platform="$1"
	grep -Eq "^platform=\"$platform\"$" "$EXPORT_PRESETS"
}

has_preset_value() {
	local pattern="$1"
	grep -Eq "$pattern" "$EXPORT_PRESETS"
}

check_no_export_secrets() {
	if grep -Eq '^(keystore/(debug|debug_user|debug_password|release|release_user|release_password)|application/(app_store_team_id|provisioning_profile_uuid_debug|provisioning_profile_uuid_release|provisioning_profile_specifier_debug|provisioning_profile_specifier_release))="[^"]+"' "$EXPORT_PRESETS"; then
		fail "export_presets.cfg contains signing credentials or profile values"
	else
		pass "export presets contain no signing credentials"
	fi
}

check_command() {
	local cmd="$1"
	local label="$2"
	if command -v "$cmd" >/dev/null 2>&1; then
		pass "$label: $(command -v "$cmd")"
	else
		fail "$label is missing"
	fi
}

resolve_java_home() {
	if [[ -n "${PSW_JAVA_HOME:-}" ]]; then
		printf '%s' "$PSW_JAVA_HOME"
	elif [[ -n "${JAVA_HOME:-}" ]]; then
		printf '%s' "$JAVA_HOME"
	elif [[ -x "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/java" ]]; then
		printf '%s' "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
	elif [[ -x "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home/bin/java" ]]; then
		printf '%s' "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
	fi
}

resolve_android_sdk_root() {
	if [[ -n "${ANDROID_HOME:-}" ]]; then
		printf '%s' "$ANDROID_HOME"
	elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
		printf '%s' "$ANDROID_SDK_ROOT"
	elif [[ -d "/opt/homebrew/share/android-commandlinetools" ]]; then
		printf '%s' "/opt/homebrew/share/android-commandlinetools"
	elif [[ -d "$HOME/Library/Android/sdk" ]]; then
		printf '%s' "$HOME/Library/Android/sdk"
	fi
}

resource_to_file() {
	local resource_path="$1"
	printf '%s/%s' "$ROOT_DIR" "${resource_path#res://}"
}

check_resource_file() {
	local resource_path="$1"
	local label="$2"
	local file_path
	file_path="$(resource_to_file "$resource_path")"

	if [[ -f "$file_path" ]]; then
		pass "$label exists: $resource_path"
	else
		fail "$label is missing: $resource_path"
	fi
}

check_png_size() {
	local resource_path="$1"
	local width="$2"
	local height="$3"
	local label="$4"
	local file_path actual_width actual_height
	file_path="$(resource_to_file "$resource_path")"

	if [[ ! -f "$file_path" ]]; then
		return
	fi
	if ! command -v sips >/dev/null 2>&1; then
		warn "cannot validate $label dimensions because sips is unavailable"
		return
	fi

	actual_width="$(sips -g pixelWidth "$file_path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
	actual_height="$(sips -g pixelHeight "$file_path" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
	if [[ "$actual_width" == "$width" && "$actual_height" == "$height" ]]; then
		pass "$label dimensions are ${width}x${height}"
	else
		fail "$label dimensions are ${actual_width:-unknown}x${actual_height:-unknown}, expected ${width}x${height}"
	fi
}

resolve_xcode_developer_dir() {
	local selected_dir
	selected_dir="$(xcode-select -p 2>/dev/null || true)"

	if [[ -n "${PSW_XCODE_DEVELOPER_DIR:-}" ]]; then
		printf '%s' "$PSW_XCODE_DEVELOPER_DIR"
	elif [[ -n "${DEVELOPER_DIR:-}" ]]; then
		printf '%s' "$DEVELOPER_DIR"
	elif [[ "$selected_dir" == *"/Xcode.app/"* ]]; then
		printf '%s' "$selected_dir"
	elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
		printf '%s' "/Applications/Xcode.app/Contents/Developer"
	else
		printf '%s' "$selected_dir"
	fi
}

check_project_config() {
	printf '\n== Godot project ==\n'
	if [[ ! -f "$PROJECT_FILE" ]]; then
		fail "project.godot is missing"
		return
	fi

	has_project_value '^config/name="[^"]+"' && pass "application name is set" || fail "application name is missing"
	has_project_value '^config/version="[^"]+"' && pass "application version is set" || warn "application version is missing"
	has_project_value '^run/main_scene="res://[^"]+\.tscn"' && pass "main scene is set" || fail "main scene is missing"
	has_project_value '^config/features=.*Mobile' && pass "Mobile feature flag is present" || warn "Mobile feature flag is not present"
	has_project_value '^window/size/viewport_width=960$' && pass "viewport width is 960" || warn "viewport width is not 960"
	has_project_value '^window/size/viewport_height=540$' && pass "viewport height is 540" || warn "viewport height is not 540"
	has_project_value '^renderer/rendering_method="mobile"$' && pass "mobile renderer is enabled" || warn "mobile renderer is not enabled"

	local main_scene
	main_scene="$(grep -E '^run/main_scene=' "$PROJECT_FILE" | sed -E 's/^run\/main_scene="res:\/\/([^"]+)"/\1/' | head -1)"
	if [[ -n "$main_scene" && -f "$ROOT_DIR/$main_scene" ]]; then
		pass "main scene file exists: $main_scene"
	else
		fail "main scene file is missing: ${main_scene:-unset}"
	fi
}

check_godot_export() {
	printf '\n== Godot export ==\n'
	if [[ -x "$GODOT_BIN" ]]; then
		local version template_version template_dir
		version="$("$GODOT_BIN" --version 2>/dev/null | head -1)"
		template_version="$(printf '%s' "$version" | sed -E 's/\.official.*$//')"
		template_dir="$HOME/Library/Application Support/Godot/export_templates/$template_version"
		pass "Godot binary: $GODOT_BIN ($version)"
		if [[ -d "$template_dir" ]]; then
			pass "export templates installed: $template_dir"
		else
			fail "export templates missing for $template_version"
		fi
	else
		fail "Godot binary not executable: $GODOT_BIN"
	fi

	if [[ ! -f "$EXPORT_PRESETS" ]]; then
		fail "export_presets.cfg is missing"
		return
	fi

	has_preset_platform "Web" && pass "Web export preset exists" || fail "Web export preset is missing"
	if has_preset_platform "iOS"; then
		pass "iOS export preset exists"
		has_preset_value '^application/bundle_identifier="com\.pixelsocialworld\.app"$' && pass "iOS bundle identifier is set" || fail "iOS bundle identifier is missing"
		has_preset_value '^application/short_version="0\.1\.0"$' && pass "iOS short version is set" || warn "iOS short version is missing"
	else
		fail "iOS export preset is missing"
	fi
	if has_preset_platform "Android"; then
		pass "Android export preset exists"
		has_preset_value '^package/unique_name="com\.pixelsocialworld\.app"$' && pass "Android package name is set" || fail "Android package name is missing"
		if has_preset_value '^gradle_build/use_gradle_build=true$'; then
			has_preset_value "^gradle_build/target_sdk=$ANDROID_TARGET_SDK$" && pass "Android Gradle target SDK is $ANDROID_TARGET_SDK" || fail "Android Gradle target SDK is not $ANDROID_TARGET_SDK"
		else
			pass "Android standard export uses Godot template target SDK defaults"
		fi
		has_preset_value '^permissions/internet=true$' && pass "Android internet permission is enabled" || fail "Android internet permission is missing"
	else
		fail "Android export preset is missing"
	fi
	check_no_export_secrets
}

check_ios_toolchain() {
	printf '\n== iOS toolchain ==\n'
	local developer_dir
	developer_dir="$(resolve_xcode_developer_dir)"

	if command -v xcode-select >/dev/null 2>&1; then
		if [[ "$developer_dir" == *"/Xcode.app/"* ]]; then
			pass "Xcode developer directory: $developer_dir"
		else
			fail "active developer directory is not full Xcode: ${developer_dir:-unset}"
		fi
	else
		fail "xcode-select is missing"
	fi

	if DEVELOPER_DIR="$developer_dir" xcodebuild -version >/dev/null 2>&1; then
		pass "xcodebuild is usable"
	else
		fail "xcodebuild is not usable"
	fi

	if DEVELOPER_DIR="$developer_dir" xcrun --sdk iphoneos --show-sdk-version >/dev/null 2>&1; then
		pass "iphoneos SDK is available"
	else
		fail "iphoneos SDK is unavailable"
	fi

	if DEVELOPER_DIR="$developer_dir" xcrun simctl list devices available >/dev/null 2>&1; then
		pass "iOS simulator tooling is available"
	else
		warn "iOS simulator tooling is unavailable"
	fi

	[[ -n "${IOS_TEAM_ID:-}" ]] && pass "IOS_TEAM_ID is set" || warn "IOS_TEAM_ID is not set"
	[[ -n "${IOS_BUNDLE_ID:-}" ]] && pass "IOS_BUNDLE_ID is set" || warn "IOS_BUNDLE_ID is not set"
}

check_android_toolchain() {
	printf '\n== Android toolchain ==\n'
	local java_home java_path sdk_root
	java_home="$(resolve_java_home)"
	java_path="${java_home:+$java_home/bin/java}"
	if [[ -n "$java_path" && -x "$java_path" ]] && "$java_path" -version >/dev/null 2>&1; then
		pass "Java runtime is usable: $java_path"
	elif java -version >/dev/null 2>&1; then
		pass "Java runtime is usable: $(command -v java)"
	else
		fail "Java runtime is unavailable"
	fi

	check_command keytool "keytool"
	check_command adb "adb"
	if command -v sdkmanager >/dev/null 2>&1; then
		if [[ -n "$java_home" ]]; then
			if JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" sdkmanager --version >/dev/null 2>&1; then
				pass "sdkmanager is usable: $(command -v sdkmanager)"
			else
				fail "sdkmanager is installed but not usable"
			fi
		elif sdkmanager --version >/dev/null 2>&1; then
			pass "sdkmanager is usable: $(command -v sdkmanager)"
		else
			fail "sdkmanager is installed but not usable"
		fi
	else
		fail "sdkmanager is missing"
	fi

	sdk_root="$(resolve_android_sdk_root)"
	if [[ -n "$sdk_root" && -d "$sdk_root" ]]; then
		pass "Android SDK root exists: $sdk_root"
		if [[ -d "$sdk_root/platforms/android-$ANDROID_TARGET_SDK" ]]; then
			pass "Android SDK platform installed: android-$ANDROID_TARGET_SDK"
		else
			fail "Android SDK platform missing: android-$ANDROID_TARGET_SDK"
		fi
		if [[ -d "$sdk_root/build-tools/$ANDROID_BUILD_TOOLS_VERSION" ]]; then
			pass "Android build-tools installed: $ANDROID_BUILD_TOOLS_VERSION"
		else
			fail "Android build-tools missing: $ANDROID_BUILD_TOOLS_VERSION"
		fi
		if [[ -d "$sdk_root/cmake/$ANDROID_CMAKE_VERSION" ]]; then
			pass "Android CMake installed: $ANDROID_CMAKE_VERSION"
		else
			fail "Android CMake missing: $ANDROID_CMAKE_VERSION"
		fi
		if [[ -d "$sdk_root/ndk/$ANDROID_NDK_VERSION" ]]; then
			pass "Android NDK installed: $ANDROID_NDK_VERSION"
		else
			fail "Android NDK missing: $ANDROID_NDK_VERSION"
		fi
		if [[ -f "$sdk_root/licenses/android-sdk-license" ]]; then
			pass "Android SDK licenses are accepted"
		else
			fail "Android SDK licenses are not accepted"
		fi
	else
		fail "ANDROID_HOME or ANDROID_SDK_ROOT is not configured"
	fi

	[[ -n "${ANDROID_RELEASE_KEYSTORE:-}" ]] && pass "ANDROID_RELEASE_KEYSTORE is set" || warn "ANDROID_RELEASE_KEYSTORE is not set"
	[[ -n "${ANDROID_RELEASE_KEYSTORE_USER:-}" ]] && pass "ANDROID_RELEASE_KEYSTORE_USER is set" || warn "ANDROID_RELEASE_KEYSTORE_USER is not set"
	[[ -n "${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}" ]] && pass "ANDROID_RELEASE_KEYSTORE_PASSWORD is set" || warn "ANDROID_RELEASE_KEYSTORE_PASSWORD is not set"
}

check_assets() {
	printf '\n== Store assets ==\n'
	local branding_config="$ROOT_DIR/configs/store_branding.json"
	local ios_icon="res://assets/branding/generated/app_icon_forest_dawn_v1_1024.png"
	local android_icon="res://assets/branding/generated/launcher_icon_forest_dawn_v1_192.png"
	local android_foreground="res://assets/branding/generated/adaptive_foreground_forest_dawn_v1_432.png"
	local android_background="res://assets/branding/generated/adaptive_background_forest_dawn_v1_432.png"
	local splash_2x="res://assets/branding/generated/launch_splash_forest_dawn_v1_2048x1152.png"
	local splash_3x="res://assets/branding/generated/launch_splash_forest_dawn_v1_2732x1536.png"

	if [[ -f "$branding_config" ]]; then
		pass "store branding config exists: configs/store_branding.json"
	else
		fail "store branding config is missing: configs/store_branding.json"
	fi

	check_resource_file "$ios_icon" "iOS app icon"
	check_resource_file "$android_icon" "Android launcher icon"
	check_resource_file "$android_foreground" "Android adaptive foreground"
	check_resource_file "$android_background" "Android adaptive background"
	check_resource_file "$splash_2x" "iOS launch splash @2x"
	check_resource_file "$splash_3x" "iOS launch splash @3x"

	check_png_size "$ios_icon" 1024 1024 "iOS app icon"
	check_png_size "$android_icon" 192 192 "Android launcher icon"
	check_png_size "$android_foreground" 432 432 "Android adaptive foreground"
	check_png_size "$android_background" 432 432 "Android adaptive background"
	check_png_size "$splash_2x" 2048 1152 "iOS launch splash @2x"
	check_png_size "$splash_3x" 2732 1536 "iOS launch splash @3x"

	has_preset_value '^icons/icon_1024x1024="res://assets/branding/generated/app_icon_forest_dawn_v1_1024\.png"$' && pass "iOS preset references the store icon" || fail "iOS preset does not reference the store icon"
	has_preset_value '^storyboard/custom_image@2x="res://assets/branding/generated/launch_splash_forest_dawn_v1_2048x1152\.png"$' && pass "iOS preset references launch splash @2x" || fail "iOS preset does not reference launch splash @2x"
	has_preset_value '^storyboard/custom_image@3x="res://assets/branding/generated/launch_splash_forest_dawn_v1_2732x1536\.png"$' && pass "iOS preset references launch splash @3x" || fail "iOS preset does not reference launch splash @3x"
	has_preset_value '^launcher_icons/main_192x192="res://assets/branding/generated/launcher_icon_forest_dawn_v1_192\.png"$' && pass "Android preset references main launcher icon" || fail "Android preset does not reference main launcher icon"
	has_preset_value '^launcher_icons/adaptive_foreground_432x432="res://assets/branding/generated/adaptive_foreground_forest_dawn_v1_432\.png"$' && pass "Android preset references adaptive foreground" || fail "Android preset does not reference adaptive foreground"
	has_preset_value '^launcher_icons/adaptive_background_432x432="res://assets/branding/generated/adaptive_background_forest_dawn_v1_432\.png"$' && pass "Android preset references adaptive background" || fail "Android preset does not reference adaptive background"
}

check_project_config
check_godot_export
check_ios_toolchain
check_android_toolchain
check_assets

printf '\nMobile export readiness: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
