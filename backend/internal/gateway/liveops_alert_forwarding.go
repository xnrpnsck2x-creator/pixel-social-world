package gateway

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func (s *Server) liveOpsAlertSnapshotFromServices(ctx context.Context) liveOpsAlertState {
	roomSnapshot := s.roomHub.Snapshot()
	return s.liveOpsAlertSnapshot(
		ctx,
		roomSnapshot,
		s.chatService.Stats(ctx),
		s.fishingRewards.Stats(ctx),
		s.economyService.Stats(ctx),
	)
}

func (s *Server) writeLiveOpsAlertLog(ctx *gin.Context, alerts liveOpsAlertState) {
	if alerts.Count <= 0 && ctx.Query("emit_log") != "1" {
		return
	}
	level := "warn"
	if alerts.HighestSeverity == "critical" {
		level = "error"
	} else if alerts.HighestSeverity == "ok" {
		level = "info"
	}
	entry := map[string]any{
		"ts":                   time.Now().UTC().Format(time.RFC3339Nano),
		"level":                level,
		"event":                "liveops_alert_snapshot",
		"request_id":           requestID(ctx),
		"highest_severity":     alerts.HighestSeverity,
		"count":                alerts.Count,
		"thresholds_version":   alerts.ThresholdsVersion,
		"open_reports":         alerts.OpenReports,
		"admin_missing_notes":  alerts.AdminMissingNotes,
		"movement_culled_rate": alerts.MovementCulledRate,
		"items":                liveOpsAlertLogItems(alerts.Items),
	}
	_ = json.NewEncoder(gin.DefaultWriter).Encode(entry)
}

func liveOpsAlertLogItems(items []liveOpsAlert) []map[string]any {
	rows := make([]map[string]any, 0, len(items))
	for _, item := range items {
		rows = append(rows, map[string]any{
			"area":     item.Area,
			"code":     item.Code,
			"severity": item.Severity,
			"value":    item.Value,
			"warning":  item.Warning,
			"critical": item.Critical,
		})
	}
	return rows
}

func liveOpsAlertMetrics(alerts liveOpsAlertState) string {
	var builder strings.Builder
	writeMetricHelp(&builder, "psw_liveops_alerts_active", "Active LiveOps alert count.")
	writeMetric(&builder, "psw_liveops_alerts_active", nil, int64(alerts.Count))
	writeMetricHelp(&builder, "psw_liveops_alerts_severity", "Highest LiveOps severity as 0 ok, 1 warning, 2 critical.")
	writeMetric(&builder, "psw_liveops_alerts_severity", nil, severityScore(alerts.HighestSeverity))
	writeMetricHelp(&builder, "psw_liveops_alert_item", "Active LiveOps alert item by area, code, and severity.")
	for _, item := range alerts.Items {
		writeMetric(&builder, "psw_liveops_alert_item", map[string]string{
			"area":     item.Area,
			"code":     item.Code,
			"severity": item.Severity,
		}, item.Value)
	}
	writeMetric(&builder, "psw_liveops_open_chat_reports", nil, int64(alerts.OpenReports))
	writeMetric(&builder, "psw_liveops_admin_missing_notes", nil, int64(alerts.AdminMissingNotes))
	writeMetric(&builder, "psw_liveops_movement_culled_rate_percent", nil, alerts.MovementCulledRate)
	writeMetric(&builder, "psw_liveops_trade_buy_inactive_total", nil, alerts.Trade.Counters.BuyInactive)
	writeMetric(&builder, "psw_liveops_trade_settlement_failures_total", nil, alerts.Trade.Counters.SettlementFailures)
	writeMetric(&builder, "psw_liveops_trade_cancel_rate_percent", nil, alerts.Trade.Events.CancelRate)
	writeMetric(&builder, "psw_liveops_trade_high_price_active_listings", nil, int64(alerts.Trade.Events.HighPriceActiveListings))
	return builder.String()
}

func severityScore(severity string) int64 {
	switch severity {
	case "critical":
		return 2
	case "warning":
		return 1
	default:
		return 0
	}
}

func writeMetricHelp(builder *strings.Builder, name string, help string) {
	builder.WriteString("# HELP ")
	builder.WriteString(name)
	builder.WriteByte(' ')
	builder.WriteString(help)
	builder.WriteByte('\n')
	builder.WriteString("# TYPE ")
	builder.WriteString(name)
	builder.WriteString(" gauge\n")
}

func writeMetric(builder *strings.Builder, name string, labels map[string]string, value int64) {
	builder.WriteString(name)
	if len(labels) > 0 {
		builder.WriteByte('{')
		index := 0
		for key, labelValue := range labels {
			if index > 0 {
				builder.WriteByte(',')
			}
			builder.WriteString(metricLabelName(key))
			builder.WriteString("=\"")
			builder.WriteString(metricLabelValue(labelValue))
			builder.WriteByte('"')
			index++
		}
		builder.WriteByte('}')
	}
	builder.WriteByte(' ')
	builder.WriteString(strconv.FormatInt(value, 10))
	builder.WriteByte('\n')
}

func metricLabelName(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "label"
	}
	var builder strings.Builder
	for _, char := range value {
		if char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' || char >= '0' && char <= '9' || char == '_' {
			builder.WriteRune(char)
			continue
		}
		builder.WriteByte('_')
	}
	return builder.String()
}

func metricLabelValue(value string) string {
	return strings.ReplaceAll(fmt.Sprintf("%s", value), `"`, `\"`)
}
