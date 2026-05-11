package economy

import (
	"context"
	"errors"
	"strings"
	"time"
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
		return s.creatorRewardResponseLocked(request, 0, 0, 0), nil
	}
	request.PlayerAmount = s.cappedGrantAmountLocked(request.PlayerID, request.PlayerAmount, time.Now().Unix())
	creatorAmount = creatorShareAmount(request.PlayerAmount, s.policy.CreatorShareBps)
	s.balances[request.PlayerID] += request.PlayerAmount
	s.record(request.PlayerID, LedgerEvent{
		Type:         creatorPlayRewardType,
		GameID:       request.GameID,
		SourceID:     request.SourceID,
		Delta:        request.PlayerAmount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	if request.CreatorID != request.PlayerID && creatorAmount > 0 {
		s.balances[request.CreatorID] += creatorAmount
		s.record(request.CreatorID, LedgerEvent{
			Type:         creatorRevenueShareType,
			GameID:       request.GameID,
			SourceID:     request.SourceID,
			Delta:        creatorAmount,
			BalanceAfter: s.balances[request.CreatorID],
		})
	}
	return s.creatorRewardResponseLocked(request, creatorAmount, request.PlayerAmount, creatorAmount), nil
}

func (s *MemoryService) creatorRewardResponseLocked(
	request CreatorPlayRewardRequest,
	creatorAmount int,
	playerDelta int,
	creatorDelta int,
) CreatorPlayRewardResponse {
	return CreatorPlayRewardResponse{
		Player:          GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID], Delta: playerDelta},
		Creator:         GrantResponse{PlayerID: request.CreatorID, Balance: s.balances[request.CreatorID], Delta: creatorDelta},
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
	if policy.DailySoftCap <= 0 {
		policy.DailySoftCap = DefaultPolicy().DailySoftCap
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

func (s *MemoryService) cappedGrantAmountLocked(playerID string, requested int, now int64) int {
	if requested <= 0 || s.policy.DailySoftCap <= 0 {
		return maxInt(requested, 0)
	}
	remaining := s.policy.DailySoftCap - s.dailyGrantUsedLocked(playerID, now)
	if remaining <= 0 {
		return 0
	}
	if requested > remaining {
		return remaining
	}
	return requested
}

func (s *MemoryService) dailyGrantUsedLocked(playerID string, now int64) int {
	used := 0
	dayStart := dailyGrantStartUnix(now)
	for _, event := range s.ledger[playerID] {
		if event.CreatedAt >= dayStart && countsTowardDailyCap(event.Type) && event.Delta > 0 {
			used += event.Delta
		}
	}
	return used
}

func countsTowardDailyCap(eventType string) bool {
	return eventType == "grant" || eventType == creatorPlayRewardType
}

func dailyGrantStartUnix(now int64) int64 {
	year, month, day := time.Unix(now, 0).UTC().Date()
	return time.Date(year, month, day, 0, 0, 0, 0, time.UTC).Unix()
}

func maxInt(left int, right int) int {
	if left > right {
		return left
	}
	return right
}
