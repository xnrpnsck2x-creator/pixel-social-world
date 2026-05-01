package economy

import (
	"context"
	"errors"
	"strings"
)

const creatorPlayRewardType = "creator.play_reward"
const creatorRevenueShareType = "creator.revenue_share"

func (s *MemoryService) GrantCreatorPlayReward(
	_ context.Context,
	request CreatorPlayRewardRequest,
) (CreatorPlayRewardResponse, error) {
	request = normalizeCreatorReward(request)
	if err := validateCreatorReward(request); err != nil {
		return CreatorPlayRewardResponse{}, err
	}
	creatorAmount := creatorShareAmount(request.PlayerAmount, s.policy.CreatorShareBps)
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.hasEventLocked(request.PlayerID, creatorPlayRewardType, request.SourceID) {
		return s.creatorRewardResponseLocked(request, creatorAmount), nil
	}
	s.balances[request.PlayerID] += request.PlayerAmount
	s.record(request.PlayerID, LedgerEvent{
		Type:         creatorPlayRewardType,
		SourceID:     request.SourceID,
		Delta:        request.PlayerAmount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	if request.CreatorID != request.PlayerID && creatorAmount > 0 {
		s.balances[request.CreatorID] += creatorAmount
		s.record(request.CreatorID, LedgerEvent{
			Type:         creatorRevenueShareType,
			SourceID:     request.SourceID,
			Delta:        creatorAmount,
			BalanceAfter: s.balances[request.CreatorID],
		})
	}
	return s.creatorRewardResponseLocked(request, creatorAmount), nil
}

func (s *MemoryService) creatorRewardResponseLocked(
	request CreatorPlayRewardRequest,
	creatorAmount int,
) CreatorPlayRewardResponse {
	return CreatorPlayRewardResponse{
		Player:          GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID]},
		Creator:         GrantResponse{PlayerID: request.CreatorID, Balance: s.balances[request.CreatorID]},
		CreatorAmount:   creatorAmount,
		CreatorShareBps: s.policy.CreatorShareBps,
	}
}

func (s *MemoryService) hasEventLocked(playerID string, eventType string, sourceID string) bool {
	for _, event := range s.ledger[playerID] {
		if event.Type == eventType && event.SourceID == sourceID {
			return true
		}
	}
	return false
}

func normalizePolicy(policy Policy) Policy {
	if policy.CreatorShareBps < 0 {
		policy.CreatorShareBps = 0
	}
	if policy.CreatorShareBps > 10000 {
		policy.CreatorShareBps = 10000
	}
	return policy
}

func normalizeCreatorReward(request CreatorPlayRewardRequest) CreatorPlayRewardRequest {
	request.PlayerID = normalizePlayerID(strings.TrimSpace(request.PlayerID))
	request.CreatorID = normalizePlayerID(strings.TrimSpace(request.CreatorID))
	request.GameID = strings.TrimSpace(request.GameID)
	request.SourceID = strings.TrimSpace(request.SourceID)
	return request
}

func validateCreatorReward(request CreatorPlayRewardRequest) error {
	if request.PlayerID == "" || request.CreatorID == "" || request.GameID == "" || request.SourceID == "" {
		return errors.New("creator_reward_required")
	}
	if request.PlayerAmount < 0 {
		return errors.New("invalid_reward_amount")
	}
	return nil
}

func creatorShareAmount(playerAmount int, shareBps int) int {
	if playerAmount <= 0 || shareBps <= 0 {
		return 0
	}
	return playerAmount * shareBps / 10000
}
