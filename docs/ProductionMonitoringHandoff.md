# Production Monitoring Handoff

Date: 2026-05-12

Status: Local contract ready. External monitoring receiver, production alert
token, and server-side enablement remain release-environment tasks.

## Scope

This runbook covers the production monitoring handoff for the first public alpha
single-host deployment.

It covers:

- Health and readiness checks.
- LiveOps alert endpoint polling.
- systemd probe/timer installation.
- Journald evidence and external receiver handoff.
- Rollback metrics and stop conditions.

## Non-Negotiables

- Do not commit production admin tokens, alert tokens, webhook URLs with embedded
  secrets, DSNs, or monitoring vendor API keys.
- Keep `/debug/ops` and `/debug/ops/alerts` admin-token protected.
- Do not expose LiveOps alert endpoints publicly without a private network,
  Cloudflare Access rule, or equivalent gateway protection.
- Alert probes must be read-only and must not mutate player, economy, trade,
  creator, moderation, or room state.
- A failed monitoring handoff blocks public alpha release until the operator can
  see health, readiness, and LiveOps alert state from the production host.

## Existing Backend Contract

Public process probes:

```text
GET /healthz
GET /readyz
```

Admin-only LiveOps probes:

```text
GET /debug/ops
GET /debug/ops/alerts
GET /debug/ops/alerts?format=prometheus
GET /debug/ops/alerts?emit_log=1
```

The alert payload includes the Public Alpha threshold snapshot:

- `highest_severity`
- `count`
- `items`
- `open_reports`
- `admin_missing_notes`
- `movement_culled_rate`
- trade risk counters
- threshold version

## Local Gate Before Public Alpha

Run these from the repository root:

```bash
scripts/check_production_monitoring_handoff.sh
scripts/run_project_category_v2_gate.sh
```

Expected local result:

- `check_production_monitoring_handoff.sh` passes in default mode with real
  monitoring env unset.
- `check_production_monitoring_handoff.sh` proves strict mode fails closed when
  monitoring env is absent.
- `run_project_category_v2_gate.sh` executes the monitoring handoff check as
  part of `liveops_moderation`.

## Strict Monitoring Handoff

On the production or staging host:

```bash
export PSW_PRODUCTION_MONITORING_REQUIRED=1
export PSW_LIVEOPS_ALERT_ENDPOINT="http://127.0.0.1:8787/debug/ops/alerts"
export PSW_LIVEOPS_ALERT_FORMAT="json"
export PSW_LIVEOPS_ALERT_TIMEOUT_SECONDS=5
export PSW_LIVEOPS_ALERT_TOKEN="<operator-or-owner-token>"
scripts/check_production_monitoring_handoff.sh
```

`PSW_LIVEOPS_ALERT_TOKEN` may be omitted only when `PSW_ADMIN_TOKEN` is set in
the process environment used by the probe. The systemd probe reads
`/etc/pixel-social-world/backend.env`.

Acceptance:

- `backend/deploy/pixel-social-world-liveops-alert-probe.sh` exists and uses
  `curl --config -` so tokens do not appear in the process list.
- `backend/deploy/pixel-social-world-liveops-alerts.service` reads
  `/etc/pixel-social-world/backend.env`.
- `backend/deploy/pixel-social-world-liveops-alerts.timer` runs every minute.
- `backend/deploy/pixel-social-world.service` runs strict preflight before the
  backend starts.
- `backend/scripts/package-cloudflare-free-launch.sh` includes the alert probe,
  service, and timer in release packaging.
- `docs/LiveOpsRiskThresholds.md`, `docs/BackendDeployment.md`, and
  `docs/BackendContract.md` describe the probe path.

## Operator Evidence

For every public alpha candidate, keep a local evidence folder under
`.tools/production-monitoring-handoff/<date-or-commit>/` with:

- Build commit SHA.
- `scripts/check_production_monitoring_handoff.sh` output.
- `scripts/run_project_category_v2_gate.sh` output.
- `curl /healthz` output from the production host.
- `curl /readyz` output from the production host.
- `curl /debug/ops/alerts?emit_log=1` output with secrets redacted.
- `curl /debug/ops/alerts?format=prometheus` output with secrets redacted.
- `systemctl status pixel-social-world` output.
- `systemctl status pixel-social-world-liveops-alerts.timer` output.
- `journalctl -u pixel-social-world-liveops-alerts -n 30` output.

Do not put admin tokens, alert tokens, DSNs, or webhook secrets in the evidence
folder.

## Rollout Metrics

Advance from local/public-alpha candidate only when:

- `/healthz` and `/readyz` return success from the host.
- `/debug/ops/alerts` returns `highest_severity: ok` or only known accepted
  warnings with an operator note.
- The alert timer is enabled and has run at least twice.
- Journald contains a recent `liveops_alert_snapshot` heartbeat.
- H5/browser smoke matrix has zero console errors.
- Android device regression and runtime budget evidence are still current.

Hold or roll back when:

- `/readyz` fails.
- alert severity becomes `critical`.
- WebSocket failed writes exceed the critical threshold.
- trade settlement failures repeat.
- admin action notes are missing for high-risk actions.
- open moderation reports exceed the critical threshold.
- health/readiness/alert probe evidence cannot be captured by the operator.

Rollback target is the last commit where:

```bash
scripts/check_production_monitoring_handoff.sh
scripts/run_project_category_v2_gate.sh
```

both passed.
