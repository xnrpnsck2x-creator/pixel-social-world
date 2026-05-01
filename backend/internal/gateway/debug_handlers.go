package gateway

import (
	"net/http"

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
	ctx.JSON(http.StatusOK, gin.H{
		"request_id":             requestID(ctx),
		"rooms":                  roomSnapshot,
		"realtime":               roomSnapshot["realtime"],
		"chat":                   s.chatService.Stats(ctx.Request.Context()),
		"fishing_rewards":        s.fishingRewards.Stats(ctx.Request.Context()),
		"economy_policy":         s.economyService.Policy(),
		"retention_policy":       s.retentionPolicy,
		"retention_cleanup_plan": ops.BuildRetentionCleanupPlan(s.retentionPolicy),
	})
}
