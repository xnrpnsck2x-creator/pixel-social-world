package gateway

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/inventory"
	"pixel-social-world/backend/internal/mapactivity"
)

type mapActivityClaimPayload struct {
	mapactivity.ClaimResponse
	InventoryItems []inventory.Item `json:"inventory_items,omitempty"`
}

func (s *Server) claimMapActivity(ctx *gin.Context) {
	var request mapactivity.ClaimRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	response, err := s.mapActivityService.Claim(ctx.Request.Context(), request)
	if err == nil {
		inventoryItems, inventoryErr := s.grantMapActivityDrops(ctx, response)
		if inventoryErr != nil {
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": "inventory_sync_failed"})
			return
		}
		ctx.JSON(http.StatusOK, mapActivityClaimPayload{
			ClaimResponse:  response,
			InventoryItems: inventoryItems,
		})
		return
	}
	switch {
	case errors.Is(err, mapactivity.ErrCooldown):
		ctx.JSON(http.StatusTooManyRequests, withError(response, "activity_cooldown"))
	case errors.Is(err, mapactivity.ErrDailyLimit):
		ctx.JSON(http.StatusTooManyRequests, withError(response, "activity_daily_limit"))
	case errors.Is(err, mapactivity.ErrActivityNotMap):
		ctx.JSON(http.StatusBadRequest, withError(response, "activity_not_on_map"))
	case errors.Is(err, mapactivity.ErrUnknownAction):
		ctx.JSON(http.StatusBadRequest, withError(response, "unknown_activity"))
	case errors.Is(err, mapactivity.ErrPlayerRequired):
		ctx.JSON(http.StatusBadRequest, withError(response, "player_required"))
	case errors.Is(err, mapactivity.ErrMapRequired):
		ctx.JSON(http.StatusBadRequest, withError(response, "map_required"))
	case errors.Is(err, mapactivity.ErrActionRequired):
		ctx.JSON(http.StatusBadRequest, withError(response, "action_required"))
	default:
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "map_activity_failed"})
	}
}

func (s *Server) grantMapActivityDrops(
	ctx *gin.Context,
	response mapactivity.ClaimResponse,
) ([]inventory.Item, error) {
	if !response.Claimed || len(response.Drops) == 0 {
		return nil, nil
	}
	grants := make([]inventory.Grant, 0, len(response.Drops))
	for _, drop := range response.Drops {
		grants = append(grants, inventory.Grant{
			ItemID:   drop.ItemID,
			Quantity: drop.Amount,
		})
	}
	return s.inventoryService.Grant(ctx.Request.Context(), inventory.GrantRequest{
		PlayerID: response.PlayerID,
		Items:    grants,
	})
}

func withError(response mapactivity.ClaimResponse, errorCode string) gin.H {
	return gin.H{
		"error":              errorCode,
		"player_id":          response.PlayerID,
		"map_id":             response.MapID,
		"action_id":          response.ActionID,
		"reward_coins":       response.RewardCoins,
		"skill_id":           response.SkillID,
		"skill_xp":           response.SkillXP,
		"drops":              response.Drops,
		"rare_event":         response.RareEvent,
		"cooldown_seconds":   response.CooldownSeconds,
		"daily_reward_limit": response.DailyRewardLimit,
		"daily_reward_count": response.DailyRewardCount,
		"ready_at":           response.ReadyAt,
		"ready_in_seconds":   response.ReadyInSeconds,
		"server_time":        response.ServerTime,
		"claimed":            response.Claimed,
		"wallet":             response.Wallet,
	}
}
