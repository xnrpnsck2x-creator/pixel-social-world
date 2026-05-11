package trade

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

const EventTypeCreated = "created"
const EventTypeSold = "sold"
const EventTypeCancelled = "cancelled"

const defaultRecentEventLimit = 10
const maxRecentEventLimit = 50
const maxMemoryEvents = 100

type Event struct {
	ID          string `json:"id"`
	Type        string `json:"type"`
	ListingID   string `json:"listing_id"`
	SellerID    string `json:"seller_id"`
	BuyerID     string `json:"buyer_id,omitempty"`
	ItemID      string `json:"item_id"`
	TitleKey    string `json:"title_key"`
	IconID      string `json:"icon_id"`
	Price       int    `json:"price"`
	CreatedUnix int64  `json:"created_unix"`
}

type TradeEventRecord struct {
	ID          string `gorm:"primaryKey;size:180"`
	Type        string `gorm:"index;size:32"`
	ListingID   string `gorm:"index;size:140"`
	SellerID    string `gorm:"index;size:80"`
	BuyerID     string `gorm:"index;size:80"`
	ItemID      string `gorm:"size:120"`
	TitleKey    string `gorm:"size:160"`
	IconID      string `gorm:"size:80"`
	Price       int
	CreatedUnix int64 `gorm:"index"`
}

type EventQuery struct {
	Limit     int
	Offset    int
	Type      string
	PlayerID  string
	SellerID  string
	BuyerID   string
	ItemID    string
	ListingID string
}

func (s *MemoryService) RecentEvents(_ context.Context, limit int) ([]Event, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	count := normalizeRecentEventLimit(limit)
	if count > len(s.events) {
		count = len(s.events)
	}
	events := make([]Event, count)
	copy(events, s.events[:count])
	return events, nil
}

func (s *MemoryService) SearchEvents(_ context.Context, query EventQuery) ([]Event, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	query = normalizeEventQuery(query)
	items := make([]Event, 0, query.Limit)
	matched := 0
	for _, event := range s.events {
		if !eventMatchesQuery(event, query) {
			continue
		}
		if matched >= query.Offset && len(items) < query.Limit {
			items = append(items, event)
		}
		matched++
	}
	return items, matched, nil
}

func (s *MemoryService) recordEventLocked(eventType string, listing Listing) {
	event := newTradeEvent(eventType, listing, time.Now())
	s.events = append([]Event{event}, s.events...)
	if len(s.events) > maxMemoryEvents {
		s.events = s.events[:maxMemoryEvents]
	}
}

func (s *GormService) RecentEvents(ctx context.Context, limit int) ([]Event, error) {
	records := []TradeEventRecord{}
	err := s.db.WithContext(ctx).
		Order("created_unix desc, id desc").
		Limit(normalizeRecentEventLimit(limit)).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	events := make([]Event, 0, len(records))
	for _, record := range records {
		events = append(events, record.toEvent())
	}
	return events, nil
}

func (s *GormService) SearchEvents(ctx context.Context, query EventQuery) ([]Event, int, error) {
	query = normalizeEventQuery(query)
	tx := applyEventQueryFilters(s.db.WithContext(ctx).Model(&TradeEventRecord{}), query)
	var matched int64
	if err := tx.Count(&matched).Error; err != nil {
		return nil, 0, err
	}
	records := []TradeEventRecord{}
	err := tx.Order("created_unix desc, id desc").Limit(query.Limit).Offset(query.Offset).Find(&records).Error
	if err != nil {
		return nil, 0, err
	}
	events := make([]Event, 0, len(records))
	for _, record := range records {
		events = append(events, record.toEvent())
	}
	return events, int(matched), nil
}

func (s *GormService) createEventInTransaction(
	ctx context.Context,
	tx *gorm.DB,
	eventType string,
	listing Listing,
) error {
	record := recordFromEvent(newTradeEvent(eventType, listing, time.Now()))
	return tx.WithContext(ctx).Create(&record).Error
}

