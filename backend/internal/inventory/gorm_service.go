package inventory

import (
	"context"
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type Record struct {
	PlayerID string `gorm:"primaryKey;size:80"`
	ItemID   string `gorm:"primaryKey;size:120"`
	Owned    int
	Locked   int
}

func (Record) TableName() string {
	return "inventory_records"
}

type GormService struct {
	db *gorm.DB
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&Record{}, &ReservationRecord{})
}

func NewGormService(db *gorm.DB) Service {
	return &GormService{db: db}
}

func (s *GormService) Items(ctx context.Context, playerID string) ([]Item, error) {
	playerID = NormalizePlayerID(playerID)
	if err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return s.seed(tx, playerID)
	}); err != nil {
		return nil, err
	}
	records := []Record{}
	if err := s.db.WithContext(ctx).Where("player_id = ?", playerID).Order("item_id asc").Find(&records).Error; err != nil {
		return nil, err
	}
	items := make([]Item, 0, len(records))
	reservations, err := s.reservationsByItem(s.db.WithContext(ctx), playerID)
	if err != nil {
		return nil, err
	}
	for _, record := range records {
		item := record.toItem()
		item.Reservations = reservations[item.ItemID]
		items = append(items, item.Normalized())
	}
	return items, nil
}

func (s *GormService) Grant(ctx context.Context, request GrantRequest) ([]Item, error) {
	return s.GrantInTransaction(s.db.WithContext(ctx), request)
}

func (s *GormService) Lock(ctx context.Context, playerID string, itemID string) (bool, error) {
	return s.LockForSource(ctx, playerID, itemID, legacySourceID(itemID), "legacy")
}

func (s *GormService) LockForSource(
	ctx context.Context,
	playerID string,
	itemID string,
	sourceID string,
	reason string,
) (bool, error) {
	locked := false
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var lockErr error
		locked, lockErr = s.LockForSourceInTransaction(tx, playerID, itemID, sourceID, reason)
		return lockErr
	})
	return locked, err
}

func (s *GormService) Unlock(ctx context.Context, playerID string, itemID string) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return s.UnlockAnyInTransaction(tx, playerID, itemID)
	})
}

func (s *GormService) UnlockForSource(ctx context.Context, playerID string, itemID string, sourceID string) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return s.UnlockForSourceInTransaction(tx, playerID, itemID, sourceID)
	})
}

func (s *GormService) Deliver(ctx context.Context, sellerID string, buyerID string, itemID string) (Transfer, error) {
	return s.DeliverForSource(ctx, sellerID, buyerID, itemID, "")
}

func (s *GormService) DeliverForSource(
	ctx context.Context,
	sellerID string,
	buyerID string,
	itemID string,
	sourceID string,
) (Transfer, error) {
	transfer := Transfer{}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var deliverErr error
		transfer, deliverErr = s.DeliverForSourceInTransaction(tx, sellerID, buyerID, itemID, sourceID)
		return deliverErr
	})
	return transfer, err
}

func (s *GormService) GrantInTransaction(tx *gorm.DB, request GrantRequest) ([]Item, error) {
	request = normalizeGrantRequest(request)
	if err := validateGrantRequest(request); err != nil {
		return nil, err
	}
	items := []Item{}
	err := tx.Transaction(func(scoped *gorm.DB) error {
		for _, grant := range request.Items {
			item, err := s.grantItem(scoped, request.PlayerID, grant)
			if err != nil {
				return err
			}
			items = append(items, item)
		}
		return nil
	})
	sortItems(items)
	return items, err
}

func (s *GormService) LockInTransaction(tx *gorm.DB, playerID string, itemID string) (bool, error) {
	return s.LockForSourceInTransaction(tx, playerID, itemID, legacySourceID(itemID), "legacy")
}

func (s *GormService) LockForSourceInTransaction(
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
	reason string,
) (bool, error) {
	record, err := s.lockRecord(tx, playerID, itemID)
	if err != nil {
		return false, err
	}
	legacyLocked := max(0, record.Locked-s.lockedQuantity(tx, playerID, itemID))
	record.Locked = s.lockedQuantity(tx, playerID, itemID)
	item := record.toItem()
	item.Locked += legacyLocked
	item = item.Normalized()
	if item.Available <= 0 {
		return false, nil
	}
	if _, err := s.reserveItem(tx, playerID, itemID, sourceID, reason); err != nil {
		return false, err
	}
	record.Locked = legacyLocked + s.lockedQuantity(tx, playerID, itemID)
	return true, tx.Save(&record).Error
}

func (s *GormService) UnlockInTransaction(tx *gorm.DB, playerID string, itemID string) error {
	return s.UnlockAnyInTransaction(tx, playerID, itemID)
}

func (s *GormService) UnlockAnyInTransaction(tx *gorm.DB, playerID string, itemID string) error {
	record, err := s.lockRecord(tx, playerID, itemID)
	if err != nil {
		return err
	}
	beforeReserved := s.lockedQuantity(tx, playerID, itemID)
	legacyLocked := max(0, record.Locked-beforeReserved)
	released, err := s.unlockAnyReservation(tx, playerID, itemID)
	if err != nil {
		return err
	}
	if !released && legacyLocked > 0 {
		legacyLocked--
	}
	record.Locked = legacyLocked + s.lockedQuantity(tx, playerID, itemID)
	return tx.Save(&record).Error
}

