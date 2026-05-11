package gateway

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/ops"
)

func (s *Server) debugRooms(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	ctx.JSON(http.StatusOK, s.roomHub.DebugSnapshot())
}

func (s *Server) debugOps(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	roomSnapshot := s.roomHub.Snapshot()
	chatStats := s.chatService.Stats(ctx.Request.Context())
	fishingStats := s.fishingRewards.Stats(ctx.Request.Context())
	economyStats := s.economyService.Stats(ctx.Request.Context())
	creatorPayouts := s.economyService.CreatorPayouts(ctx.Request.Context(), 5)
	ctx.JSON(http.StatusOK, gin.H{
		"request_id":             requestID(ctx),
		"rooms":                  roomSnapshot,
		"realtime":               roomSnapshot["realtime"],
		"chat":                   chatStats,
		"fishing_rewards":        fishingStats,
		"economy":                economyStats,
		"creator_payouts":        creatorPayouts,
		"economy_policy":         s.economyService.Policy(),
		"admin_action_audit":     s.adminActionAuditStats(),
		"retention_policy":       s.retentionPolicy,
		"retention_cleanup_plan": ops.BuildRetentionCleanupPlan(s.retentionPolicy),
		"alerts":                 s.liveOpsAlertSnapshot(ctx.Request.Context(), roomSnapshot, chatStats, fishingStats, economyStats),
	})
}

func (s *Server) debugOpsAlerts(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	alerts := s.liveOpsAlertSnapshotFromServices(ctx.Request.Context())
	s.writeLiveOpsAlertLog(ctx, alerts)
	if strings.EqualFold(strings.TrimSpace(ctx.Query("format")), "prometheus") {
		ctx.Header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		ctx.String(http.StatusOK, liveOpsAlertMetrics(alerts))
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"request_id": requestID(ctx),
		"alerts":     alerts,
	})
}
