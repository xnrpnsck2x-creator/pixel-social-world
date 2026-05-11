package gateway

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/house"
)

func (s *Server) authorizeHousingMutation(
	ctx *gin.Context,
	ownerID string,
	playerID string,
) (string, bool) {
	if playerID == "" {
		playerID = ownerID
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, playerID)
	if !ok {
		return "", false
	}
	if ownerID == "" {
		ownerID = playerID
	}
	if ownerID != playerID {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "owner_mismatch"})
		return "", false
	}
	return playerID, true
}

func (s *Server) writeHousingError(
	ctx *gin.Context,
	err error,
	fallback string,
	balance *int,
) {
	status := http.StatusInternalServerError
	code := fallback
	switch {
	case errors.Is(err, house.ErrUnknownItem):
		status = http.StatusBadRequest
		code = "unknown_item"
	case errors.Is(err, house.ErrInvalidPlacement):
		status = http.StatusBadRequest
		code = "invalid_placement"
	case errors.Is(err, house.ErrOccupiedTile):
		status = http.StatusConflict
		code = "occupied_tile"
	case errors.Is(err, house.ErrInvalidStyle):
		status = http.StatusBadRequest
		code = "invalid_style"
	case errors.Is(err, house.ErrItemNotPlaced):
		status = http.StatusNotFound
		code = "item_not_placed"
	}
	payload := gin.H{"error": code}
	if balance != nil {
		payload["balance"] = *balance
	}
	ctx.JSON(status, payload)
}
