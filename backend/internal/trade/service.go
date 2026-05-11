package trade

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/inventory"
)

const StatusActive = "active"
const StatusSold = "sold"
const StatusCancelled = "cancelled"
const MaxListingPrice = 9999

var ErrInvalidListing = errors.New("invalid_listing")
var ErrListingNotFound = errors.New("listing_not_found")
var ErrListingInactive = errors.New("listing_inactive")
var ErrSelfPurchase = errors.New("self_purchase_forbidden")
var ErrForbidden = errors.New("forbidden")
var ErrInsufficientFunds = errors.New("insufficient_funds")
var ErrItemUnavailable = inventory.ErrItemUnavailable

type Listing struct {
	ID           string `json:"id"`
	SellerID     string `json:"seller_id"`
	BuyerID      string `json:"buyer_id,omitempty"`
	ItemID       string `json:"item_id"`
	TitleKey     string `json:"title_key"`
	BodyKey      string `json:"body_key"`
	IconID       string `json:"icon_id"`
	Price        int    `json:"price"`
	Status       string `json:"status"`
	EscrowStatus string `json:"escrow_status"`
	CreatedUnix  int64  `json:"created_unix"`
	UpdatedUnix  int64  `json:"updated_unix"`
}

type CreateListingRequest struct {
	SellerID string `json:"seller_id"`
	ItemID   string `json:"item_id"`
	TitleKey string `json:"title_key"`
	BodyKey  string `json:"body_key"`
	IconID   string `json:"icon_id"`
	Price    int    `json:"price"`
}

type PurchaseRequest struct {
	BuyerID   string `json:"buyer_id"`
	ListingID string `json:"listing_id"`
}

type CancelRequest struct {
	SellerID  string `json:"seller_id"`
	ListingID string `json:"listing_id"`
}

type PurchaseResponse struct {
	Listing  Listing                  `json:"listing"`
	Transfer economy.TransferResponse `json:"transfer"`
	Item     inventory.Transfer       `json:"item_transfer"`
}

type Service interface {
	Listings(ctx context.Context) ([]Listing, error)
	RecentEvents(ctx context.Context, limit int) ([]Event, error)
	SearchEvents(ctx context.Context, query EventQuery) ([]Event, int, error)
	Create(ctx context.Context, request CreateListingRequest) (Listing, error)
	Purchase(ctx context.Context, request PurchaseRequest) (PurchaseResponse, error)
	Cancel(ctx context.Context, request CancelRequest) (Listing, error)
}

type MemoryService struct {
	mu               sync.Mutex
	economy          economy.Service
	inventoryService inventory.Service
	listings         map[string]Listing
	events           []Event
}

func NewMemoryService(economyService economy.Service, inventoryServices ...inventory.Service) Service {
	inventoryService := firstInventoryService(inventoryServices)
	return &MemoryService{
		economy:          economyService,
		inventoryService: inventoryService,
		listings:         map[string]Listing{},
		events:           []Event{},
	}
}

func (s *MemoryService) Listings(_ context.Context) ([]Listing, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	items := make([]Listing, 0, len(s.listings))
	for _, listing := range s.listings {
		items = append(items, listing)
	}
	sortListings(items)
	return items, nil
}

