package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/economy"
)

func (s *Server) grantReward(ctx *gin.Context) {
	ctx.JSON(http.StatusForbidden, gin.H{"error": "server_authoritative_rewards_only"})
}

func (s *Server) grantCreatorShare(ctx *gin.Context) {
	if !s.requireAdminRole(ctx, AdminRoleOwner) {
		return
	}
	var request economy.CreatorPlayRewardRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	response, err := s.economyService.GrantCreatorPlayReward(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, response)
}

func (s *Server) spendCoins(ctx *gin.Context) {
	var request economy.SpendRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	response, ok := s.economyService.Spend(ctx.Request.Context(), request)
	if !ok {
		ctx.JSON(http.StatusPaymentRequired, gin.H{
			"error":   "insufficient_funds",
			"balance": response.Balance,
		})
		return
	}
	ctx.JSON(http.StatusOK, response)
}

func (s *Server) getLedger(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Param("player_id"))
	if !ok {
		return
	}
	events := s.economyService.Ledger(ctx.Request.Context(), playerID)
	ctx.JSON(http.StatusOK, gin.H{"events": events})
}

func (s *Server) economyPolicy(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	ctx.JSON(http.StatusOK, s.economyService.Policy())
}
