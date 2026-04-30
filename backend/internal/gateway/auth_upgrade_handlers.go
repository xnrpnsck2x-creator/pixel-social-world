package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/auth"
)

func (s *Server) upgradeGuestAccount(ctx *gin.Context) {
	var request auth.UpgradeGuestRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	if _, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID); !ok {
		return
	}
	response, err := s.authService.UpgradeGuest(ctx.Request.Context(), request)
	if err != nil {
		status := http.StatusBadRequest
		if err.Error() == "account_already_linked" {
			status = http.StatusConflict
		}
		ctx.JSON(status, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, response)
}
