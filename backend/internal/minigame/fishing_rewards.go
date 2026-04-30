package minigame

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"

	"pixel-social-world/backend/internal/economy"
)

const DefaultFishingSessionCatchLimit = 10

var (
	ErrInvalidFishingSession   = errors.New("invalid_fishing_session")
	ErrFishingSessionForbidden = errors.New("session_forbidden")
	ErrFishingRewardCap        = errors.New("fishing_session_reward_cap")
	ErrFishingRequestPending   = errors.New("fishing_request_pending")
)

type FishingCatchRequest struct {
	PlayerID  string
	SessionID string
	RequestID string
}

type FishingCatchResponse struct {
	PlayerID    string `json:"player_id"`
	SessionID   string `json:"session_id"`
	RequestID   string `json:"request_id,omitempty"`
	CatchNumber int    `json:"catch_number"`
	FishID      string `json:"fish_id"`
	FishNameKey string `json:"fish_name_key"`
	Rarity      string `json:"rarity"`
	RewardCoin  int    `json:"reward_coin"`
	Balance     int    `json:"balance"`
}

type FishingReward struct {
	FishID     string
	NameKey    string
	Rarity     string
	Weight     int
	RewardCoin int
}

type FishingRewardRules struct {
	RewardLimit int
	Rewards     []FishingReward
}

type FishingRewardService interface {
	ClaimCatch(ctx context.Context, request FishingCatchRequest) (FishingCatchResponse, error)
	Stats(ctx context.Context) FishingRewardStats
}

type FishingRewardStats struct {
	Backend        string `json:"backend"`
	Granted        int64  `json:"granted"`
	Replayed       int64  `json:"replayed"`
	Capped         int64  `json:"capped"`
	Pending        int64  `json:"pending"`
	Errors         int64  `json:"errors"`
	ActiveCounters int    `json:"active_counters"`
	StoredRequests int    `json:"stored_requests"`
}

type fishingRewardMetrics struct {
	granted  atomic.Int64
	replayed atomic.Int64
	capped   atomic.Int64
	pending  atomic.Int64
	errors   atomic.Int64
}

type MemoryFishingRewardService struct {
	sessions  Service
	economy   economy.Service
	rules     FishingRewardRules
	counts    map[string]int
	responses map[string]FishingCatchResponse
	metrics   fishingRewardMetrics
	mu        sync.Mutex
}

func NewMemoryFishingRewardService(
	sessions Service,
	economyService economy.Service,
	rules FishingRewardRules,
) *MemoryFishingRewardService {
	rules = normalizeFishingRules(rules)
	return &MemoryFishingRewardService{
		sessions:  sessions,
		economy:   economyService,
		rules:     rules,
		counts:    map[string]int{},
		responses: map[string]FishingCatchResponse{},
	}
}

func (s *MemoryFishingRewardService) ClaimCatch(
	ctx context.Context,
	request FishingCatchRequest,
) (FishingCatchResponse, error) {
	session, ok := s.sessions.GetSession(ctx, request.SessionID)
	if !ok || session.GameID != "fishing" {
		s.metrics.errors.Add(1)
		return FishingCatchResponse{}, ErrInvalidFishingSession
	}
	if !fishingSessionHasPlayer(session.Players, request.PlayerID) {
		s.metrics.errors.Add(1)
		return FishingCatchResponse{}, ErrFishingSessionForbidden
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	requestKey := fishingRequestKey(session.ID, request.PlayerID, request.RequestID)
	if requestKey != "" {
		if response, ok := s.responses[requestKey]; ok {
			s.metrics.replayed.Add(1)
			return response, nil
		}
	}
	catchNumber, ok := s.nextCatchLocked(session.ID, request.PlayerID)
	if !ok {
		s.metrics.capped.Add(1)
		return FishingCatchResponse{}, ErrFishingRewardCap
	}
	reward := pickFishingReward(s.rules.Rewards)
	balance := s.economy.Grant(ctx, economy.GrantRequest{
		PlayerID: request.PlayerID,
		SourceID: fmt.Sprintf("minigame.fishing.%s.%s.%02d", session.ID, request.PlayerID, catchNumber),
		Amount:   reward.RewardCoin,
	})
	response := FishingCatchResponse{
		PlayerID:    request.PlayerID,
		SessionID:   session.ID,
		RequestID:   request.RequestID,
		CatchNumber: catchNumber,
		FishID:      reward.FishID,
		FishNameKey: reward.NameKey,
		Rarity:      reward.Rarity,
		RewardCoin:  reward.RewardCoin,
		Balance:     balance.Balance,
	}
	if requestKey != "" {
		s.responses[requestKey] = response
	}
	s.metrics.granted.Add(1)
	return response, nil
}

func (s *MemoryFishingRewardService) Stats(_ context.Context) FishingRewardStats {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.statsLocked("memory")
}

func (s *MemoryFishingRewardService) nextCatchLocked(sessionID string, playerID string) (int, bool) {
	key := fmt.Sprintf("%s:%s", sessionID, playerID)
	next := s.counts[key] + 1
	if next > s.rules.RewardLimit {
		return next, false
	}
	s.counts[key] = next
	return next, true
}

func (s *MemoryFishingRewardService) statsLocked(backend string) FishingRewardStats {
	return FishingRewardStats{
		Backend:        backend,
		Granted:        s.metrics.granted.Load(),
		Replayed:       s.metrics.replayed.Load(),
		Capped:         s.metrics.capped.Load(),
		Pending:        s.metrics.pending.Load(),
		Errors:         s.metrics.errors.Load(),
		ActiveCounters: len(s.counts),
		StoredRequests: len(s.responses),
	}
}
