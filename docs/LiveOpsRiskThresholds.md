# LiveOps Risk Thresholds

Status: Public Alpha baseline, alert forwarding and systemd probe v1
implemented 2026-05-06.

This document defines the first production alert targets for the single-host
MVP. The current code exposes enough data through Debug Ops, audit endpoints,
CSV exports, access logs, and service counters to inspect these manually; the
current `/debug/ops.alerts` payload wires the highest-risk subset into the
LiveOps console. The production deploy sample now includes a systemd timer that
polls the forwarding endpoint into journald; a metrics collector or external
alert service can consume the same endpoint later.

## Policy

- Warning: investigate in the same operator session.
- Critical: stop the affected rollout path, capture CSV/audit evidence, and
  disable the risky public entry point if the issue repeats.
- All thresholds are per single Linux amd64 host unless noted.
- CSV exports must remain paged; do not add full-table admin downloads for MVP.

## Thresholds

| Area | Signal | Warning | Critical | First response |
| --- | --- | ---: | ---: | --- |
| Trade | `listing_inactive` or race-lost buy failures | 3 process-lifetime hits | 10 process-lifetime hits | Export `/admin/trade/history?format=csv`, inspect listing IDs, and check client refresh behavior. |
| Trade | Recent cancel ratio | 45% once 5 sold/cancelled events exist | 70% once 5 sold/cancelled events exist | Review seller inventory locks and recent listings before taking action. |
| Trade | Active listings priced at 8000+ coins | 2 | 5 | Review whether high-price listings are accidental, exploit-driven, or expected collector pricing. |
| Trade | Trade settlement failures | 1 process-lifetime hit | 3 process-lifetime hits | Pause trade market entry if repeated, then inspect escrow, ledger, and inventory transfer rows. |
| Economy | Daily reward cap hits | 25/hour | 100/hour | Check Debug Ops cap counters and compare with active-user count. |
| Economy | Creator payout settlements failing | 1/hour | 3/hour | Pause settlement retries for the affected creator and preserve ledger rows. |
| Realtime | WebSocket failed writes | 10/min | 40/min | Inspect room drilldown, active room size, and host socket pressure. |
| Realtime | Dense-room movement culling ratio | 35% for 10 min | 60% for 10 min | Lower room cap or split event traffic before increasing send rate. |
| Moderation | Open chat reports | 20 | 50 | Triage oldest reports first, then export moderation CSV for handoff. |
| Admin audit | High-risk admin actions without notes | 1 | 1 | Treat as policy violation; notes are required for rollback, unpublish, ban, and forced grants. |
| Cleanup | Retention dry-run shows delete backlog | 1000 rows | 10000 rows | Run dry-run again, then execute cleanup during low traffic if counts match expectations. |
| H5 client | Browser console errors in smoke matrix | 1 run | 2 consecutive runs | Block release candidate and attach screenshots/logs to the release note. |

## Wired In `/debug/ops.alerts`

- Trade inactive buy/race-lost attempts from gateway request counters.
- Recent trade cancel ratio from the server trade event stream.
- High-price active trade listings from current listing state.
- Trade settlement failures from unexpected buy-path errors.
- Economy daily reward cap hits.
- Fishing reward caps.
- WebSocket failed writes.
- Movement culling ratio.
- Open chat reports.
- High-risk admin actions missing required notes.

Creator settlement failures, cleanup delete backlog, and H5 smoke console
errors remain documented operator checks until those sources have durable
counters.

## Forwarding

`GET /debug/ops/alerts` exposes the alert snapshot without the heavier Debug
Ops payload. It is intended for a simple authenticated poller, such as a
systemd timer, cron job, or small metrics collector.

- JSON mode returns `{ request_id, alerts }`.
- `format=prometheus` returns text metrics such as
  `psw_liveops_alerts_active`, `psw_liveops_alerts_severity`,
  `psw_liveops_alert_item`, and selected trade/moderation counters.
- The endpoint writes a structured `liveops_alert_snapshot` JSON log line when
  active alerts exist; `emit_log=1` forces a log line for heartbeat checks.
- Keep the endpoint admin-token protected. Do not expose it publicly without a
  private network or gateway rule.

Ubuntu sample files:

- `backend/deploy/pixel-social-world-liveops-alert-probe.sh`
- `backend/deploy/pixel-social-world-liveops-alerts.service`
- `backend/deploy/pixel-social-world-liveops-alerts.timer`

The timer runs every minute. It reads `/etc/pixel-social-world/backend.env`,
uses `PSW_LIVEOPS_ALERT_TOKEN` or falls back to `PSW_ADMIN_TOKEN`, and writes the
endpoint response plus the backend's structured alert heartbeat into journald.
Check it with:

```bash
systemctl status pixel-social-world-liveops-alerts.timer
journalctl -u pixel-social-world-liveops-alerts -n 30
```

## Alpha Release Gate

Before public alpha, the operator should be able to:

1. Open LiveOps Console with a viewer token.
2. Inspect chat moderation, admin action audit, inventory audit, and trade
   history without mutating player state.
3. Export filtered moderation, reviewer, and trade CSV pages.
4. Check Debug Ops counters for rooms, realtime failures, economy caps,
   creator payouts, cleanup metadata, and admin action audit size.
5. Confirm the latest H5 smoke matrix has zero console messages.
