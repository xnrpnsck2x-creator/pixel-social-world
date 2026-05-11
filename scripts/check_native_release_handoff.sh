#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT_DIR/docs/NativeReleaseHandoffRunbook.md"

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

require_file_nonempty() {
	local path="$1"
	if [[ -s "$ROOT_DIR/$path" ]]; then
		pass "$path exists"
	else
		fail "$path is missing or empty"
	fi
}

require_runbook_text() {
	local text="$1"
	local label="$2"
	if grep -Fq "$text" "$RUNBOOK"; then
		pass "$label"
	else
		fail "runbook missing: $label"
	fi
}

run_required_command() {
	local label="$1"
	shift
	local output
	if output="$("$@" 2>&1)"; then
		pass "$label passes"
	else
		fail "$label failed"
		printf '%s\n' "$output"
	fi
}

has_ios_signing_env() {
	[[ -n "${IOS_TEAM_ID:-}${IOS_BUNDLE_ID:-}${IOS_CODE_SIGN_IDENTITY_RELEASE:-}${IOS_PROVISIONING_PROFILE_UUID_RELEASE:-}${IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE:-}" ]]
}

has_android_signing_env() {
	[[ -n "${ANDROID_RELEASE_KEYSTORE:-}" && -n "${ANDROID_RELEASE_KEYSTORE_USER:-}" && -n "${ANDROID_RELEASE_KEYSTORE_PASSWORD:-}" ]]
}

check_strict_modes_fail_closed_when_unset() {
	local output

	if has_ios_signing_env; then
		pass "iOS strict signing env is present for release handoff"
	else
		if output="$(PSW_IOS_RELEASE_SIGNING_REQUIRED=1 "$ROOT_DIR/scripts/check_ios_release_readiness.sh" 2>&1)"; then
			fail "iOS strict release mode unexpectedly passed without signing env"
			printf '%s\n' "$output"
		else
			pass "iOS strict release mode fails closed without signing env"
		fi
	fi

	if has_android_signing_env; then
		pass "Android strict signing env is present for release handoff"
	else
		if output="$(PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1 "$ROOT_DIR/scripts/check_android_release_readiness.sh" 2>&1)"; then
			fail "Android strict release mode unexpectedly passed without signing env"
			printf '%s\n' "$output"
		else
			pass "Android strict release mode fails closed without signing env"
		fi
	fi
}

check_runbook_contract() {
	require_file_nonempty "docs/NativeReleaseHandoffRunbook.md"
	require_file_nonempty "scripts/check_mobile_export_readiness.sh"
	require_file_nonempty "scripts/check_ios_release_readiness.sh"
	require_file_nonempty "scripts/check_android_release_readiness.sh"
	require_file_nonempty "scripts/run_project_category_v2_gate.sh"

	require_runbook_text "Do not commit production signing secrets" "no committed production signing secrets rule"
	require_runbook_text "scripts/check_mobile_export_readiness.sh" "mobile export readiness command"
	require_runbook_text "scripts/check_ios_release_readiness.sh" "iOS readiness command"
	require_runbook_text "scripts/check_android_release_readiness.sh" "Android readiness command"
	require_runbook_text "scripts/check_native_release_handoff.sh" "native handoff command"
	require_runbook_text "scripts/run_project_category_v2_gate.sh" "project category gate command"
	require_runbook_text "PSW_IOS_RELEASE_SIGNING_REQUIRED=1" "iOS strict signing flag"
	require_runbook_text "PSW_ANDROID_RELEASE_SIGNING_REQUIRED=1" "Android strict signing flag"
	require_runbook_text "IOS_TEAM_ID" "iOS Team ID env"
	require_runbook_text "IOS_BUNDLE_ID" "iOS bundle id env"
	require_runbook_text "IOS_CODE_SIGN_IDENTITY_RELEASE" "iOS signing identity env"
	require_runbook_text "IOS_PROVISIONING_PROFILE_UUID_RELEASE" "iOS provisioning UUID env"
	require_runbook_text "IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE" "iOS provisioning specifier env"
	require_runbook_text "ANDROID_RELEASE_KEYSTORE" "Android release keystore env"
	require_runbook_text "ANDROID_RELEASE_KEYSTORE_USER" "Android release alias env"
	require_runbook_text "ANDROID_RELEASE_KEYSTORE_PASSWORD" "Android release store password env"
	require_runbook_text "ANDROID_RELEASE_KEY_PASSWORD" "Android release key password env"
	require_runbook_text "PSW_ANDROID_RELEASE_FORMAT=aab" "Android AAB release flag"
	require_runbook_text "Android Play AAB" "Android Play AAB preset note"
	require_runbook_text "scripts/run_android_stability_probe.sh" "Android stability command"
	require_runbook_text "scripts/run_android_device_regression.sh" "Android regression command"
	require_runbook_text "scripts/check_android_runtime_budget.sh" "Android runtime budget command"
	require_runbook_text ".tools/project-category-v2-gate/project-category-v2-summary.json" "project gate evidence"
	require_runbook_text ".tools/android-stability-soak-v1/android-stability-report.json" "Android soak evidence"
}

check_runbook_contract
run_required_command "iOS release readiness default contract" "$ROOT_DIR/scripts/check_ios_release_readiness.sh"
run_required_command "Android release readiness default contract" "$ROOT_DIR/scripts/check_android_release_readiness.sh"
run_required_command "Android AAB release readiness default contract" env PSW_ANDROID_RELEASE_FORMAT=aab "$ROOT_DIR/scripts/check_android_release_readiness.sh"
check_strict_modes_fail_closed_when_unset

if [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
	pass "native release handoff has no warnings"
elif [[ "$fail_count" -eq 0 ]]; then
	warn "native release handoff passed with warnings"
fi

printf '\nNative release handoff: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
