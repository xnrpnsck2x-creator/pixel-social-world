package economy

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

func (s *GormService) GrantCreatorPlayReward(
	ctx context.Context,
	request CreatorPlayRewardRequest,
) (CreatorPlayRewardResponse, error) {
	request = normalizeCreatorReward(request)
	if err := validateCreatorReward(request); err != nil {
		return CreatorPlayRewardResponse{}, err
	}
	creatorAmount := creatorShareAmount(request.PlayerAmount, s.policy.CreatorShareBps)
	response := CreatorPlayRewardResponse{CreatorShareBps: s.policy.CreatorShareBps, CreatorAmount: creatorAmount}
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		playerWallet, _, err := s.walletForUpdate(tx, request.PlayerID, 0)
		if err != nil {
			return err
		}
		if hasLedgerEvent(tx, request.PlayerID, creatorPlayRewardType, request.SourceID) {
			response.CreatorAmount = 0
			response.Player = GrantResponse{PlayerID: request.PlayerID, Balance: playerWallet.Balance}
			creatorWallet, _, err := s.walletForUpdate(tx, request.CreatorID, 0)
			if err != nil {
				return err
			}
			response.Creator = GrantResponse{PlayerID: request.CreatorID, Balance: creatorWallet.Balance}
			return nil
		}
		request.PlayerAmount = s.cappedGrantAmount(tx, request.PlayerID, request.PlayerAmount, time.Now().Unix())
		creatorAmount = creatorShareAmount(request.PlayerAmount, s.policy.CreatorShareBps)
		response.CreatorAmount = creatorAmount
		playerWallet.Balance += request.PlayerAmount
		if err := tx.Save(&playerWallet).Error; err != nil {
			return err
		}
		if err := s.appendRecord(tx, LedgerEvent{
			PlayerID:     request.PlayerID,
			Type:         creatorPlayRewardType,
			GameID:       request.GameID,
			SourceID:     request.SourceID,
			Delta:        request.PlayerAmount,
			BalanceAfter: playerWallet.Balance,
		}); err != nil {
			return err
		}
		response.Player = GrantResponse{PlayerID: request.PlayerID, Balance: playerWallet.Balance, Delta: request.PlayerAmount}
		creatorWallet, _, err := s.walletForUpdate(tx, request.CreatorID, 0)
		if err != nil {
			return err
		}
		if request.CreatorID != request.PlayerID && creatorAmount > 0 {
			creatorWallet.Balance += creatorAmount
			if err := tx.Save(&creatorWallet).Error; err != nil {
				return err
			}
			if err := s.appendRecord(tx, LedgerEvent{
				PlayerID:     request.CreatorID,
				Type:         creatorRevenueShareType,
				GameID:       request.GameID,
				SourceID:     request.SourceID,
				Delta:        creatorAmount,
				BalanceAfter: creatorWallet.Balance,
			}); err != nil {
				return err
			}
		}
		response.Creator = GrantResponse{PlayerID: request.CreatorID, Balance: creatorWallet.Balance, Delta: creatorAmount}
		return nil
	})
	return response, err
}

func hasLedgerEvent(tx *gorm.DB, playerID string, eventType string, sourceID string) bool {
	var record LedgerRecord
	err := tx.First(&record, "player_id = ? AND type = ? AND source_id = ?", playerID, eventType, sourceID).Error
	return err == nil || !errors.Is(err, gorm.ErrRecordNotFound)
}

func (s *GormService) cappedGrantAmount(tx *gorm.DB, playerID string, requested int, now int64) int {
	if requested <= 0 || s.policy.DailySoftCap <= 0 {
		return maxInt(requested, 0)
	}
	var used int
	if err := tx.Model(&LedgerRecord{}).
		Select("COALESCE(SUM(delta), 0)").
		Where("player_id = ? AND type IN ? AND delta > 0 AND created_unix >= ?",
			playerID,
			[]string{"grant", creatorPlayRewardType},
			dailyGrantStartUnix(now),
		).
		Scan(&used).Error; err != nil {
		return 0
	}
	remaining := s.policy.DailySoftCap - used
	if remaining <= 0 {
		return 0
	}
	if requested > remaining {
		return remaining
	}
	return requested
}
