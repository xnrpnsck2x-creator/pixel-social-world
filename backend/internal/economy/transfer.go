package economy

import (
	"context"
	"sort"

	"gorm.io/gorm"
)

func (s *GormService) Transfer(ctx context.Context, request TransferRequest) (TransferResponse, bool) {
	response := TransferResponse{}
	ok := false
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		nextResponse, nextOK, err := s.TransferInTransaction(tx, request)
		response = nextResponse
		ok = nextOK
		return err
	})
	if err != nil {
		return response, false
	}
	return response, ok
}

func (s *GormService) TransferInTransaction(
	tx *gorm.DB,
	request TransferRequest,
) (TransferResponse, bool, error) {
	request.FromPlayerID = normalizePlayerID(request.FromPlayerID)
	request.ToPlayerID = normalizePlayerID(request.ToPlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}
	wallets, err := s.lockTransferWallets(tx, request.FromPlayerID, request.ToPlayerID)
	if err != nil {
		return TransferResponse{}, false, err
	}
	from := wallets[request.FromPlayerID]
	to := wallets[request.ToPlayerID]
	response := TransferResponse{
		From:   GrantResponse{PlayerID: request.FromPlayerID, Balance: from.Balance},
		To:     GrantResponse{PlayerID: request.ToPlayerID, Balance: to.Balance},
		Amount: request.Amount,
	}
	if request.FromPlayerID == request.ToPlayerID {
		return response, true, nil
	}
	if from.Balance < request.Amount {
		return response, false, nil
	}
	from.Balance -= request.Amount
	if err := tx.Save(&from).Error; err != nil {
		return response, false, err
	}
	if err := s.appendRecord(tx, LedgerEvent{
		PlayerID:     request.FromPlayerID,
		Type:         "transfer.out",
		SinkID:       request.SinkID,
		Delta:        -request.Amount,
		BalanceAfter: from.Balance,
	}); err != nil {
		return response, false, err
	}
	to.Balance += request.Amount
	if err := tx.Save(&to).Error; err != nil {
		return response, false, err
	}
	if err := s.appendRecord(tx, LedgerEvent{
		PlayerID:     request.ToPlayerID,
		Type:         "transfer.in",
		SourceID:     request.SourceID,
		Delta:        request.Amount,
		BalanceAfter: to.Balance,
	}); err != nil {
		return response, false, err
	}
	return TransferResponse{
		From:   GrantResponse{PlayerID: request.FromPlayerID, Balance: from.Balance, Delta: -request.Amount},
		To:     GrantResponse{PlayerID: request.ToPlayerID, Balance: to.Balance, Delta: request.Amount},
		Amount: request.Amount,
	}, true, nil
}

func (s *GormService) lockTransferWallets(tx *gorm.DB, left string, right string) (map[string]WalletRecord, error) {
	ids := []string{left}
	if right != left {
		ids = append(ids, right)
	}
	sort.Strings(ids)
	wallets := make(map[string]WalletRecord, len(ids))
	for _, id := range ids {
		wallet, _, err := s.walletForUpdate(tx, id, 0)
		if err != nil {
			return nil, err
		}
		wallets[id] = wallet
	}
	return wallets, nil
}
