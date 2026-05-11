#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT_DIR/docs/ProductionDataBackupHandoff.md"
BACKEND_DEPLOYMENT="$ROOT_DIR/docs/BackendDeployment.md"
LIVEOPS_THRESHOLDS="$ROOT_DIR/docs/LiveOpsRiskThresholds.md"
MVP_SCORE="$ROOT_DIR/docs/MVPProgressPerformanceScore.md"
PRODUCTION_CONFIG="$ROOT_DIR/backend/configs/production.yaml"
ENV_EXAMPLE="$ROOT_DIR/backend/deploy/pixel-social-world.env.example"
INSTALL_SCRIPT="$ROOT_DIR/backend/deploy/install-funyoru-origin.sh"
REQUIRED="${PSW_PRODUCTION_BACKUP_REQUIRED:-0}"

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
	if grep -Fq -- "$text" "$file"; then
		pass "$label"
	else
		fail "$label missing"
	fi
}

is_placeholder_or_empty() {
	local value="$1"
	value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
	[[ -z "$value" || "$value" == *"change_me"* || "$value" == *"<"* || "$value" == *">"* || "$value" == *"..."* ]]
}

is_repo_path() {
	local value="$1"
	[[ "$value" == "$ROOT_DIR" || "$value" == "$ROOT_DIR/"* ]]
}

is_app_install_path() {
	local value="$1"
	[[ "$value" == "/opt/pixel-social-world" || "$value" == "/opt/pixel-social-world/"* ]]
}

