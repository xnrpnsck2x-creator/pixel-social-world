package gateway

import (
	"context"
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
	catalog, err := s.sessionGameCatalog(ctx.Request.Context())
	if err != nil {
		ctx.JSON(http.StatusServiceUnavailable, gin.H{"error": "minigame_catalog_unavailable"})
		return
	}
	maxPlayers, available := catalog[request.GameID]
	if !available {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "game_unavailable"})
		return
	}
	if request.MaxPlayers <= 0 || request.MaxPlayers > maxPlayers {
		request.MaxPlayers = maxPlayers
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
	catalog, err := s.sessionGameCatalog(ctx.Request.Context())
	if err != nil {
		ctx.JSON(http.StatusServiceUnavailable, gin.H{"error": "minigame_catalog_unavailable"})
		return
	}
	sessions := s.minigameService.ListSessions(ctx.Request.Context(), roomID)
	visible := make([]minigame.Session, 0, len(sessions))
	for _, session := range sessions {
		if _, available := catalog[session.GameID]; available {
			visible = append(visible, session)
		}
	}
	ctx.JSON(http.StatusOK, gin.H{"sessions": visible})
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
	if session, exists := s.minigameService.GetSession(ctx.Request.Context(), request.SessionID); exists {
		catalog, err := s.sessionGameCatalog(ctx.Request.Context())
		if err != nil {
			ctx.JSON(http.StatusServiceUnavailable, gin.H{"error": "minigame_catalog_unavailable"})
			return
		}
		if _, available := catalog[session.GameID]; !available {
			ctx.JSON(http.StatusGone, gin.H{"error": "game_unavailable"})
			return
		}
	}
	session, err := s.minigameService.JoinSession(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, session)
}

func (s *Server) sessionGameCatalog(ctx context.Context) (map[string]int, error) {
	catalog := map[string]int{"fishing": 4}
	published, err := s.minigameService.ListPublishedPackages(ctx)
	if err != nil {
		return nil, err
	}
	for _, install := range published {
		if install.Status != "installed" || install.GameID == "" || install.MaxPlayers <= 0 {
			continue
		}
		if _, err := s.minigameService.PublishedRuntime(ctx, install.GameID); err != nil {
			continue
		}
		catalog[install.GameID] = install.MaxPlayers
	}
	return catalog, nil
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
