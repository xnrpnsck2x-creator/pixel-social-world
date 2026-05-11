package gateway

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/inventory"
)

func (s *Server) inventoryItems(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	items, err := s.inventoryService.Items(ctx.Request.Context(), playerID)
	if err != nil {
		s.writeInventoryError(ctx, err)
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"items":       items,
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) adminInventoryAudit(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	playerID := inventory.NormalizePlayerID(ctx.Query("player_id"))
	items, err := s.inventoryService.Items(ctx.Request.Context(), playerID)
	if err != nil {
		s.writeInventoryError(ctx, err)
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"flags":       inventoryAuditFlags(items),
		"items":       items,
		"player_id":   playerID,
		"server_time": time.Now().Unix(),
		"totals":      inventoryAuditTotals(items),
	})
}

func inventoryAuditTotals(items []inventory.Item) gin.H {
	totals := gin.H{
		"available":                  0,
		"housing_reservations":       0,
		"items":                      len(items),
		"legacy_reservations":        0,
		"locked":                     0,
		"locked_without_reservation": 0,
		"other_reservations":         0,
		"owned":                      0,
		"reservation_count":          0,
		"trade_reservations":         0,
	}
	for _, item := range items {
		totals["owned"] = totals["owned"].(int) + item.Owned
		totals["locked"] = totals["locked"].(int) + item.Locked
		totals["available"] = totals["available"].(int) + item.Available
		reserved := 0
		for _, reservation := range item.Reservations {
			quantity := max(0, reservation.Quantity)
			reserved += quantity
			totals["reservation_count"] = totals["reservation_count"].(int) + quantity
			key := inventoryAuditReasonKey(reservation.Reason)
			totals[key] = totals[key].(int) + quantity
		}
		if item.Locked > reserved {
			totals["locked_without_reservation"] = totals["locked_without_reservation"].(int) + item.Locked - reserved
		}
	}
	return totals
}

func inventoryAuditFlags(items []inventory.Item) []gin.H {
	flags := []gin.H{}
	for _, item := range items {
		reserved := 0
		for _, reservation := range item.Reservations {
			quantity := max(0, reservation.Quantity)
			reserved += quantity
			if inventoryAuditReasonKey(reservation.Reason) == "other_reservations" {
				flags = append(flags, inventoryAuditFlag(
					item.ItemID,
					"unknown_reservation_reason",
					"warn",
					quantity,
				))
			}
		}
		if item.Locked > reserved {
			flags = append(flags, inventoryAuditFlag(
				item.ItemID,
				"locked_without_reservation",
				"warn",
				item.Locked-reserved,
			))
		}
		if reserved > item.Locked {
			flags = append(flags, inventoryAuditFlag(
				item.ItemID,
				"reservation_exceeds_locked",
				"warn",
				reserved-item.Locked,
			))
		}
	}
	return flags
}

func inventoryAuditFlag(itemID string, code string, severity string, quantity int) gin.H {
	return gin.H{
		"code":     code,
		"item_id":  itemID,
		"quantity": quantity,
		"severity": severity,
	}
}

func inventoryAuditReasonKey(reason string) string {
	switch reason {
	case "housing":
		return "housing_reservations"
	case "trade":
		return "trade_reservations"
	case "legacy":
		return "legacy_reservations"
	default:
		return "other_reservations"
	}
}

func (s *Server) writeInventoryError(ctx *gin.Context, err error) {
	switch {
	case errors.Is(err, inventory.ErrInvalidGrant):
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	case errors.Is(err, inventory.ErrItemUnavailable):
		ctx.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	default:
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "inventory_unavailable"})
	}
}
