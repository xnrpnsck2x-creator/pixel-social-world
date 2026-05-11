#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT_DIR/docs/ProductionMonitoringHandoff.md"
BACKEND_DEPLOYMENT="$ROOT_DIR/docs/BackendDeployment.md"
LIVEOPS_THRESHOLDS="$ROOT_DIR/docs/LiveOpsRiskThresholds.md"
BACKEND_CONTRACT="$ROOT_DIR/docs/BackendContract.md"
PROBE_SCRIPT="$ROOT_DIR/backend/deploy/pixel-social-world-liveops-alert-probe.sh"
ALERT_SERVICE="$ROOT_DIR/backend/deploy/pixel-social-world-liveops-alerts.service"
ALERT_TIMER="$ROOT_DIR/backend/deploy/pixel-social-world-liveops-alerts.timer"
BACKEND_SERVICE="$ROOT_DIR/backend/deploy/pixel-social-world.service"
PACKAGE_SCRIPT="$ROOT_DIR/backend/scripts/package-cloudflare-free-launch.sh"
ENV_EXAMPLE="$ROOT_DIR/backend/deploy/pixel-social-world.env.example"
REQUIRED="${PSW_PRODUCTION_MONITORING_REQUIRED:-0}"

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
	[[ -z "$value" || "$value" == *"change_me"* || "$value" == *"<"* || "$value" == *">"* ]]
}

is_supported_format() {
	[[ "$1" == "json" || "$1" == "prometheus" ]]
}

check_committed_contract() {
	require_file_nonempty "docs/ProductionMonitoringHandoff.md"
	require_file_nonempty "docs/LiveOpsRiskThresholds.md"
	require_file_nonempty "docs/BackendDeployment.md"
	require_file_nonempty "docs/BackendContract.md"
	require_file_nonempty "backend/deploy/pixel-social-world-liveops-alert-probe.sh"
	require_file_nonempty "backend/deploy/pixel-social-world-liveops-alerts.service"
	require_file_nonempty "backend/deploy/pixel-social-world-liveops-alerts.timer"
	require_file_nonempty "backend/deploy/pixel-social-world.service"
	require_file_nonempty "backend/scripts/package-cloudflare-free-launch.sh"
	require_file_nonempty "backend/deploy/pixel-social-world.env.example"

	require_text "$RUNBOOK" "Do not commit production admin tokens" "no committed monitoring secrets rule"
	require_text "$RUNBOOK" "GET /healthz" "health probe contract"
	require_text "$RUNBOOK" "GET /readyz" "readiness probe contract"
	require_text "$RUNBOOK" "GET /debug/ops/alerts" "alerts endpoint contract"
	require_text "$RUNBOOK" "format=prometheus" "prometheus alert mode"
	require_text "$RUNBOOK" "emit_log=1" "alert heartbeat logging"
	require_text "$RUNBOOK" "PSW_PRODUCTION_MONITORING_REQUIRED=1" "strict monitoring flag"
	require_text "$RUNBOOK" "PSW_LIVEOPS_ALERT_ENDPOINT" "alert endpoint env"
	require_text "$RUNBOOK" "PSW_LIVEOPS_ALERT_TOKEN" "alert token env"
	require_text "$RUNBOOK" "PSW_LIVEOPS_ALERT_FORMAT" "alert format env"
	require_text "$RUNBOOK" "PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS" "alert timeout env"
	require_text "$RUNBOOK" ".tools/production-monitoring-handoff/" "monitoring evidence folder"

	require_text "$BACKEND_CONTRACT" "GET /healthz" "backend healthz docs"
	require_text "$BACKEND_CONTRACT" "GET /readyz" "backend readyz docs"
	require_text "$BACKEND_CONTRACT" "GET /debug/ops/alerts" "backend alerts docs"
	require_text "$BACKEND_CONTRACT" "liveops_alert_snapshot" "backend alert log docs"
	require_text "$BACKEND_CONTRACT" "psw_liveops_alerts_active" "backend prometheus docs"

	require_text "$LIVEOPS_THRESHOLDS" "pixel-social-world-liveops-alert-probe.sh" "thresholds probe script docs"
	require_text "$LIVEOPS_THRESHOLDS" "pixel-social-world-liveops-alerts.service" "thresholds alert service docs"
	require_text "$LIVEOPS_THRESHOLDS" "pixel-social-world-liveops-alerts.timer" "thresholds alert timer docs"
	require_text "$BACKEND_DEPLOYMENT" "pixel-social-world-liveops-alert-probe" "deployment probe install docs"
	require_text "$BACKEND_DEPLOYMENT" "journalctl -u pixel-social-world-liveops-alerts" "deployment journal docs"

	require_text "$PROBE_SCRIPT" "X-Admin-Token" "probe sends admin token header"
	require_text "$PROBE_SCRIPT" "--config -" "probe keeps token out of process args"
	require_text "$PROBE_SCRIPT" "emit_log=1" "probe forces alert heartbeat"
	require_text "$PROBE_SCRIPT" "format=prometheus" "probe supports prometheus mode"
	require_text "$ALERT_SERVICE" "EnvironmentFile=/etc/pixel-social-world/backend.env" "alert service reads env file"
	require_text "$ALERT_SERVICE" "NoNewPrivileges=true" "alert service hardened"
	require_text "$ALERT_TIMER" "OnUnitActiveSec=60s" "alert timer runs every minute"
	require_text "$BACKEND_SERVICE" "ExecStartPre=/opt/pixel-social-world/backend/bin/pixel-social-world-preflight -strict" "backend strict preflight"
	require_text "$PACKAGE_SCRIPT" "pixel-social-world-liveops-alert-probe" "package includes alert probe"
	require_text "$PACKAGE_SCRIPT" "pixel-social-world-liveops-alerts.service" "package includes alert service"
	require_text "$PACKAGE_SCRIPT" "pixel-social-world-liveops-alerts.timer" "package includes alert timer"
	require_text "$ENV_EXAMPLE" "PSW_LIVEOPS_ALERT_ENDPOINT=" "env example alert endpoint"
	require_text "$ENV_EXAMPLE" "PSW_LIVEOPS_ALERT_TOKEN=" "env example alert token"
	require_text "$ENV_EXAMPLE" "PSW_LIVEOPS_ALERT_FORMAT=" "env example alert format"
	require_text "$ENV_EXAMPLE" "PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS=" "env example alert timeout"
}