is_absolute_path() {
	[[ "$1" == /* ]]
}

is_supported_encryption() {
	local value
	value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
	[[ -n "$value" && "$value" != "none" && "$value" != "disabled" && "$value" != "plaintext" ]]
}

check_committed_contract() {
	require_file_nonempty "docs/ProductionDataBackupHandoff.md"
	require_file_nonempty "docs/BackendDeployment.md"
	require_file_nonempty "docs/LiveOpsRiskThresholds.md"
	require_file_nonempty "docs/MVPProgressPerformanceScore.md"
	require_file_nonempty "backend/configs/production.yaml"
	require_file_nonempty "backend/deploy/pixel-social-world.env.example"
	require_file_nonempty "backend/deploy/install-funyoru-origin.sh"

	require_text "$RUNBOOK" "Do not commit DB dumps" "no committed backup artifacts rule"
	require_text "$RUNBOOK" "Room chat is ephemeral" "ephemeral room chat exclusion"
	require_text "$RUNBOOK" "PSW_PRODUCTION_BACKUP_REQUIRED=1" "strict backup flag"
	require_text "$RUNBOOK" "PSW_POSTGRES_DSN" "PostgreSQL DSN env"
	require_text "$RUNBOOK" "PSW_PACKAGE_ARTIFACT_DIR" "creator artifact env"
	require_text "$RUNBOOK" "PSW_PACKAGE_INSTALL_DIR" "creator runtime env"
	require_text "$RUNBOOK" "PSW_BACKUP_DESTINATION" "backup destination env"
	require_text "$RUNBOOK" "PSW_BACKUP_ENCRYPTION" "backup encryption env"
	require_text "$RUNBOOK" "pg_dump" "PostgreSQL dump command"
	require_text "$RUNBOOK" "creator_packages" "creator package archive coverage"
	require_text "$RUNBOOK" "creator_runtime" "creator runtime archive coverage"
	require_text "$RUNBOOK" "restore drill" "restore drill requirement"
	require_text "$RUNBOOK" ".tools/production-data-backup-handoff/" "backup evidence folder"

	require_text "$BACKEND_DEPLOYMENT" "ProductionDataBackupHandoff.md" "deployment links backup handoff"
	require_text "$BACKEND_DEPLOYMENT" "PSW_PRODUCTION_BACKUP_REQUIRED=1" "deployment strict backup command"
	require_text "$BACKEND_DEPLOYMENT" "PSW_BACKUP_DESTINATION" "deployment backup destination env"
	require_text "$BACKEND_DEPLOYMENT" "PSW_BACKUP_ENCRYPTION" "deployment backup encryption env"
	require_text "$LIVEOPS_THRESHOLDS" "check_production_data_backup_handoff.sh" "LiveOps alpha gate includes backup handoff"
	require_text "$MVP_SCORE" "Production data backup handoff" "MVP score mentions backup handoff"

	require_text "$PRODUCTION_CONFIG" 'package_artifacts_dir: "/var/lib/pixel-social-world/creator_packages"' "production creator artifacts path"
	require_text "$PRODUCTION_CONFIG" 'package_install_dir: "/var/lib/pixel-social-world/creator_runtime"' "production creator runtime path"
	require_text "$PRODUCTION_CONFIG" 'dsn: ""' "production DSN remains external"
	require_text "$ENV_EXAMPLE" "PSW_POSTGRES_DSN=" "env example PostgreSQL DSN"
	require_text "$ENV_EXAMPLE" "PSW_PACKAGE_ARTIFACT_DIR=/var/lib/pixel-social-world/creator_packages" "env example creator artifact dir"
	require_text "$ENV_EXAMPLE" "PSW_PACKAGE_INSTALL_DIR=/var/lib/pixel-social-world/creator_runtime" "env example creator runtime dir"
	require_text "$INSTALL_SCRIPT" '$STATE_ROOT/creator_packages' "installer creates creator artifact dir"
	require_text "$INSTALL_SCRIPT" '$STATE_ROOT/creator_runtime' "installer creates creator runtime dir"
}

check_no_committed_backup_artifacts() {
	local matches
	matches="$(git -C "$ROOT_DIR" ls-files | grep -E '(\.dump|\.pgdump|\.backup|\.sql(\.gz)?|creator_packages.*\.(tgz|tar|zip)|creator_runtime.*\.(tgz|tar|zip))$' || true)"
	if [[ -z "$matches" ]]; then
		pass "no committed database dumps or creator backup archives found"
	else
		fail "committed backup-like artifacts found: $matches"
	fi
}

check_default_or_strict_env() {
	local dsn="${PSW_POSTGRES_DSN:-}"
	local artifact_dir="${PSW_PACKAGE_ARTIFACT_DIR:-}"
	local install_dir="${PSW_PACKAGE_INSTALL_DIR:-}"
	local destination="${PSW_BACKUP_DESTINATION:-}"
	local encryption="${PSW_BACKUP_ENCRYPTION:-}"

	if [[ "$REQUIRED" != "1" && -z "$dsn$artifact_dir$install_dir$destination$encryption" ]]; then
		pass "production backup env is external and currently unset"
		return
	fi

	if is_placeholder_or_empty "$dsn"; then
		fail "PSW_POSTGRES_DSN must be configured for strict backup handoff"
	elif [[ "$dsn" == postgres://* || "$dsn" == postgresql://* ]]; then
		pass "PSW_POSTGRES_DSN is a PostgreSQL URL"
	else
		fail "PSW_POSTGRES_DSN must start with postgres:// or postgresql://"
	fi

	for entry in \
		"PSW_PACKAGE_ARTIFACT_DIR:$artifact_dir" \
		"PSW_PACKAGE_INSTALL_DIR:$install_dir" \
		"PSW_BACKUP_DESTINATION:$destination"; do
		local name="${entry%%:*}"
		local value="${entry#*:}"
		if is_placeholder_or_empty "$value"; then
			fail "$name must be configured for strict backup handoff"
		elif ! is_absolute_path "$value"; then
			fail "$name must be an absolute path"
		elif is_repo_path "$value"; then
			fail "$name must not point inside the repo"
		elif [[ "$name" == "PSW_BACKUP_DESTINATION" ]]; then
			if is_app_install_path "$value"; then
				fail "PSW_BACKUP_DESTINATION must not point inside /opt/pixel-social-world"
			else
				pass "$name is an external absolute path"
			fi
		else
			pass "$name is an external absolute path"
		fi
	done

	if is_supported_encryption "$encryption"; then
		pass "PSW_BACKUP_ENCRYPTION is configured"
	else
		fail "PSW_BACKUP_ENCRYPTION must be configured and not none/plaintext/disabled"
	fi
}

check_strict_mode_fails_closed_when_unset() {
	if [[ "$REQUIRED" == "1" || -n "${PSW_POSTGRES_DSN:-}${PSW_PACKAGE_ARTIFACT_DIR:-}${PSW_PACKAGE_INSTALL_DIR:-}${PSW_BACKUP_DESTINATION:-}${PSW_BACKUP_ENCRYPTION:-}" ]]; then
		pass "strict backup env check is active or configured"
		return
	fi

	if PSW_PRODUCTION_BACKUP_REQUIRED=1 "$0" >/dev/null 2>&1; then
		fail "strict production backup mode unexpectedly passed without backup env"
	else
		pass "strict production backup mode fails closed without backup env"
	fi
}

check_committed_contract
check_no_committed_backup_artifacts
check_default_or_strict_env
check_strict_mode_fails_closed_when_unset

if [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
	pass "production data backup handoff has no warnings"
elif [[ "$fail_count" -eq 0 ]]; then
	warn "production data backup handoff passed with warnings"
fi

printf '\nProduction data backup handoff: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
