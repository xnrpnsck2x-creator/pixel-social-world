package gateway

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/house"
)

type housingPlaceRequest struct {
	OwnerID  string `json:"owner_id"`
	PlayerID string `json:"player_id"`
	ItemID   string `json:"item_id"`
	TileX    int    `json:"tile_x"`
	TileY    int    `json:"tile_y"`
	Rotation int    `json:"rotation"`
}

type housingStyleRequest struct {
	OwnerID  string `json:"owner_id"`
	PlayerID string `json:"player_id"`
	Category string `json:"category"`
	ItemID   string `json:"item_id"`
}

type housingMoveRequest struct {
	OwnerID        string `json:"owner_id"`
	PlayerID       string `json:"player_id"`
	ItemID         string `json:"item_id"`
	TileX          int    `json:"tile_x"`
	TileY          int    `json:"tile_y"`
	Rotation       int    `json:"rotation"`
	TargetTileX    int    `json:"target_tile_x"`
	TargetTileY    int    `json:"target_tile_y"`
	TargetRotation int    `json:"target_rotation"`
}

type housingRemoveRequest struct {
	OwnerID  string `json:"owner_id"`
	PlayerID string `json:"player_id"`
	ItemID   string `json:"item_id"`
	TileX    int    `json:"tile_x"`
	TileY    int    `json:"tile_y"`
	Rotation int    `json:"rotation"`
}

func (s *Server) placeHousingItem(ctx *gin.Context) {
	var request housingPlaceRequest
	if err := ctx.ShouldBindJSON(&request); err != nil || request.ItemID == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.authorizeHousingMutation(ctx, request.OwnerID, request.PlayerID)
	if !ok {
		return
	}
	price, ok := s.houseService.ItemPrice(request.ItemID)
	if !ok {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "unknown_item"})
		return
	}
	placeRequest := house.PlaceRequest{
		OwnerID:  playerID,
		ItemID:   request.ItemID,
		TileX:    request.TileX,
		TileY:    request.TileY,
		Rotation: request.Rotation,
	}
	if err := s.houseService.ValidatePlacement(ctx.Request.Context(), placeRequest); err != nil {
		s.writeHousingError(ctx, err, "invalid_placement", nil)
		return
	}
	balance, ok := s.economyService.Spend(ctx.Request.Context(), economy.SpendRequest{
		PlayerID: playerID,
		SinkID:   "housing." + request.ItemID,
		Amount:   price,
	})
	if !ok {
		ctx.JSON(http.StatusPaymentRequired, gin.H{
			"error":   "insufficient_funds",
			"balance": balance.Balance,
		})
		return
	}
	layout, err := s.houseService.PlaceItem(ctx.Request.Context(), placeRequest)
	if err != nil {
		refund := s.refundHousingSpend(ctx, playerID, "housing.refund."+request.ItemID, price)
		s.writeHousingError(ctx, err, "place_failed", &refund.Balance)
		return
	}
	s.broadcastHousingLayout(playerID, "place", layout)
	ctx.JSON(http.StatusOK, gin.H{"layout": layout, "balance": balance.Balance})
}

func (s *Server) applyHousingStyle(ctx *gin.Context) {
	var request housingStyleRequest
	if err := ctx.ShouldBindJSON(&request); err != nil || request.ItemID == "" || request.Category == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.authorizeHousingMutation(ctx, request.OwnerID, request.PlayerID)
	if !ok {
		return
	}
	price, ok := s.houseService.ItemPrice(request.ItemID)
	if !ok {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "unknown_item"})
		return
	}
	styleRequest := house.StyleRequest{
		OwnerID:  playerID,
		Category: request.Category,
		ItemID:   request.ItemID,
	}
	if err := s.houseService.ValidateStyle(ctx.Request.Context(), styleRequest); err != nil {
		s.writeHousingError(ctx, err, "invalid_style", nil)
		return
	}
	balance, ok := s.economyService.Spend(ctx.Request.Context(), economy.SpendRequest{
		PlayerID: playerID,
		SinkID:   "housing.style." + request.ItemID,
		Amount:   price,
	})
	if !ok {
		ctx.JSON(http.StatusPaymentRequired, gin.H{
			"error":   "insufficient_funds",
			"balance": balance.Balance,
		})
		return
	}
	layout, err := s.houseService.ApplyStyle(ctx.Request.Context(), styleRequest)
	if err != nil {
		refund := s.refundHousingSpend(ctx, playerID, "housing.style.refund."+request.ItemID, price)
		s.writeHousingError(ctx, err, "style_failed", &refund.Balance)
		return
	}
	s.broadcastHousingLayout(playerID, "style", layout)
	ctx.JSON(http.StatusOK, gin.H{"layout": layout, "balance": balance.Balance})
}

