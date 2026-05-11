package trade

import (
	"context"
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/inventory"
)

type ListingRecord struct {
	ID           string `gorm:"primaryKey;size:140"`
	SellerID     string `gorm:"index;size:80"`
	BuyerID      string `gorm:"index;size:80"`
	ItemID       string `gorm:"size:120"`
	TitleKey     string `gorm:"size:160"`
	BodyKey      string `gorm:"size:160"`
	IconID       string `gorm:"size:80"`
	Price        int
	Status       string `gorm:"index;size:32"`
	EscrowStatus string `gorm:"size:32"`
	CreatedUnix  int64
	UpdatedUnix  int64
}

type GormService struct {
	db               *gorm.DB
	economy          economy.Service
	inventoryService inventory.Service
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&ListingRecord{}, &TradeEventRecord{})
}

func NewGormService(db *gorm.DB, economyService economy.Service, inventoryServices ...inventory.Service) Service {
	return &GormService{
		db:               db,
		economy:          economyService,
		inventoryService: firstInventoryService(inventoryServices),
	}
}

func (s *GormService) Listings(ctx context.Context) ([]Listing, error) {
	records := []ListingRecord{}
	if err := s.db.WithContext(ctx).Order("updated_unix desc, id asc").Find(&records).Error; err != nil {
		return nil, err
	}
	listings := make([]Listing, 0, len(records))
	for _, record := range records {
		listings = append(listings, record.toListing())
	}
	return listings, nil
}

func (s *GormService) Create(ctx context.Context, request CreateListingRequest) (Listing, error) {
	request = normalizeCreateRequest(request)
	if err := validateCreateRequest(request); err != nil {
		return Listing{}, err
	}
	now := time.Now().Unix()
	record := ListingRecord{
		ID:           nextListingID(request.SellerID),
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
	if err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if ok, err := s.lockInventoryItem(ctx, tx, request.SellerID, request.ItemID, tradeReservationID(record.ID)); err != nil {
			return err
		} else if !ok {
			return ErrItemUnavailable
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}
		return s.createEventInTransaction(ctx, tx, EventTypeCreated, record.toListing())
	}); err != nil {
		return Listing{}, err
	}
	return record.toListing(), nil
}

func (s *GormService) Purchase(ctx context.Context, request PurchaseRequest) (PurchaseResponse, error) {
	request.BuyerID = normalizePlayerID(request.BuyerID)
	response := PurchaseResponse{}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		record, err := s.lockListing(tx, request.ListingID)
		if err != nil {
			return err
		}
		listing := record.toListing()
		response.Listing = listing
		if listing.Status != StatusActive {
			return ErrListingInactive
		}
		if listing.SellerID == request.BuyerID {
			return ErrSelfPurchase
		}
		transfer, ok, err := s.transferForListing(ctx, tx, listing, request.BuyerID)
		response.Transfer = transfer
		if err != nil {
			return err
		}
		if !ok {
			return ErrInsufficientFunds
		}
		record.Status = StatusSold
		record.BuyerID = request.BuyerID
		record.EscrowStatus = EscrowDelivered
		record.UpdatedUnix = time.Now().Unix()
		itemTransfer, err := s.deliverInventoryItem(
			ctx,
			tx,
			listing.SellerID,
			request.BuyerID,
			listing.ItemID,
			tradeReservationID(listing.ID),
		)
		if err != nil {
			return err
		}
		response.Item = itemTransfer
		if err := tx.Save(&record).Error; err != nil {
			return err
		}
		if err := s.createEventInTransaction(ctx, tx, EventTypeSold, record.toListing()); err != nil {
			return err
		}
		response.Listing = record.toListing()
		return nil
	})
	return response, err
}

func (s *GormService) Cancel(ctx context.Context, request CancelRequest) (Listing, error) {
	request.SellerID = normalizePlayerID(request.SellerID)
	var listing Listing
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		record, err := s.lockListing(tx, request.ListingID)
		if err != nil {
			return err
		}
		listing = record.toListing()
		if listing.SellerID != request.SellerID {
			return ErrForbidden
		}
		if listing.Status != StatusActive {
			return ErrListingInactive
		}
		record.Status = StatusCancelled
		record.EscrowStatus = EscrowReturned
		record.UpdatedUnix = time.Now().Unix()
		if err := s.unlockInventoryItem(ctx, tx, listing.SellerID, listing.ItemID, tradeReservationID(listing.ID)); err != nil {
			return err
		}
		if err := tx.Save(&record).Error; err != nil {
			return err
		}
		if err := s.createEventInTransaction(ctx, tx, EventTypeCancelled, record.toListing()); err != nil {
			return err
		}
		listing = record.toListing()
		return nil
	})
	return listing, err
}

func (s *GormService) lockInventoryItem(
	ctx context.Context,
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
) (bool, error) {
	if service, ok := s.inventoryService.(interface {
		LockForSourceInTransaction(*gorm.DB, string, string, string, string) (bool, error)
	}); ok {
		return service.LockForSourceInTransaction(tx, playerID, itemID, sourceID, "trade")
	}
	return s.inventoryService.LockForSource(ctx, playerID, itemID, sourceID, "trade")
}

func (s *GormService) unlockInventoryItem(
	ctx context.Context,
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
) error {
	if service, ok := s.inventoryService.(interface {
		UnlockForSourceInTransaction(*gorm.DB, string, string, string) error
	}); ok {
		return service.UnlockForSourceInTransaction(tx, playerID, itemID, sourceID)
	}
	return s.inventoryService.UnlockForSource(ctx, playerID, itemID, sourceID)
}

func (s *GormService) deliverInventoryItem(
	ctx context.Context,
	tx *gorm.DB,
	sellerID string,
	buyerID string,
	itemID string,
	sourceID string,
) (inventory.Transfer, error) {
	if service, ok := s.inventoryService.(interface {
		DeliverForSourceInTransaction(*gorm.DB, string, string, string, string) (inventory.Transfer, error)
	}); ok {
		return service.DeliverForSourceInTransaction(tx, sellerID, buyerID, itemID, sourceID)
	}
	return s.inventoryService.DeliverForSource(ctx, sellerID, buyerID, itemID, sourceID)
}

func (s *GormService) lockListing(tx *gorm.DB, listingID string) (ListingRecord, error) {
	var record ListingRecord
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(
		&record,
		"id = ?",
		stringsTrim(listingID),
	).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return ListingRecord{}, ErrListingNotFound
	}
	return record, err
}

func (s *GormService) transferForListing(
	ctx context.Context,
	tx *gorm.DB,
	listing Listing,
	buyerID string,
) (economy.TransferResponse, bool, error) {
	request := tradeTransferRequest(listing, buyerID)
	if transferer, ok := s.economy.(interface {
		TransferInTransaction(*gorm.DB, economy.TransferRequest) (economy.TransferResponse, bool, error)
	}); ok {
		return transferer.TransferInTransaction(tx, request)
	}
	response, ok := s.economy.Transfer(ctx, request)
	return response, ok, nil
}

func (r ListingRecord) toListing() Listing {
	return Listing{
		ID:           r.ID,
		SellerID:     r.SellerID,
		BuyerID:      r.BuyerID,
		ItemID:       r.ItemID,
		TitleKey:     r.TitleKey,
		BodyKey:      r.BodyKey,
		IconID:       r.IconID,
		Price:        r.Price,
		Status:       r.Status,
		EscrowStatus: r.EscrowStatus,
		CreatedUnix:  r.CreatedUnix,
		UpdatedUnix:  r.UpdatedUnix,
	}
}

func stringsTrim(value string) string {
	return strings.TrimSpace(value)
}
