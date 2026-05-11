package gateway

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/economy"
)

const firstSessionRewardAmount = 5
const firstSessionRewardSource = "first_session.guide_complete"

var firstSessionRequiredSteps = []string{"npc_met", "map_opened", "trade_opened", "games_opened", "chat_sent"}

type firstSessionRewardRequest struct {
	PlayerID         string   `json:"player_id"`
	CompletedStepIDs []string `json:"completed_step_ids"`
}

func (s *Server) grantReward(ctx *gin.Context) {
	ctx.JSON(http.StatusForbidden, gin.H{"error": "server_authoritative_rewards_only"})
}

func (s *Server) claimFirstSessionReward(ctx *gin.Context) {
	var request firstSessionRewardRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	if !hasAllFirstSessionSteps(request.CompletedStepIDs) {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "first_session_incomplete"})
		return
	}
	s.economyService.EnsurePlayer(ctx.Request.Context(), playerID, s.startingCoinBalance)
	response := s.economyService.GrantOnce(ctx.Request.Context(), economy.GrantRequest{
		PlayerID: playerID,
		SourceID: firstSessionRewardSource,
		Amount:   firstSessionRewardAmount,
	})
	ctx.JSON(http.StatusOK, gin.H{
		"player_id": response.PlayerID,
		"balance":   response.Balance,
		"delta":     response.Delta,
		"source_id": firstSessionRewardSource,
		"claimed":   response.Delta > 0,
	})
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
	s.recordAdminAction(ctx, adminActionAuditEvent{
		Action:     "economy.creator_share.grant",
		TargetType: "creator_share",
		TargetID:   request.CreatorID + ":" + request.GameID,
		Status:     "granted",
		Metadata: adminActionMetadata(map[string]any{
			"player_id":         request.PlayerID,
			"creator_id":        request.CreatorID,
			"game_id":           request.GameID,
			"source_id":         request.SourceID,
			"player_amount":     request.PlayerAmount,
			"creator_amount":    response.CreatorAmount,
			"creator_share_bps": response.CreatorShareBps,
		}),
	})
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

func (s *Server) creatorPayouts(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	limit := queryInt(ctx, "limit", 8)
	snapshot := s.economyService.CreatorPayouts(ctx.Request.Context(), limit)
	ctx.JSON(http.StatusOK, gin.H{
		"request_id":           requestID(ctx),
		"server_time":          time.Now().Unix(),
		"items":                snapshot.Items,
		"count":                snapshot.Count,
		"matched":              snapshot.Matched,
		"limit":                snapshot.Limit,
		"total_creators":       snapshot.TotalCreators,
		"total_revenue_events": snapshot.TotalRevenueEvents,
		"total_revenue_coins":  snapshot.TotalRevenueCoins,
	})
}

func hasAllFirstSessionSteps(completed []string) bool {
	seen := map[string]bool{}
	for _, id := range completed {
		seen[id] = true
	}
	for _, required := range firstSessionRequiredSteps {
		if !seen[required] {
			return false
		}
	}
	return true
}
