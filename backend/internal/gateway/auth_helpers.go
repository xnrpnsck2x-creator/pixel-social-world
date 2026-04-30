package gateway

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const defaultGatewayRoomID = "world_town_square"

func (s *Server) requireAuthorizedPlayer(ctx *gin.Context, playerID string) (string, bool) {
	if playerID == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "player_required"})
		return "", false
	}
	token := bearerAccessToken(ctx.GetHeader("Authorization"))
	if !s.authService.ValidateAccessToken(ctx.Request.Context(), playerID, token) {
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return "", false
	}
	return playerID, true
}

func (s *Server) requireRoomAccess(ctx *gin.Context, playerID string, roomID string) bool {
	if NewRoomAuthorizer(s.minigameService).CanJoinRoom(ctx.Request.Context(), playerID, roomID) {
		return true
	}
	ctx.JSON(http.StatusForbidden, gin.H{"error": "room_forbidden"})
	return false
}

func (s *Server) requireAdmin(ctx *gin.Context) bool {
	return s.requireAdminRole(ctx, AdminRoleViewer)
}

func adminCredential(ctx *gin.Context) string {
	token := ctx.GetHeader("X-Admin-Token")
	if token == "" {
		token = bearerAccessToken(ctx.GetHeader("Authorization"))
	}
	return token
}

func adminReviewerID(ctx *gin.Context) string {
	token := adminCredential(ctx)
	if token == "" {
		return "admin:unknown"
	}
	digest := sha256.Sum256([]byte(token))
	return "admin:" + hex.EncodeToString(digest[:])[:12]
}

func bearerAccessToken(header string) string {
	parts := strings.Fields(header)
	if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
		return parts[1]
	}
	return ""
}

func normalizeGatewayRoomID(roomID string) string {
	if roomID == "" {
		return defaultGatewayRoomID
	}
	return roomID
}

func restrictedGatewayRoomID(roomID string) bool {
	roomID = normalizeGatewayRoomID(roomID)
	return roomID != defaultGatewayRoomID && strings.Contains(roomID, ":")
}
