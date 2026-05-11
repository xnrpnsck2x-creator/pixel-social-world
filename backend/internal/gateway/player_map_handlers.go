package gateway

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/player"
)

type discoverMapRequest struct {
	PlayerID string `json:"player_id"`
	MapID    string `json:"map_id"`
	Source   string `json:"source"`
}

type syncDiscoveredMapsRequest struct {
	PlayerID string   `json:"player_id"`
	MapIDs   []string `json:"map_ids"`
	Source   string   `json:"source"`
}

type adminDiscoverMapRequest struct {
	PlayerID string `json:"player_id"`
	MapID    string `json:"map_id"`
	Confirm  bool   `json:"confirm"`
	Note     string `json:"note"`
}

func (s *Server) discoveredMaps(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	discovered, err := s.playerService.DiscoveredMaps(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(playerMapErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, discovered)
}

func (s *Server) discoverMap(ctx *gin.Context) {
	var request discoverMapRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	source := playerMapDiscoverSource(request.Source)
	if source == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "source_required"})
		return
	}
	discovered, err := s.playerService.DiscoverMap(ctx.Request.Context(), playerID, request.MapID, source)
	if err != nil {
		ctx.JSON(playerMapErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, discovered)
}

func (s *Server) syncDiscoveredMaps(ctx *gin.Context) {
	var request syncDiscoveredMapsRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	source := playerMapSyncSource(request.Source)
	if source == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "source_required"})
		return
	}
	discovered, err := s.playerService.SyncDiscoveredMaps(ctx.Request.Context(), playerID, request.MapIDs, source)
	if err != nil {
		ctx.JSON(playerMapErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, discovered)
}

func (s *Server) adminDiscoverMap(ctx *gin.Context) {
	if !s.requireAdminRole(ctx, AdminRoleOwner) {
		return
	}
	var request adminDiscoverMapRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	if !requireConfirmedAction(ctx, "map_unlock", request.Confirm) {
		return
	}
	discovered, err := s.playerService.DiscoverMap(
		ctx.Request.Context(),
		request.PlayerID,
		request.MapID,
		player.SourceAdmin,
	)
	if err != nil {
		ctx.JSON(playerMapErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	s.recordAdminAction(ctx, adminActionAuditEvent{
		Action:     "player_map.discover",
		TargetType: "player_map",
		TargetID:   request.PlayerID + ":" + request.MapID,
		Status:     "unlocked",
		Note:       request.Note,
		Confirmed:  request.Confirm,
		Metadata: adminActionMetadata(map[string]any{
			"player_id": request.PlayerID,
			"map_id":    request.MapID,
			"source":    player.SourceAdmin,
		}),
	})
	ctx.JSON(http.StatusOK, gin.H{
		"player_id":   discovered.PlayerID,
		"map_id":      request.MapID,
		"source":      player.SourceAdmin,
		"operator_id": adminReviewerID(ctx),
		"note":        strings.TrimSpace(request.Note),
		"discovered":  discovered,
	})
}

func playerMapErrorStatus(err error) int {
	switch err.Error() {
	case "player_required", "map_required", "source_required":
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}

func playerMapDiscoverSource(source string) string {
	source = strings.TrimSpace(source)
	if source == "" {
		return player.SourceArrival
	}
	switch source {
	case player.SourceArrival, player.SourceNPC, player.SourceItem, player.SourceEvent:
		return source
	default:
		return ""
	}
}

func playerMapSyncSource(source string) string {
	source = strings.TrimSpace(source)
	if source == "" || source == player.SourceSync {
		return player.SourceSync
	}
	return ""
}
