package inventory

import (
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type ReservationRecord struct {
	PlayerID    string `gorm:"primaryKey;size:80"`
	ItemID      string `gorm:"primaryKey;size:120"`
	SourceID    string `gorm:"primaryKey;size:180"`
	Reason      string `gorm:"size:80"`
	Quantity    int
	CreatedUnix int64
	UpdatedUnix int64
}

func (ReservationRecord) TableName() string {
	return "inventory_reservations"
}

func (s *GormService) reserveItem(
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
	reason string,
) (Reservation, error) {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	sourceID = NormalizeSourceID(sourceID)
	if itemID == "" || sourceID == "" {
		return Reservation{}, ErrItemUnavailable
	}
	record, err := s.lockReservation(tx, playerID, itemID, sourceID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		now := time.Now().Unix()
		record = ReservationRecord{
			PlayerID:    playerID,
			ItemID:      itemID,
			SourceID:    sourceID,
			Reason:      NormalizeReason(reason),
			CreatedUnix: now,
			UpdatedUnix: now,
		}
	} else if err != nil {
		return Reservation{}, err
	}
	record.Quantity++
	record.Reason = NormalizeReason(reason)
	record.UpdatedUnix = time.Now().Unix()
	if err := tx.Save(&record).Error; err != nil {
		return Reservation{}, err
	}
	return record.toReservation(), nil
}

func (s *GormService) unlockSourceReservation(
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
) (bool, error) {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	sourceID = NormalizeSourceID(sourceID)
	if itemID == "" || sourceID == "" {
		return false, ErrItemUnavailable
	}
	record, err := s.lockReservation(tx, playerID, itemID, sourceID)
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, tx.Delete(&record).Error
}

func (s *GormService) unlockAnyReservation(tx *gorm.DB, playerID string, itemID string) (bool, error) {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	if itemID == "" {
		return false, ErrItemUnavailable
	}
	record := ReservationRecord{}
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("player_id = ? AND item_id = ? AND quantity > 0", playerID, itemID).
		Order("created_unix asc, source_id asc").
		First(&record).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	record.Quantity--
	if record.Quantity <= 0 {
		return true, tx.Delete(&record).Error
	}
	record.UpdatedUnix = time.Now().Unix()
	return true, tx.Save(&record).Error
}

func (s *GormService) lockedQuantity(tx *gorm.DB, playerID string, itemID string) int {
	var total int64
	_ = tx.Model(&ReservationRecord{}).
		Where("player_id = ? AND item_id = ?", NormalizePlayerID(playerID), NormalizeItemID(itemID)).
		Select("COALESCE(SUM(quantity), 0)").
		Scan(&total).Error
	return int(total)
}

func (s *GormService) reservationsByItem(tx *gorm.DB, playerID string) (map[string][]Reservation, error) {
	records := []ReservationRecord{}
	err := tx.Where("player_id = ? AND quantity > 0", NormalizePlayerID(playerID)).
		Order("item_id asc, created_unix asc, source_id asc").
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	items := map[string][]Reservation{}
	for _, record := range records {
		items[record.ItemID] = append(items[record.ItemID], record.toReservation())
	}
	for itemID := range items {
		sortReservations(items[itemID])
	}
	return items, nil
}

func (s *GormService) lockReservation(
	tx *gorm.DB,
	playerID string,
	itemID string,
	sourceID string,
) (ReservationRecord, error) {
	record := ReservationRecord{}
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(
		&record,
		"player_id = ? AND item_id = ? AND source_id = ?",
		NormalizePlayerID(playerID),
		NormalizeItemID(itemID),
		NormalizeSourceID(sourceID),
	).Error
	return record, err
}

func (r ReservationRecord) toReservation() Reservation {
	return Reservation{
		PlayerID:    r.PlayerID,
		ItemID:      r.ItemID,
		SourceID:    r.SourceID,
		Reason:      r.Reason,
		Quantity:    r.Quantity,
		CreatedUnix: r.CreatedUnix,
	}
}
