package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/presence"
)

func (s *Server) heartbeat(ctx *gin.Context) {
	var request presence.HeartbeatRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	request.RoomID = normalizeGatewayRoomID(request.RoomID)
	if !s.requireRoomAccess(ctx, playerID, request.RoomID) {
		return
	}
	record, err := s.presenceService.Heartbeat(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "presence_failed"})
		return
	}
	ctx.JSON(http.StatusOK, record)
}

func (s *Server) roomMembers(ctx *gin.Context) {
	roomID := normalizeGatewayRoomID(ctx.Param("room_id"))
	if restrictedGatewayRoomID(roomID) {
		playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
		if !ok {
			return
		}
		if !s.requireRoomAccess(ctx, playerID, roomID) {
			return
		}
	}
	members, err := s.presenceService.RoomMembers(ctx.Request.Context(), roomID)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "presence_failed"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"members": members})
}
