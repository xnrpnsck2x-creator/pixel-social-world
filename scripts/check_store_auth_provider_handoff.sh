#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT_DIR/docs/StoreAuthProviderHandoff.md"
BACKEND_CONTRACT="$ROOT_DIR/docs/BackendContract.md"
PRODUCTION_CONFIG="$ROOT_DIR/backend/configs/production.yaml"
ENV_EXAMPLE="$ROOT_DIR/backend/deploy/pixel-social-world.env.example"
VALIDATION_SOURCE="$ROOT_DIR/backend/internal/config/validation.go"
REQUIRED="${PSW_STORE_AUTH_PROVIDER_REQUIRED:-0}"

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

require_text() {
	local file="$1"
	local text="$2"
	local label="$3"
	if grep -Fq "$text" "$file"; then
		pass "$label"
	else
		fail "$label missing"
	fi
}

looks_placeholder_or_empty() {
	local value="$1"
	value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
	[[ -z "$value" || "$value" == *"change_me"* || "$value" == *"example"* || "$value" == *"<"* || "$value" == *">"* ]]
}

check_committed_contract() {
	require_file_nonempty "docs/StoreAuthProviderHandoff.md"
	require_file_nonempty "docs/BackendContract.md"
	require_file_nonempty "backend/configs/production.yaml"
	require_file_nonempty "backend/deploy/pixel-social-world.env.example"
	require_file_nonempty "backend/internal/config/validation.go"
	require_file_nonempty "scripts/run_backend_e2e.sh"

	require_text "$RUNBOOK" "Do not commit Apple private keys" "no committed provider secret rule"
	require_text "$RUNBOOK" "PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt" "provider verification env"
	require_text "$RUNBOOK" "PSW_APPLE_CLIENT_IDS" "Apple client ID env"
	require_text "$RUNBOOK" "PSW_GOOGLE_CLIENT_IDS" "Google client ID env"
	require_text "$RUNBOOK" "PSW_STORE_AUTH_PROVIDER_REQUIRED=1" "strict provider flag"
	require_text "$RUNBOOK" "scripts/run_backend_e2e.sh" "backend e2e command"
	require_text "$RUNBOOK" "scripts/run_project_category_v2_gate.sh" "project category command"
	require_text "$RUNBOOK" ".tools/store-auth-handoff/" "store auth evidence folder"
	require_text "$RUNBOOK" 'Guest upgrade must preserve `player_id`' "player id preservation rule"
	require_text "$RUNBOOK" "Store review notes" "store review notes"

	require_text "$BACKEND_CONTRACT" "POST /auth/upgrade" "backend upgrade endpoint contract"
	require_text "$BACKEND_CONTRACT" 'Supported `provider`: `apple`, `google`.' "backend supported providers"
	require_text "$BACKEND_CONTRACT" "PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt" "backend strict oidc env docs"
	require_text "$BACKEND_CONTRACT" "PSW_APPLE_CLIENT_IDS" "backend Apple env docs"
	require_text "$BACKEND_CONTRACT" "PSW_GOOGLE_CLIENT_IDS" "backend Google env docs"

	require_text "$PRODUCTION_CONFIG" 'provider_verification: "oidc_jwt"' "production config defaults to oidc_jwt"
	require_text "$PRODUCTION_CONFIG" "apple_client_ids: []" "production config keeps Apple IDs external"
	require_text "$PRODUCTION_CONFIG" "google_client_ids: []" "production config keeps Google IDs external"

	require_text "$ENV_EXAMPLE" "PSW_AUTH_PROVIDER_VERIFICATION=oidc_jwt" "env example provider verification"
	require_text "$ENV_EXAMPLE" "PSW_APPLE_CLIENT_IDS=" "env example Apple client IDs"
	require_text "$ENV_EXAMPLE" "PSW_GOOGLE_CLIENT_IDS=" "env example Google client IDs"

	require_text "$VALIDATION_SOURCE" "production auth provider verification must be oidc_jwt" "strict verifier validation"
	require_text "$VALIDATION_SOURCE" "production Apple client IDs must be configured" "strict Apple ID validation"
	require_text "$VALIDATION_SOURCE" "production Google client IDs must be configured" "strict Google ID validation"
}

check_no_committed_provider_secrets() {
	if grep -REn --exclude-dir=.git --exclude='StoreAuthProviderHandoff.md' \
		'(_PRIVATE_KEY|CLIENT_SECRET|REFRESH_TOKEN|SERVICE_ACCOUNT|AUTHORIZATION_CODE|IDENTITY_TOKEN)=' \
		"$ROOT_DIR/backend" "$ROOT_DIR/configs" "$ROOT_DIR/docs" >/dev/null 2>&1; then
		fail "committed files appear to contain provider secret variable assignments"
	else
		pass "no committed provider secret assignments found"
	fi
}

check_default_or_strict_env() {
	local verifier="${PSW_AUTH_PROVIDER_VERIFICATION:-}"
	local apple_ids="${PSW_APPLE_CLIENT_IDS:-}"
	local google_ids="${PSW_GOOGLE_CLIENT_IDS:-}"

	if [[ "$REQUIRED" != "1" && -z "$verifier$apple_ids$google_ids" ]]; then
		pass "store auth provider env is external and currently unset"
		return
	fi

	if [[ "$verifier" == "oidc_jwt" ]]; then
		pass "PSW_AUTH_PROVIDER_VERIFICATION is oidc_jwt"
	else
		fail "PSW_AUTH_PROVIDER_VERIFICATION must be oidc_jwt when store auth provider env is configured"
	fi

	if looks_placeholder_or_empty "$apple_ids"; then
		fail "PSW_APPLE_CLIENT_IDS must be configured with non-placeholder Apple audiences"
	else
		pass "PSW_APPLE_CLIENT_IDS is configured"
	fi

	if looks_placeholder_or_empty "$google_ids"; then
		fail "PSW_GOOGLE_CLIENT_IDS must be configured with non-placeholder Google audiences"
	else
		pass "PSW_GOOGLE_CLIENT_IDS is configured"
	fi
}

check_strict_mode_fails_closed_when_unset() {
	if [[ "$REQUIRED" == "1" || -n "${PSW_AUTH_PROVIDER_VERIFICATION:-}${PSW_APPLE_CLIENT_IDS:-}${PSW_GOOGLE_CLIENT_IDS:-}" ]]; then
		pass "strict provider env check is active or configured"
		return
	fi

	if PSW_STORE_AUTH_PROVIDER_REQUIRED=1 "$0" >/dev/null 2>&1; then
		fail "strict store auth mode unexpectedly passed without provider env"
	else
		pass "strict store auth mode fails closed without provider env"
	fi
}

check_committed_contract
check_no_committed_provider_secrets
check_default_or_strict_env
check_strict_mode_fails_closed_when_unset

if [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
	pass "store auth provider handoff has no warnings"
elif [[ "$fail_count" -eq 0 ]]; then
	warn "store auth provider handoff passed with warnings"
fi

printf '\nStore auth provider handoff: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