check_no_committed_monitoring_secrets() {
	local matches
	matches="$(grep -REn --exclude-dir=.git --exclude='ProductionMonitoringHandoff.md' \
		'(PSW_LIVEOPS_ALERT_TOKEN|MONITORING_API_KEY|WEBHOOK_SECRET|SLACK_WEBHOOK_URL|DISCORD_WEBHOOK_URL)=.+' \
		"$ROOT_DIR/backend" "$ROOT_DIR/configs" "$ROOT_DIR/docs" 2>/dev/null || true)"
	if [[ -z "$matches" ]]; then
		pass "no committed monitoring secret assignments found"
		return
	fi
	if printf '%s\n' "$matches" | grep -Ev 'PSW_LIVEOPS_ALERT_TOKEN=$|CHANGE_ME|<.*>' >/dev/null; then
		fail "committed files appear to contain monitoring secret assignments"
	else
		pass "monitoring secret assignments are empty or placeholders only"
	fi
}

check_default_or_strict_env() {
	local endpoint="${PSW_LIVEOPS_ALERT_ENDPOINT:-}"
	local token="${PSW_LIVEOPS_ALERT_TOKEN:-${PSW_ADMIN_TOKEN:-}}"
	local format="${PSW_LIVEOPS_ALERT_FORMAT:-}"
	local timeout="${PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS:-}"

	if [[ "$REQUIRED" != "1" && -z "$endpoint$token$format$timeout" ]]; then
		pass "production monitoring env is external and currently unset"
		return
	fi

	if is_placeholder_or_empty "$endpoint"; then
		fail "PSW_LIVEOPS_ALERT_ENDPOINT must be configured for strict monitoring handoff"
	elif [[ "$endpoint" != http://* && "$endpoint" != https://* ]]; then
		fail "PSW_LIVEOPS_ALERT_ENDPOINT must be an http(s) URL"
	else
		pass "PSW_LIVEOPS_ALERT_ENDPOINT is configured"
	fi

	if [[ "$endpoint" == *"/debug/ops/alerts"* ]]; then
		pass "PSW_LIVEOPS_ALERT_ENDPOINT targets /debug/ops/alerts"
	else
		fail "PSW_LIVEOPS_ALERT_ENDPOINT must target /debug/ops/alerts"
	fi

	if is_placeholder_or_empty "$token"; then
		fail "PSW_LIVEOPS_ALERT_TOKEN or PSW_ADMIN_TOKEN must be configured with a non-placeholder token"
	else
		pass "LiveOps alert token source is configured"
	fi

	if [[ -z "$format" ]]; then
		pass "PSW_LIVEOPS_ALERT_FORMAT defaults to json"
	elif is_supported_format "$format"; then
		pass "PSW_LIVEOPS_ALERT_FORMAT is supported"
	else
		fail "PSW_LIVEOPS_ALERT_FORMAT must be json or prometheus"
	fi

	if [[ -z "$timeout" ]]; then
		pass "PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS defaults to 5"
	elif [[ "$timeout" =~ ^[0-9]+$ && "$timeout" -gt 0 && "$timeout" -le 30 ]]; then
		pass "PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS is within range"
	else
		fail "PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS must be 1-30 seconds"
	fi
}

check_strict_mode_fails_closed_when_unset() {
	if [[ "$REQUIRED" == "1" || -n "${PSW_LIVEOPS_ALERT_ENDPOINT:-}${PSW_LIVEOPS_ALERT_TOKEN:-}${PSW_ADMIN_TOKEN:-}${PSW_LIVEOPS_ALERT_FORMAT:-}${PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS:-}" ]]; then
		pass "strict monitoring env check is active or configured"
		return
	fi

	if PSW_PRODUCTION_MONITORING_REQUIRED=1 "$0" >/dev/null 2>&1; then
		fail "strict production monitoring mode unexpectedly passed without monitoring env"
	else
		pass "strict production monitoring mode fails closed without monitoring env"
	fi
}

check_committed_contract
check_no_committed_monitoring_secrets
check_default_or_strict_env
check_strict_mode_fails_closed_when_unset

if [[ "$fail_count" -eq 0 && "$warn_count" -eq 0 ]]; then
	pass "production monitoring handoff has no warnings"
elif [[ "$fail_count" -eq 0 ]]; then
	warn "production monitoring handoff passed with warnings"
fi

printf '\nProduction monitoring handoff: %d failure(s), %d warning(s)\n' "$fail_count" "$warn_count"
if [[ "$fail_count" -gt 0 ]]; then
	exit 1
fi