func newTradeEvent(eventType string, listing Listing, now time.Time) Event {
	return Event{
		ID:          newEventID(eventType, listing.ID, now),
		Type:        eventType,
		ListingID:   listing.ID,
		SellerID:    listing.SellerID,
		BuyerID:     listing.BuyerID,
		ItemID:      listing.ItemID,
		TitleKey:    listing.TitleKey,
		IconID:      listing.IconID,
		Price:       listing.Price,
		CreatedUnix: now.Unix(),
	}
}

func recordFromEvent(event Event) TradeEventRecord {
	return TradeEventRecord{
		ID:          event.ID,
		Type:        event.Type,
		ListingID:   event.ListingID,
		SellerID:    event.SellerID,
		BuyerID:     event.BuyerID,
		ItemID:      event.ItemID,
		TitleKey:    event.TitleKey,
		IconID:      event.IconID,
		Price:       event.Price,
		CreatedUnix: event.CreatedUnix,
	}
}

func (r TradeEventRecord) toEvent() Event {
	return Event{
		ID:          r.ID,
		Type:        r.Type,
		ListingID:   r.ListingID,
		SellerID:    r.SellerID,
		BuyerID:     r.BuyerID,
		ItemID:      r.ItemID,
		TitleKey:    r.TitleKey,
		IconID:      r.IconID,
		Price:       r.Price,
		CreatedUnix: r.CreatedUnix,
	}
}

func normalizeRecentEventLimit(limit int) int {
	if limit <= 0 {
		return defaultRecentEventLimit
	}
	if limit > maxRecentEventLimit {
		return maxRecentEventLimit
	}
	return limit
}

func normalizeEventQuery(query EventQuery) EventQuery {
	query.Limit = normalizeRecentEventLimit(query.Limit)
	query.Offset = max(0, query.Offset)
	query.Type = strings.TrimSpace(query.Type)
	query.PlayerID = strings.TrimSpace(query.PlayerID)
	query.SellerID = strings.TrimSpace(query.SellerID)
	query.BuyerID = strings.TrimSpace(query.BuyerID)
	query.ItemID = strings.TrimSpace(query.ItemID)
	query.ListingID = strings.TrimSpace(query.ListingID)
	return query
}

func eventMatchesQuery(event Event, query EventQuery) bool {
	if query.Type != "" && event.Type != query.Type {
		return false
	}
	if query.PlayerID != "" && event.SellerID != query.PlayerID && event.BuyerID != query.PlayerID {
		return false
	}
	if query.SellerID != "" && event.SellerID != query.SellerID {
		return false
	}
	if query.BuyerID != "" && event.BuyerID != query.BuyerID {
		return false
	}
	if query.ItemID != "" && event.ItemID != query.ItemID {
		return false
	}
	if query.ListingID != "" && event.ListingID != query.ListingID {
		return false
	}
	return true
}

func applyEventQueryFilters(tx *gorm.DB, query EventQuery) *gorm.DB {
	if query.Type != "" {
		tx = tx.Where("type = ?", query.Type)
	}
	if query.PlayerID != "" {
		tx = tx.Where("seller_id = ? OR buyer_id = ?", query.PlayerID, query.PlayerID)
	}
	if query.SellerID != "" {
		tx = tx.Where("seller_id = ?", query.SellerID)
	}
	if query.BuyerID != "" {
		tx = tx.Where("buyer_id = ?", query.BuyerID)
	}
	if query.ItemID != "" {
		tx = tx.Where("item_id = ?", query.ItemID)
	}
	if query.ListingID != "" {
		tx = tx.Where("listing_id = ?", query.ListingID)
	}
	return tx
}

func newEventID(eventType string, listingID string, now time.Time) string {
	safeListingID := strings.ReplaceAll(strings.TrimSpace(listingID), ":", "_")
	return fmt.Sprintf("trade_event_%020d_%s_%s", now.UnixNano(), eventType, safeListingID)
}
