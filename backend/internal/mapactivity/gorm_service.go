package mapactivity

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"pixel-social-world/backend/internal/economy"
)

type CooldownRecord struct {
	ID          uint   `gorm:"primaryKey"`
	PlayerID    string `gorm:"uniqueIndex:idx_map_activity_cooldown;size:96"`
	MapID       string `gorm:"uniqueIndex:idx_map_activity_cooldown;size:96"`
	ActionID    string `gorm:"uniqueIndex:idx_map_activity_cooldown;size:96"`
	ReadyAtUnix int64
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type DailyRewardRecord struct {
	ID         uint   `gorm:"primaryKey"`
	PlayerID   string `gorm:"uniqueIndex:idx_map_activity_daily;size:96"`
	DateKey    string `gorm:"uniqueIndex:idx_map_activity_daily;size:16"`
	ActionID   string `gorm:"uniqueIndex:idx_map_activity_daily;size:96"`
	ClaimCount int
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type GormService struct {
	db              *gorm.DB
	economyService  economy.Service
	startingBalance int
	ruleset         Ruleset
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(&CooldownRecord{}, &DailyRewardRecord{})
}

func NewGormService(db *gorm.DB, economyService economy.Service, startingBalance int) Service {
	return NewGormServiceWithRuleset(db, economyService, startingBalance, DefaultRuleset())
}

func NewGormServiceWithRuleset(db *gorm.DB, economyService economy.Service, startingBalance int, ruleset Ruleset) Service {
	if economyService == nil {
		economyService = economy.NewGormService(db, startingBalance)
	}
	if startingBalance < 0 {
		startingBalance = 0
	}
	return &GormService{
		db:              db,
		economyService:  economyService,
		startingBalance: startingBalance,
		ruleset:         NormalizeRuleset(ruleset),
	}
}

func (s *GormService) Claim(ctx context.Context, request ClaimRequest) (ClaimResponse, error) {
	request = normalizeRequest(request)
	rule, err := validateRequest(s.ruleset, request)
	now := time.Now().Unix()
	if err != nil {
		return baseResponse(request, rule, now, economy.GrantResponse{PlayerID: request.PlayerID}), err
	}

	readyAt := now + rule.CooldownSeconds
	dateKey := dayKey(now)
	dailyCount := 0
	var cooldownErr error
	var dailyErr error
	transactionErr := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var record CooldownRecord
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("player_id = ? AND map_id = ? AND action_id = ?", request.PlayerID, request.MapID, request.ActionID).
			First(&record).Error
		if err == nil {
			if record.ReadyAtUnix > now {
				readyAt = record.ReadyAtUnix
				dailyCount = s.dailyRewardCount(tx, request, dateKey)
				cooldownErr = ErrCooldown
				return nil
			}
			if count, limitErr, err := s.advanceDailyReward(tx, request, rule, dateKey); err != nil {
				return err
			} else if limitErr != nil {
				dailyCount = count
				dailyErr = limitErr
				return nil
			} else {
				dailyCount = count
			}
			record.ReadyAtUnix = readyAt
			return tx.Save(&record).Error
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		if count, limitErr, err := s.advanceDailyReward(tx, request, rule, dateKey); err != nil {
			return err
		} else if limitErr != nil {
			dailyCount = count
			dailyErr = limitErr
			return nil
		} else {
			dailyCount = count
		}
		record = CooldownRecord{
			PlayerID:    request.PlayerID,
			MapID:       request.MapID,
			ActionID:    request.ActionID,
			ReadyAtUnix: readyAt,
		}
		return tx.Create(&record).Error
	})
	wallet := s.economyService.EnsurePlayer(ctx, request.PlayerID, s.startingBalance)
	if transactionErr != nil {
		return baseResponse(request, rule, now, wallet), transactionErr
	}
	if cooldownErr != nil {
		return cooldownResponse(request, rule, now, readyAt, dailyCount, wallet), cooldownErr
	}
	if dailyErr != nil {
		return dailyLimitResponse(request, rule, now, dailyCount, wallet), dailyErr
	}
	if rule.RewardCoins > 0 {
		wallet = s.economyService.Grant(ctx, economy.GrantRequest{
			PlayerID: request.PlayerID,
			SourceID: sourceID(rule, request),
			Amount:   rule.RewardCoins,
		})
	}
	return ClaimResponse{
		PlayerID:         request.PlayerID,
		MapID:            request.MapID,
		ActionID:         request.ActionID,
		RewardCoins:      wallet.Delta,
		SkillID:          rule.SkillID,
		SkillXP:          rule.SkillXP,
		Drops:            copyDrops(rule.Drops),
		RareEvent:        rareEventResult(rule, request, now, dailyCount),
		CooldownSeconds:  rule.CooldownSeconds,
		DailyRewardLimit: dailyLimit(rule),
		DailyRewardCount: dailyCount,
		ReadyAt:          readyAt,
		ReadyInSeconds:   maxInt64(0, readyAt-now),
		ServerTime:       now,
		Claimed:          true,
		Wallet:           wallet,
	}, nil
}

func (s *GormService) advanceDailyReward(
	tx *gorm.DB,
	request ClaimRequest,
	rule ActivityRule,
	dateKey string,
) (int, error, error) {
	if !tracksDailyReward(rule) {
		return 0, nil, nil
	}
	record := DailyRewardRecord{
		PlayerID: request.PlayerID,
		DateKey:  dateKey,
		ActionID: request.ActionID,
	}
	if err := tx.Clauses(clause.OnConflict{DoNothing: true}).Create(&record).Error; err != nil {
		return 0, nil, err
	}
	if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("player_id = ? AND date_key = ? AND action_id = ?", request.PlayerID, dateKey, request.ActionID).
		First(&record).Error; err != nil {
		return 0, nil, err
	}
	if dailyLimitReached(rule, record.ClaimCount) {
		return record.ClaimCount, ErrDailyLimit, nil
	}
	record.ClaimCount++
	if err := tx.Save(&record).Error; err != nil {
		return 0, nil, err
	}
	return record.ClaimCount, nil, nil
}

func (s *GormService) dailyRewardCount(tx *gorm.DB, request ClaimRequest, dateKey string) int {
	var record DailyRewardRecord
	if err := tx.
		Where("player_id = ? AND date_key = ? AND action_id = ?", request.PlayerID, dateKey, request.ActionID).
		First(&record).Error; err != nil {
		return 0
	}
	return record.ClaimCount
}
