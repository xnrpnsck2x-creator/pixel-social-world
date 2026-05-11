package economy

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type WalletRecord struct {
	PlayerID  string `gorm:"primaryKey;size:80"`
	Balance   int
	CreatedAt time.Time
	UpdatedAt time.Time
}

type LedgerRecord struct {
	ID               uint   `gorm:"primaryKey"`
	EventID          string `gorm:"uniqueIndex;size:140"`
	PlayerID         string `gorm:"index;size:80"`
	Type             string `gorm:"size:40"`
	GameID           string `gorm:"index;size:100"`
	SourceID         string `gorm:"size:120"`
	SinkID           string `gorm:"size:120"`
	Delta            int
	BalanceAfter     int
	CreatedUnix      int64
	PreviousChecksum string `gorm:"size:80"`
	Checksum         string `gorm:"size:80"`
}

type GormService struct {
	db              *gorm.DB
	startingBalance int
	policy          Policy
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&WalletRecord{}, &LedgerRecord{})
}

func NewGormService(db *gorm.DB, startingBalance int) Service {
	return NewGormServiceWithPolicy(db, startingBalance, DefaultPolicy())
}

func NewGormServiceWithPolicy(db *gorm.DB, startingBalance int, policy Policy) Service {
	if startingBalance < 0 {
		startingBalance = 0
	}
	return &GormService{db: db, startingBalance: startingBalance, policy: normalizePolicy(policy)}
}

func (s *GormService) Balance(ctx context.Context, playerID string) GrantResponse {
	playerID = normalizePlayerID(playerID)
	var wallet WalletRecord
	if err := s.db.WithContext(ctx).First(&wallet, "player_id = ?", playerID).Error; err != nil {
		return GrantResponse{PlayerID: playerID}
	}
	return GrantResponse{PlayerID: playerID, Balance: wallet.Balance}
}

func (s *GormService) EnsurePlayer(ctx context.Context, playerID string, startingBalance int) GrantResponse {
	playerID = normalizePlayerID(playerID)
	if startingBalance < 0 {
		startingBalance = s.startingBalance
	}
	response := GrantResponse{PlayerID: playerID}
	_ = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		wallet, created, err := s.walletForUpdate(tx, playerID, startingBalance)
		if err != nil {
			return err
		}
		response.Balance = wallet.Balance
		if created {
			return s.appendRecord(tx, LedgerEvent{
				PlayerID:     playerID,
				Type:         "system.init",
				SourceID:     "profile_init",
				Delta:        startingBalance,
				BalanceAfter: wallet.Balance,
			})
		}
		return nil
	})
	return response
}

func (s *GormService) Grant(ctx context.Context, request GrantRequest) GrantResponse {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}
	response := GrantResponse{PlayerID: request.PlayerID}
	_ = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		wallet, _, err := s.walletForUpdate(tx, request.PlayerID, 0)
		if err != nil {
			return err
		}
		amount := s.cappedGrantAmount(tx, request.PlayerID, request.Amount, time.Now().Unix())
		wallet.Balance += amount
		if err := tx.Save(&wallet).Error; err != nil {
			return err
		}
		response.Balance = wallet.Balance
		response.Delta = amount
		return s.appendRecord(tx, LedgerEvent{
			PlayerID:     request.PlayerID,
			Type:         "grant",
			SourceID:     request.SourceID,
			Delta:        amount,
			BalanceAfter: wallet.Balance,
		})
	})
	return response
}

func (s *GormService) GrantOnce(ctx context.Context, request GrantRequest) GrantResponse {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}
	response := GrantResponse{PlayerID: request.PlayerID}
	_ = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		wallet, _, err := s.walletForUpdate(tx, request.PlayerID, 0)
		if err != nil {
			return err
		}
		response.Balance = wallet.Balance
		if request.SourceID != "" && hasLedgerEvent(tx, request.PlayerID, "grant", request.SourceID) {
			return nil
		}
		amount := s.cappedGrantAmount(tx, request.PlayerID, request.Amount, time.Now().Unix())
		wallet.Balance += amount
		if err := tx.Save(&wallet).Error; err != nil {
			return err
		}
		response.Balance = wallet.Balance
		response.Delta = amount
		return s.appendRecord(tx, LedgerEvent{
			PlayerID:     request.PlayerID,
			Type:         "grant",
			SourceID:     request.SourceID,
			Delta:        amount,
			BalanceAfter: wallet.Balance,
		})
	})
	return response
}

