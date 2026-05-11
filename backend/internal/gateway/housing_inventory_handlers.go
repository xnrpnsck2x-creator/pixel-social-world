package gateway

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/inventory"
)

type housingInventoryReservation struct {
	ItemID          string
	Balance         int
	InventoryItems  []inventory.Item
	InventoryLocked bool
	InventorySource string
	ReservationID   string
}

func (s *Server) reserveHousingInventory(
	ctx *gin.Context,
	playerID string,
	itemID string,
	price int,
) (housingInventoryReservation, bool) {
	reservation := housingInventoryReservation{ItemID: itemID}
	reservation.ReservationID = housingReservationID(playerID, itemID)
	locked, err := s.inventoryService.LockForSource(
		ctx.Request.Context(),
		playerID,
		itemID,
		reservation.ReservationID,
		"housing",
	)
	if err != nil {
		s.writeInventoryError(ctx, err)
		return reservation, false
	}
	if locked {
		reservation.Balance = s.economyService.Balance(ctx.Request.Context(), playerID).Balance
		reservation.InventoryLocked = true
		reservation.InventorySource = "owned"
		reservation.InventoryItems = s.safeInventoryItems(ctx, playerID)
		return reservation, true
	}

	balance, ok := s.economyService.Spend(ctx.Request.Context(), economy.SpendRequest{
		PlayerID: playerID,
		SinkID:   "housing.purchase." + itemID,
		Amount:   price,
	})
	if !ok {
		ctx.JSON(http.StatusPaymentRequired, gin.H{
			"error":   "insufficient_funds",
			"balance": balance.Balance,
		})
		return reservation, false
	}
	reservation.Balance = balance.Balance
	if _, err := s.inventoryService.Grant(ctx.Request.Context(), inventory.GrantRequest{
		PlayerID: playerID,
		Items: []inventory.Grant{{
			ItemID:   itemID,
			Quantity: 1,
		}},
	}); err != nil {
		refund := s.refundHousingSpend(ctx, playerID, "housing.purchase.refund."+itemID, price)
		reservation.Balance = refund.Balance
		s.writeInventoryError(ctx, err)
		return reservation, false
	}
	locked, err = s.inventoryService.LockForSource(
		ctx.Request.Context(),
		playerID,
		itemID,
		reservation.ReservationID,
		"housing",
	)
	if err != nil {
		s.writeInventoryError(ctx, err)
		return reservation, false
	}
	if !locked {
		ctx.JSON(http.StatusConflict, gin.H{
			"error":   "item_unavailable",
			"balance": reservation.Balance,
		})
		return reservation, false
	}
	reservation.InventoryLocked = true
	reservation.InventorySource = "purchased"
	reservation.InventoryItems = s.safeInventoryItems(ctx, playerID)
	return reservation, true
}

func (s *Server) releaseHousingInventory(
	ctx *gin.Context,
	playerID string,
	itemID string,
	sourceID string,
) ([]inventory.Item, error) {
	var err error
	if strings.TrimSpace(sourceID) == "" {
		err = s.inventoryService.Unlock(ctx.Request.Context(), playerID, itemID)
	} else {
		err = s.inventoryService.UnlockForSource(ctx.Request.Context(), playerID, itemID, sourceID)
	}
	if err != nil {
		return nil, err
	}
	return s.inventoryService.Items(ctx.Request.Context(), playerID)
}

func (s *Server) rollbackHousingReservation(
	ctx *gin.Context,
	playerID string,
	reservation housingInventoryReservation,
) []inventory.Item {
	if !reservation.InventoryLocked || reservation.ItemID == "" {
		return reservation.InventoryItems
	}
	items, err := s.releaseHousingInventory(ctx, playerID, reservation.ItemID, reservation.ReservationID)
	if err != nil {
		return reservation.InventoryItems
	}
	return items
}

func housingReservationID(playerID string, itemID string) string {
	playerID = strings.ReplaceAll(inventory.NormalizePlayerID(playerID), ":", "_")
	itemID = strings.ReplaceAll(inventory.NormalizeItemID(itemID), ":", "_")
	return fmt.Sprintf("housing:%s:%s:%d", playerID, itemID, time.Now().UnixNano())
}

func (s *Server) safeInventoryItems(ctx *gin.Context, playerID string) []inventory.Item {
	items, err := s.inventoryService.Items(ctx.Request.Context(), playerID)
	if err != nil {
		return []inventory.Item{}
	}
	return items
}
