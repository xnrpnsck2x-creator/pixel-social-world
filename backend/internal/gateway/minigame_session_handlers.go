package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
)

func (s *Server) createMinigameSession(ctx *gin.Context) {
	var request minigame.CreateSessionRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.HostPlayerID)
	if !ok {
		return
	}
	request.HostPlayerID = playerID
	request.RoomID = normalizeGatewayRoomID(request.RoomID)
	if !s.requireRoomAccess(ctx, playerID, request.RoomID) {
		return
	}
	session, err := s.minigameService.CreateSession(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusCreated, session)
}

func (s *Server) listMinigameSessions(ctx *gin.Context) {
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
	sessions := s.minigameService.ListSessions(ctx.Request.Context(), roomID)
	ctx.JSON(http.StatusOK, gin.H{"sessions": sessions})
}

func (s *Server) joinMinigameSession(ctx *gin.Context) {
	var request minigame.JoinSessionRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.SessionID = ctx.Param("session_id")
	request.PlayerID = playerID
	session, err := s.minigameService.JoinSession(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, session)
}

func (s *Server) leaveMinigameSession(ctx *gin.Context) {
	var request minigame.LeaveSessionRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.SessionID = ctx.Param("session_id")
	request.PlayerID = playerID
	session, err := s.minigameService.LeaveSession(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, session)
}

func (s *Server) endMinigameSession(ctx *gin.Context) {
	sessionID := ctx.Param("session_id")
	existing, ok := s.minigameService.GetSession(ctx.Request.Context(), sessionID)
	if !ok {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "session_not_found"})
		return
	}
	if _, ok := s.requireAuthorizedPlayer(ctx, existing.HostPlayerID); !ok {
		return
	}
	session, err := s.minigameService.EndSession(ctx.Request.Context(), sessionID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, session)
}
