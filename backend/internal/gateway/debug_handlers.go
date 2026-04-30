package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
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
		"request_id":      requestID(ctx),
		"rooms":           roomSnapshot,
		"realtime":        roomSnapshot["realtime"],
		"chat":            s.chatService.Stats(ctx.Request.Context()),
		"fishing_rewards": s.fishingRewards.Stats(ctx.Request.Context()),
	})
}
