package gateway

import (
	"context"
	"strings"
	"time"

	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/minigame"
)

const liveOpsThresholdVersion = "public-alpha-2026-05-05"

type liveOpsAlert struct {
	Area     string `json:"area"`
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Value    int64  `json:"value"`
	Warning  int64  `json:"warning"`
	Critical int64  `json:"critical"`
	Message  string `json:"message"`
}

type liveOpsAlertState struct {
	GeneratedAt        int64             `json:"generated_at"`
	ThresholdsVersion  string            `json:"thresholds_version"`
	HighestSeverity    string            `json:"highest_severity"`
	Count              int               `json:"count"`
	OpenReports        int               `json:"open_reports"`
	AdminMissingNotes  int               `json:"admin_missing_notes"`
	MovementCulledRate int64             `json:"movement_culled_rate"`
	Trade              tradeRiskSnapshot `json:"trade"`
	Items              []liveOpsAlert    `json:"items"`
}

func (s *Server) liveOpsAlertSnapshot(
	ctx context.Context,
	roomSnapshot map[string]interface{},
	chatStats chat.Stats,
	fishingStats minigame.FishingRewardStats,
	economyStats economy.Stats,
) liveOpsAlertState {
	realtime := roomSnapshot["realtime"]
	openReports := s.openChatReportCount(ctx)
	missingNotes := s.adminMissingNotesCount()
	culledRate := movementCulledRate(realtime)
	tradeRisk := s.tradeRiskSnapshot(ctx)
	items := []liveOpsAlert{}
	items = appendTradeRiskAlerts(items, tradeRisk)
	items = appendAlert(items, "economy", "daily_reward_cap_hits", int64(economyStats.RewardCapHits), 25, 100, "Reward caps are hitting frequently.")
	items = appendAlert(items, "economy", "fishing_reward_caps", fishingStats.Capped, 25, 100, "Fishing rewards are repeatedly capped.")
	items = appendAlert(items, "realtime", "ws_failed_writes", int64MapValue(realtime, "write_failed"), 10, 40, "WebSocket failed writes need room drilldown.")
	items = appendAlert(items, "realtime", "movement_culled_ratio", culledRate, 35, 60, "Movement culling is high for current delivery targets.")
	items = appendAlert(items, "moderation", "open_chat_reports", int64(openReports), 20, 50, "Open chat reports are above the alpha review target.")
	items = appendAlert(items, "admin", "admin_missing_notes", int64(missingNotes), 1, 1, "High-risk admin actions must include operator notes.")
	return liveOpsAlertState{
		GeneratedAt:        time.Now().Unix(),
		ThresholdsVersion:  liveOpsThresholdVersion,
		HighestSeverity:    highestAlertSeverity(items),
		Count:              len(items),
		OpenReports:        openReports,
		AdminMissingNotes:  missingNotes,
		MovementCulledRate: culledRate,
		Trade:              tradeRisk,
		Items:              items,
	}
}

func appendTradeRiskAlerts(items []liveOpsAlert, risk tradeRiskSnapshot) []liveOpsAlert {
	counters := risk.Counters
	events := risk.Events
	items = appendAlert(items, "trade", "listing_race_or_inactive", counters.BuyInactive, 3, 10, "Repeated inactive buy attempts suggest race-lost purchases or stale listings.")
	if events.Completed >= 5 {
		items = appendAlert(items, "trade", "cancel_rate", events.CancelRate, 45, 70, "Recent trade cancellations are high compared with completed sales.")
	}
	items = appendAlert(items, "trade", "high_price_active_listings", int64(events.HighPriceActiveListings), 2, 5, "High-price active listings need economy review before public alpha.")
	items = appendAlert(items, "trade", "settlement_failures", counters.SettlementFailures, 1, 3, "Trade settlement failures require immediate escrow and transfer audit.")
	return items
}

func (s *Server) openChatReportCount(ctx context.Context) int {
	snapshot, err := s.chatService.Reports(ctx, chat.ReportListRequest{Status: chat.ReportStatusOpen, Limit: 100})
	if err != nil {
		return 0
	}
	return len(snapshot.Items)
}

func (s *Server) adminMissingNotesCount() int {
	s.adminActionAuditMu.Lock()
	defer s.adminActionAuditMu.Unlock()
	count := 0
	for _, event := range s.adminActionAuditEvents {
		if highRiskAdminActionNeedsNote(event) && strings.TrimSpace(event.Note) == "" {
			count++
		}
	}
	return count
}

func highRiskAdminActionNeedsNote(event adminActionAuditEvent) bool {
	switch event.Action {
	case "player_map.discover":
		return true
	case "chat_moderation.apply":
		return event.Status == chat.ModerationActionBan
	case "minigame.review":
		operation := strings.TrimSpace(stringMapValue(event.Metadata, "operation"))
		return operation == "rollback" || operation == "unpublish"
	default:
		return false
	}
}

func appendAlert(items []liveOpsAlert, area string, code string, value int64, warning int64, critical int64, message string) []liveOpsAlert {
	severity := ""
	if critical > 0 && value >= critical {
		severity = "critical"
	} else if warning > 0 && value >= warning {
		severity = "warning"
	}
	if severity == "" {
		return items
	}
	return append(items, liveOpsAlert{Area: area, Code: code, Severity: severity, Value: value, Warning: warning, Critical: critical, Message: message})
}

func highestAlertSeverity(items []liveOpsAlert) string {
	highest := "ok"
	for _, item := range items {
		if item.Severity == "critical" {
			return "critical"
		}
		if item.Severity == "warning" {
			highest = "warning"
		}
	}
	return highest
}

func movementCulledRate(realtime interface{}) int64 {
	target := int64MapValue(realtime, "local_delivery_target")
	if target <= 0 {
		return 0
	}
	return int64MapValue(realtime, "movement_culled") * 100 / target
}

func int64MapValue(data interface{}, key string) int64 {
	switch typed := data.(type) {
	case map[string]int64:
		return typed[key]
	case map[string]interface{}:
		return anyInt64(typed[key])
	default:
		return 0
	}
}

func anyInt64(value interface{}) int64 {
	switch typed := value.(type) {
	case int64:
		return typed
	case int:
		return int64(typed)
	case float64:
		return int64(typed)
	default:
		return 0
	}
}

func stringMapValue(data map[string]any, key string) string {
	value, ok := data[key]
	if !ok {
		return ""
	}
	if typed, ok := value.(string); ok {
		return strings.TrimSpace(typed)
	}
	return ""
}
