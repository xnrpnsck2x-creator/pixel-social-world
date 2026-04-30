package gateway

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
)

type fishingCatchRequest struct {
	PlayerID  string `json:"player_id"`
	SessionID string `json:"session_id"`
	RequestID string `json:"request_id"`
}

func (s *Server) claimFishingCatch(ctx *gin.Context) {
	var request fishingCatchRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	response, err := s.fishingRewards.ClaimCatch(ctx.Request.Context(), minigame.FishingCatchRequest{
		PlayerID:  playerID,
		SessionID: request.SessionID,
		RequestID: request.RequestID,
	})
	if err != nil {
		status := http.StatusInternalServerError
		if errors.Is(err, minigame.ErrInvalidFishingSession) {
			status = http.StatusBadRequest
		} else if errors.Is(err, minigame.ErrFishingSessionForbidden) {
			status = http.StatusForbidden
		} else if errors.Is(err, minigame.ErrFishingRewardCap) {
			status = http.StatusTooManyRequests
		} else if errors.Is(err, minigame.ErrFishingRequestPending) {
			status = http.StatusConflict
		}
		ctx.JSON(status, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, response)
}
