package gateway

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/chat"
)

func (s *Server) sendChat(ctx *gin.Context) {
	var request chat.SendRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.SenderID)
	if !ok {
		return
	}
	request.SenderID = playerID
	request.RoomID = normalizeGatewayRoomID(request.RoomID)
	if !s.requireRoomAccess(ctx, playerID, request.RoomID) {
		return
	}
	message, err := s.chatService.Send(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s.roomHub.BroadcastChat(message.RoomID, message)
	ctx.JSON(http.StatusOK, message)
}

func (s *Server) chatHistory(ctx *gin.Context) {
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
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
	messages, err := s.chatService.History(ctx.Request.Context(), chat.HistoryRequest{
		RoomID:    roomID,
		ChannelID: ctx.Param("channel_id"),
		Limit:     limit,
	})
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"messages": messages})
}

func (s *Server) reportChat(ctx *gin.Context) {
	var request chat.ReportRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.ReporterID)
	if !ok {
		return
	}
	request.ReporterID = playerID
	request.RoomID = normalizeGatewayRoomID(request.RoomID)
	if !s.requireRoomAccess(ctx, playerID, request.RoomID) {
		return
	}
	report, err := s.chatService.Report(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusAccepted, report)
}

func (s *Server) reportPlayer(ctx *gin.Context) {
	var request chat.PlayerReportRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.ReporterID)
	if !ok {
		return
	}
	request.ReporterID = playerID
	request.ContextRoomID = normalizeGatewayRoomID(request.ContextRoomID)
	if !s.requireRoomAccess(ctx, playerID, request.ContextRoomID) {
		return
	}
	report, err := s.chatService.ReportPlayer(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusAccepted, report)
}