func (s *Server) moveHousingItem(ctx *gin.Context) {
	var request housingMoveRequest
	if err := ctx.ShouldBindJSON(&request); err != nil || request.ItemID == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.authorizeHousingMutation(ctx, request.OwnerID, request.PlayerID)
	if !ok {
		return
	}
	layout, err := s.houseService.MoveItem(ctx.Request.Context(), house.MoveRequest{
		OwnerID: playerID,
		Item: house.ItemRef{
			ItemID:   request.ItemID,
			TileX:    request.TileX,
			TileY:    request.TileY,
			Rotation: request.Rotation,
		},
		TargetTileX:    request.TargetTileX,
		TargetTileY:    request.TargetTileY,
		TargetRotation: request.TargetRotation,
	})
	if err != nil {
		s.writeHousingError(ctx, err, "move_failed", nil)
		return
	}
	s.broadcastHousingLayout(playerID, "move", layout)
	ctx.JSON(http.StatusOK, gin.H{"layout": layout})
}

func (s *Server) removeHousingItem(ctx *gin.Context) {
	var request housingRemoveRequest
	if err := ctx.ShouldBindJSON(&request); err != nil || request.ItemID == "" {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.authorizeHousingMutation(ctx, request.OwnerID, request.PlayerID)
	if !ok {
		return
	}
	layout, removed, err := s.houseService.RemoveItem(ctx.Request.Context(), house.RemoveRequest{
		OwnerID: playerID,
		Item: house.ItemRef{
			ItemID:   request.ItemID,
			TileX:    request.TileX,
			TileY:    request.TileY,
			Rotation: request.Rotation,
		},
	})
	if err != nil {
		s.writeHousingError(ctx, err, "remove_failed", nil)
		return
	}
	refundAmount := s.housingRefundAmount(removed.ItemID)
	balance := s.economyService.Balance(ctx.Request.Context(), playerID)
	if refundAmount > 0 {
		balance = s.economyService.Grant(ctx.Request.Context(), economy.GrantRequest{
			PlayerID: playerID,
			SourceID: "housing.sell." + removed.ItemID,
			Amount:   refundAmount,
		})
	}
	s.broadcastHousingLayout(playerID, "remove", layout)
	ctx.JSON(http.StatusOK, gin.H{
		"layout":  layout,
		"balance": balance.Balance,
		"refund":  refundAmount,
	})
}

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

func (s *Server) refundHousingSpend(
	ctx *gin.Context,
	playerID string,
	sourceID string,
	amount int,
) economy.GrantResponse {
	return s.economyService.Grant(ctx.Request.Context(), economy.GrantRequest{
		PlayerID: playerID,
		SourceID: sourceID,
		Amount:   amount,
	})
}

func (s *Server) housingRefundAmount(itemID string) int {
	price, ok := s.houseService.ItemPrice(itemID)
	if !ok || price <= 0 {
		return 0
	}
	rate := s.housingSellRefundRate
	if rate <= 0 {
		rate = housingDefaultSellRefundRate
	}
	if rate > 1 {
		rate = 1
	}
	return int(float64(price) * rate)
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
