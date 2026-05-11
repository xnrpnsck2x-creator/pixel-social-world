package gateway

import (
	"context"
	"errors"
	"time"

	"pixel-social-world/backend/internal/trade"
)

const tradeRiskRecentEventLimit = 50
const tradeRiskHighPrice = 8000

const tradeRiskOperationCreate = "create"
const tradeRiskOperationBuy = "buy"
const tradeRiskOperationCancel = "cancel"

type tradeRiskCounters struct {
	BuyInactive        int64 `json:"buy_inactive"`
	CancelInactive     int64 `json:"cancel_inactive"`
	InsufficientFunds  int64 `json:"insufficient_funds"`
	SettlementFailures int64 `json:"settlement_failures"`
	CreateRejected     int64 `json:"create_rejected"`
	UpdatedUnix        int64 `json:"updated_unix"`
}

type tradeRiskEventStats struct {
	RecentEvents             int   `json:"recent_events"`
	Created                  int   `json:"created"`
	Sold                     int   `json:"sold"`
	Cancelled                int   `json:"cancelled"`
	Completed                int   `json:"completed"`
	CancelRate               int64 `json:"cancel_rate"`
	ActiveListings           int   `json:"active_listings"`
	HighPriceActiveListings  int   `json:"high_price_active_listings"`
	HighPriceCreatedInWindow int   `json:"high_price_created_in_window"`
}

type tradeRiskSnapshot struct {
	Counters tradeRiskCounters   `json:"counters"`
	Events   tradeRiskEventStats `json:"events"`
}

func (s *Server) recordTradeRiskError(operation string, err error) {
	if err == nil {
		return
	}
	s.tradeRiskMu.Lock()
	defer s.tradeRiskMu.Unlock()
	switch operation {
	case tradeRiskOperationCreate:
		if errors.Is(err, trade.ErrInvalidListing) || errors.Is(err, trade.ErrItemUnavailable) {
			s.tradeRiskCounters.CreateRejected++
		}
	case tradeRiskOperationBuy:
		switch {
		case errors.Is(err, trade.ErrListingInactive):
			s.tradeRiskCounters.BuyInactive++
		case errors.Is(err, trade.ErrInsufficientFunds):
			s.tradeRiskCounters.InsufficientFunds++
		case !isExpectedTradeBuyError(err):
			s.tradeRiskCounters.SettlementFailures++
		}
	case tradeRiskOperationCancel:
		if errors.Is(err, trade.ErrListingInactive) {
			s.tradeRiskCounters.CancelInactive++
		}
	}
	s.tradeRiskCounters.UpdatedUnix = time.Now().Unix()
}

func isExpectedTradeBuyError(err error) bool {
	return errors.Is(err, trade.ErrInvalidListing) ||
		errors.Is(err, trade.ErrListingNotFound) ||
		errors.Is(err, trade.ErrListingInactive) ||
		errors.Is(err, trade.ErrSelfPurchase) ||
		errors.Is(err, trade.ErrForbidden) ||
		errors.Is(err, trade.ErrInsufficientFunds)
}

func (s *Server) tradeRiskSnapshot(ctx context.Context) tradeRiskSnapshot {
	return tradeRiskSnapshot{
		Counters: s.tradeRiskCountersSnapshot(),
		Events:   s.tradeRiskEventStats(ctx),
	}
}

func (s *Server) tradeRiskCountersSnapshot() tradeRiskCounters {
	s.tradeRiskMu.Lock()
	defer s.tradeRiskMu.Unlock()
	return s.tradeRiskCounters
}

func (s *Server) tradeRiskEventStats(ctx context.Context) tradeRiskEventStats {
	stats := tradeRiskEventStats{}
	events, _, err := s.tradeService.SearchEvents(ctx, trade.EventQuery{Limit: tradeRiskRecentEventLimit})
	if err == nil {
		stats.RecentEvents = len(events)
		for _, event := range events {
			switch event.Type {
			case trade.EventTypeCreated:
				stats.Created++
				if event.Price >= tradeRiskHighPrice {
					stats.HighPriceCreatedInWindow++
				}
			case trade.EventTypeSold:
				stats.Sold++
			case trade.EventTypeCancelled:
				stats.Cancelled++
			}
		}
		stats.Completed = stats.Sold + stats.Cancelled
		if stats.Completed > 0 {
			stats.CancelRate = int64(stats.Cancelled * 100 / stats.Completed)
		}
	}
	listings, listErr := s.tradeService.Listings(ctx)
	if listErr == nil {
		for _, listing := range listings {
			if listing.Status != trade.StatusActive {
				continue
			}
			stats.ActiveListings++
			if listing.Price >= tradeRiskHighPrice {
				stats.HighPriceActiveListings++
			}
		}
	}
	return stats
}
