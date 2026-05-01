package economy

import (
	"context"
	"errors"

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
			response.Player = GrantResponse{PlayerID: request.PlayerID, Balance: playerWallet.Balance}
			creatorWallet, _, err := s.walletForUpdate(tx, request.CreatorID, 0)
			if err != nil {
				return err
			}
			response.Creator = GrantResponse{PlayerID: request.CreatorID, Balance: creatorWallet.Balance}
			return nil
		}
		playerWallet.Balance += request.PlayerAmount
		if err := tx.Save(&playerWallet).Error; err != nil {
			return err
		}
		if err := s.appendRecord(tx, LedgerEvent{
			PlayerID:     request.PlayerID,
			Type:         creatorPlayRewardType,
			SourceID:     request.SourceID,
			Delta:        request.PlayerAmount,
			BalanceAfter: playerWallet.Balance,
		}); err != nil {
			return err
		}
		response.Player = GrantResponse{PlayerID: request.PlayerID, Balance: playerWallet.Balance}
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
				SourceID:     request.SourceID,
				Delta:        creatorAmount,
				BalanceAfter: creatorWallet.Balance,
			}); err != nil {
				return err
			}
		}
		response.Creator = GrantResponse{PlayerID: request.CreatorID, Balance: creatorWallet.Balance}
		return nil
	})
	return response, err
}

func hasLedgerEvent(tx *gorm.DB, playerID string, eventType string, sourceID string) bool {
	var record LedgerRecord
	err := tx.First(&record, "player_id = ? AND type = ? AND source_id = ?", playerID, eventType, sourceID).Error
	return err == nil || !errors.Is(err, gorm.ErrRecordNotFound)
}
