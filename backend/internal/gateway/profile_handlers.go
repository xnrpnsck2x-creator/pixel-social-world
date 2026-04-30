package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (s *Server) me(ctx *gin.Context) {
	playerID := ctx.DefaultQuery("player_id", "offline-player")
	if _, ok := s.requireAuthorizedPlayer(ctx, playerID); !ok {
		return
	}
	balance := s.economyService.Balance(ctx.Request.Context(), playerID)
	ctx.JSON(http.StatusOK, gin.H{
		"player_id":    balance.PlayerID,
		"display_name": "Guest",
		"wallet":       gin.H{"coin": balance.Balance},
	})
}