func (s *MemoryService) Create(ctx context.Context, request CreateListingRequest) (Listing, error) {
	request = normalizeCreateRequest(request)
	if err := validateCreateRequest(request); err != nil {
		return Listing{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	listingID := nextListingID(request.SellerID)
	ok, err := s.inventoryService.LockForSource(ctx, request.SellerID, request.ItemID, tradeReservationID(listingID), "trade")
	if err != nil {
		return Listing{}, err
	}
	if !ok {
		return Listing{}, ErrItemUnavailable
	}
	now := time.Now().Unix()
	listing := Listing{
		ID:           listingID,
		SellerID:     request.SellerID,
		ItemID:       request.ItemID,
		TitleKey:     request.TitleKey,
		BodyKey:      request.BodyKey,
		IconID:       request.IconID,
		Price:        request.Price,
		Status:       StatusActive,
		EscrowStatus: EscrowLocked,
		CreatedUnix:  now,
		UpdatedUnix:  now,
	}
	s.listings[listing.ID] = listing
	s.recordEventLocked(EventTypeCreated, listing)
	return listing, nil
}

func (s *MemoryService) Purchase(ctx context.Context, request PurchaseRequest) (PurchaseResponse, error) {
	request.BuyerID = normalizePlayerID(request.BuyerID)
	request.ListingID = strings.TrimSpace(request.ListingID)
	s.mu.Lock()
	defer s.mu.Unlock()
	listing, ok := s.listings[request.ListingID]
	if !ok {
		return PurchaseResponse{}, ErrListingNotFound
	}
	if listing.Status != StatusActive {
		return PurchaseResponse{Listing: listing}, ErrListingInactive
	}
	if listing.SellerID == request.BuyerID {
		return PurchaseResponse{Listing: listing}, ErrSelfPurchase
	}

	transfer, ok := s.economy.Transfer(ctx, tradeTransferRequest(listing, request.BuyerID))
	if !ok {
		return PurchaseResponse{Listing: listing, Transfer: transfer}, ErrInsufficientFunds
	}

	listing.Status = StatusSold
	listing.BuyerID = request.BuyerID
	listing.EscrowStatus = EscrowDelivered
	listing.UpdatedUnix = time.Now().Unix()
	itemTransfer, err := s.inventoryService.DeliverForSource(
		ctx,
		listing.SellerID,
		request.BuyerID,
		listing.ItemID,
		tradeReservationID(listing.ID),
	)
	if err != nil {
		return PurchaseResponse{Listing: listing, Transfer: transfer}, err
	}
	s.listings[listing.ID] = listing
	s.recordEventLocked(EventTypeSold, listing)
	return PurchaseResponse{Listing: listing, Transfer: transfer, Item: itemTransfer}, nil
}

func (s *MemoryService) Cancel(ctx context.Context, request CancelRequest) (Listing, error) {
	request.SellerID = normalizePlayerID(request.SellerID)
	request.ListingID = strings.TrimSpace(request.ListingID)
	s.mu.Lock()
	defer s.mu.Unlock()
	listing, ok := s.listings[request.ListingID]
	if !ok {
		return Listing{}, ErrListingNotFound
	}
	if listing.SellerID != request.SellerID {
		return listing, ErrForbidden
	}
	if listing.Status != StatusActive {
		return listing, ErrListingInactive
	}
	listing.Status = StatusCancelled
	listing.EscrowStatus = EscrowReturned
	listing.UpdatedUnix = time.Now().Unix()
	if err := s.inventoryService.UnlockForSource(ctx, listing.SellerID, listing.ItemID, tradeReservationID(listing.ID)); err != nil {
		return listing, err
	}
	s.listings[listing.ID] = listing
	s.recordEventLocked(EventTypeCancelled, listing)
	return listing, nil
}

func normalizeCreateRequest(request CreateListingRequest) CreateListingRequest {
	request.SellerID = normalizePlayerID(request.SellerID)
	request.ItemID = strings.TrimSpace(request.ItemID)
	request.TitleKey = strings.TrimSpace(request.TitleKey)
	request.BodyKey = strings.TrimSpace(request.BodyKey)
	request.IconID = strings.TrimSpace(request.IconID)
	if request.TitleKey == "" {
		request.TitleKey = "facility.trade.listing.title"
	}
	if request.BodyKey == "" {
		request.BodyKey = "facility.trade.listing.body"
	}
	if request.IconID == "" {
		request.IconID = "icon.gift"
	}
	return request
}

func validateCreateRequest(request CreateListingRequest) error {
	if request.SellerID == "" || request.ItemID == "" || request.Price <= 0 || request.Price > MaxListingPrice {
		return ErrInvalidListing
	}
	return nil
}

func tradeTransferRequest(listing Listing, buyerID string) economy.TransferRequest {
	sourceID := "trade.sale." + listing.ID
	return economy.TransferRequest{
		FromPlayerID: buyerID,
		ToPlayerID:   listing.SellerID,
		SourceID:     sourceID,
		SinkID:       sourceID,
		Amount:       listing.Price,
	}
}

func normalizePlayerID(playerID string) string {
	return inventory.NormalizePlayerID(playerID)
}

func sortListings(items []Listing) {
	sort.Slice(items, func(left int, right int) bool {
		if items[left].UpdatedUnix == items[right].UpdatedUnix {
			return items[left].ID < items[right].ID
		}
		return items[left].UpdatedUnix > items[right].UpdatedUnix
	})
}

func nextListingID(sellerID string) string {
	return fmt.Sprintf("trade_%s_%d", strings.ReplaceAll(sellerID, "-", "_"), time.Now().UnixNano())
}

func tradeReservationID(listingID string) string {
	return "trade:" + strings.ReplaceAll(strings.TrimSpace(listingID), ":", "_")
}

func firstInventoryService(inventoryServices []inventory.Service) inventory.Service {
	if len(inventoryServices) > 0 && inventoryServices[0] != nil {
		return inventoryServices[0]
	}
	return inventory.NewMemoryService()
}
