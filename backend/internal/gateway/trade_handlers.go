package gateway

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/trade"
)

func (s *Server) tradeListings(ctx *gin.Context) {
	if _, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id")); !ok {
		return
	}
	listings, err := s.tradeService.Listings(ctx.Request.Context())
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "trade_unavailable"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"items":       listings,
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) tradeHistory(ctx *gin.Context) {
	if _, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id")); !ok {
		return
	}
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "10"))
	events, err := s.tradeService.RecentEvents(ctx.Request.Context(), limit)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "trade_unavailable"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"items":       events,
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) adminTradeHistory(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	limit := queryInt(ctx, "limit", 25)
	if limit <= 0 || limit > 50 {
		limit = 25
	}
	offset := max(0, queryInt(ctx, "offset", 0))
	query := trade.EventQuery{
		Limit:     limit,
		Offset:    offset,
		Type:      ctx.Query("type"),
		PlayerID:  ctx.Query("player_id"),
		SellerID:  ctx.Query("seller_id"),
		BuyerID:   ctx.Query("buyer_id"),
		ItemID:    ctx.Query("item_id"),
		ListingID: ctx.Query("listing_id"),
	}
	events, matched, err := s.tradeService.SearchEvents(ctx.Request.Context(), query)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "trade_unavailable"})
		return
	}
	if wantsCSV(ctx) {
		writeAdminCSV(ctx, "trade-history.csv", tradeHistoryCSVRows(events))
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"items":       events,
		"count":       len(events),
		"matched":     matched,
		"limit":       limit,
		"offset":      offset,
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) tradeInventory(ctx *gin.Context) {
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

func (s *Server) createTradeListing(ctx *gin.Context) {
	var request trade.CreateListingRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	sellerID, ok := s.requireAuthorizedPlayer(ctx, request.SellerID)
	if !ok {
		return
	}
	request.SellerID = sellerID
	listing, err := s.tradeService.Create(ctx.Request.Context(), request)
	if err != nil {
		s.recordTradeRiskError(tradeRiskOperationCreate, err)
		s.writeTradeError(ctx, err)
		return
	}
	ctx.JSON(http.StatusCreated, gin.H{"listing": listing})
}

func (s *Server) purchaseTradeListing(ctx *gin.Context) {
	var request trade.PurchaseRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	request.ListingID = ctx.Param("id")
	buyerID, ok := s.requireAuthorizedPlayer(ctx, request.BuyerID)
	if !ok {
		return
	}
	request.BuyerID = buyerID
	response, err := s.tradeService.Purchase(ctx.Request.Context(), request)
	if err != nil {
		s.recordTradeRiskError(tradeRiskOperationBuy, err)
		s.writeTradeError(ctx, err)
		return
	}
	ctx.JSON(http.StatusOK, response)
}

func (s *Server) cancelTradeListing(ctx *gin.Context) {
	var request trade.CancelRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	request.ListingID = ctx.Param("id")
	sellerID, ok := s.requireAuthorizedPlayer(ctx, request.SellerID)
	if !ok {
		return
	}
	request.SellerID = sellerID
	listing, err := s.tradeService.Cancel(ctx.Request.Context(), request)
	if err != nil {
		s.recordTradeRiskError(tradeRiskOperationCancel, err)
		s.writeTradeError(ctx, err)
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"listing": listing})
}

func (s *Server) writeTradeError(ctx *gin.Context, err error) {
	switch {
	case errors.Is(err, trade.ErrInvalidListing):
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	case errors.Is(err, trade.ErrListingNotFound):
		ctx.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
	case errors.Is(err, trade.ErrInsufficientFunds):
		ctx.JSON(http.StatusPaymentRequired, gin.H{"error": err.Error()})
	case errors.Is(err, trade.ErrItemUnavailable):
		ctx.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, trade.ErrSelfPurchase), errors.Is(err, trade.ErrForbidden):
		ctx.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
	case errors.Is(err, trade.ErrListingInactive):
		ctx.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	default:
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "trade_unavailable"})
	}
}