func (s *GormService) UnlockForSourceInTransaction(
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
) error {
	record, err := s.lockRecord(tx, playerID, itemID)
	if err != nil {
		return err
	}
	beforeReserved := s.lockedQuantity(tx, playerID, itemID)
	legacyLocked := max(0, record.Locked-beforeReserved)
	released, err := s.unlockSourceReservation(tx, playerID, itemID, sourceID)
	if err != nil {
		return err
	}
	if !released && legacyLocked > 0 {
		legacyLocked--
	}
	record.Locked = legacyLocked + s.lockedQuantity(tx, playerID, itemID)
	return tx.Save(&record).Error
}

func (s *GormService) DeliverInTransaction(
	tx *gorm.DB,
	sellerID string,
	buyerID string,
	itemID string,
) (Transfer, error) {
	return s.DeliverForSourceInTransaction(tx, sellerID, buyerID, itemID, "")
}

func (s *GormService) DeliverForSourceInTransaction(
	tx *gorm.DB,
	sellerID string,
	buyerID string,
	itemID string,
	sourceID string,
) (Transfer, error) {
	records, err := s.lockTransferRecords(tx, sellerID, buyerID, itemID)
	if err != nil {
		return Transfer{}, err
	}
	seller := records[NormalizePlayerID(sellerID)]
	buyer := records[NormalizePlayerID(buyerID)]
	if seller.Owned <= 0 {
		return Transfer{}, ErrItemUnavailable
	}
	beforeReserved := s.lockedQuantity(tx, sellerID, itemID)
	legacyLocked := max(0, seller.Locked-beforeReserved)
	sourceID = NormalizeSourceID(sourceID)
	released := false
	if sourceID == "" {
		var err error
		released, err = s.unlockAnyReservation(tx, sellerID, itemID)
		if err != nil {
			return Transfer{}, err
		}
	} else {
		var err error
		released, err = s.unlockSourceReservation(tx, sellerID, itemID, sourceID)
		if err != nil {
			return Transfer{}, err
		}
	}
	if !released && legacyLocked > 0 {
		legacyLocked--
	} else if !released {
		return Transfer{}, ErrItemUnavailable
	}
	seller.Locked = legacyLocked + s.lockedQuantity(tx, sellerID, itemID)
	seller.Owned--
	buyer.Owned++
	if err := tx.Save(&seller).Error; err != nil {
		return Transfer{}, err
	}
	if err := tx.Save(&buyer).Error; err != nil {
		return Transfer{}, err
	}
	return Transfer{ItemID: NormalizeItemID(itemID), Quantity: 1, From: seller.toItem(), To: buyer.toItem()}, nil
}

func (s *GormService) seed(tx *gorm.DB, playerID string) error {
	var count int64
	if err := tx.Model(&Record{}).Where("player_id = ?", playerID).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	for _, item := range defaultItems {
		record := Record{PlayerID: playerID, ItemID: item.ItemID, Owned: item.Owned, Locked: item.Locked}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}
	}
	return nil
}

func (s *GormService) grantItem(tx *gorm.DB, playerID string, grant Grant) (Item, error) {
	playerID = NormalizePlayerID(playerID)
	if err := s.seed(tx, playerID); err != nil {
		return Item{}, err
	}
	record, err := s.lockRecord(tx, playerID, grant.ItemID)
	if errors.Is(err, ErrItemUnavailable) {
		record = Record{PlayerID: playerID, ItemID: grant.ItemID}
	} else if err != nil {
		return Item{}, err
	}
	record.Owned += grant.Quantity
	legacyLocked := max(0, record.Locked-s.lockedQuantity(tx, playerID, grant.ItemID))
	record.Locked = legacyLocked + s.lockedQuantity(tx, playerID, grant.ItemID)
	if err := tx.Save(&record).Error; err != nil {
		return Item{}, err
	}
	return record.toItem(), nil
}

func (s *GormService) lockTransferRecords(
	tx *gorm.DB,
	sellerID string,
	buyerID string,
	itemID string,
) (map[string]Record, error) {
	sellerID = NormalizePlayerID(sellerID)
	buyerID = NormalizePlayerID(buyerID)
	itemID = NormalizeItemID(itemID)
	if itemID == "" {
		return nil, ErrItemUnavailable
	}
	seller, err := s.lockRecord(tx, sellerID, itemID)
	if err != nil {
		return nil, err
	}
	records := map[string]Record{sellerID: seller}
	if buyerID == sellerID {
		return records, nil
	}
	buyer, err := s.lockRecord(tx, buyerID, itemID)
	if errors.Is(err, ErrItemUnavailable) {
		buyer = Record{PlayerID: buyerID, ItemID: itemID}
		if err := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&buyer).Error; err != nil {
			return nil, err
		}
		buyer, err = s.lockRecord(tx, buyerID, itemID)
	}
	if err != nil {
		return nil, err
	}
	records[buyerID] = buyer
	return records, nil
}

func (s *GormService) lockRecord(tx *gorm.DB, playerID string, itemID string) (Record, error) {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	if itemID == "" {
		return Record{}, ErrItemUnavailable
	}
	if err := s.seed(tx, playerID); err != nil {
		return Record{}, err
	}
	var record Record
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(
		&record,
		"player_id = ? AND item_id = ?",
		playerID,
		itemID,
	).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return Record{}, ErrItemUnavailable
	}
	return record, err
}

func (r Record) toItem() Item {
	return Item{
		PlayerID: r.PlayerID,
		ItemID:   r.ItemID,
		Owned:    r.Owned,
		Locked:   r.Locked,
	}.Normalized()
}