func (s *GormService) Spend(ctx context.Context, request SpendRequest) (GrantResponse, bool) {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}
	response := GrantResponse{PlayerID: request.PlayerID}
	ok := false
	_ = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		wallet, _, err := s.walletForUpdate(tx, request.PlayerID, 0)
		if err != nil {
			return err
		}
		response.Balance = wallet.Balance
		if wallet.Balance < request.Amount {
			return nil
		}
		wallet.Balance -= request.Amount
		if err := tx.Save(&wallet).Error; err != nil {
			return err
		}
		response.Balance = wallet.Balance
		ok = true
		return s.appendRecord(tx, LedgerEvent{
			PlayerID:     request.PlayerID,
			Type:         "spend",
			SinkID:       request.SinkID,
			Delta:        -request.Amount,
			BalanceAfter: wallet.Balance,
		})
	})
	return response, ok
}

func (s *GormService) Ledger(ctx context.Context, playerID string) []LedgerEvent {
	playerID = normalizePlayerID(playerID)
	records := []LedgerRecord{}
	_ = s.db.WithContext(ctx).
		Where("player_id = ?", playerID).
		Order("id asc").
		Find(&records).Error
	events := make([]LedgerEvent, 0, len(records))
	for _, record := range records {
		events = append(events, record.toEvent())
	}
	return events
}

func (s *GormService) Policy() Policy {
	return s.policy
}

func (s *GormService) walletForUpdate(
	tx *gorm.DB,
	playerID string,
	startingBalance int,
) (WalletRecord, bool, error) {
	var wallet WalletRecord
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		First(&wallet, "player_id = ?", playerID).Error
	if err == nil {
		return wallet, false, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return WalletRecord{}, false, err
	}
	wallet = WalletRecord{PlayerID: playerID, Balance: startingBalance}
	if err := tx.Create(&wallet).Error; err != nil {
		return WalletRecord{}, false, err
	}
	return wallet, true, nil
}

func (s *GormService) appendRecord(tx *gorm.DB, event LedgerEvent) error {
	var previous LedgerRecord
	err := tx.Where("player_id = ?", event.PlayerID).
		Order("id desc").
		First(&previous).Error
	if err == nil {
		event.PreviousChecksum = previous.Checksum
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	event.ID = eventRecordID(event)
	event.CreatedAt = time.Now().Unix()
	event.Checksum = checksum(event)
	return tx.Create(&LedgerRecord{
		EventID:          event.ID,
		PlayerID:         event.PlayerID,
		Type:             event.Type,
		GameID:           event.GameID,
		SourceID:         event.SourceID,
		SinkID:           event.SinkID,
		Delta:            event.Delta,
		BalanceAfter:     event.BalanceAfter,
		CreatedUnix:      event.CreatedAt,
		PreviousChecksum: event.PreviousChecksum,
		Checksum:         event.Checksum,
	}).Error
}

func (r LedgerRecord) toEvent() LedgerEvent {
	return LedgerEvent{
		ID:               r.EventID,
		PlayerID:         r.PlayerID,
		Type:             r.Type,
		GameID:           r.GameID,
		SourceID:         r.SourceID,
		SinkID:           r.SinkID,
		Delta:            r.Delta,
		BalanceAfter:     r.BalanceAfter,
		CreatedAt:        r.CreatedUnix,
		PreviousChecksum: r.PreviousChecksum,
		Checksum:         r.Checksum,
	}
}

func eventRecordID(event LedgerEvent) string {
	return event.PlayerID + "-" + event.Type + "-" + time.Now().Format("20060102150405.000000000")
}
