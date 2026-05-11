package economy

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sync"
	"time"
)

type GrantRequest struct {
	PlayerID string `json:"player_id"`
	SourceID string `json:"source_id"`
	Amount   int    `json:"amount"`
}

type SpendRequest struct {
	PlayerID string `json:"player_id"`
	SinkID   string `json:"sink_id"`
	Amount   int    `json:"amount"`
}

type TransferRequest struct {
	FromPlayerID string `json:"from_player_id"`
	ToPlayerID   string `json:"to_player_id"`
	SourceID     string `json:"source_id"`
	SinkID       string `json:"sink_id"`
	Amount       int    `json:"amount"`
}

type CreatorPlayRewardRequest struct {
	PlayerID     string `json:"player_id"`
	CreatorID    string `json:"creator_id"`
	GameID       string `json:"game_id"`
	SourceID     string `json:"source_id"`
	PlayerAmount int    `json:"player_amount"`
}

type GrantResponse struct {
	PlayerID string `json:"player_id"`
	Balance  int    `json:"balance"`
	Delta    int    `json:"delta"`
}

type CreatorPlayRewardResponse struct {
	Player          GrantResponse `json:"player"`
	Creator         GrantResponse `json:"creator"`
	CreatorAmount   int           `json:"creator_amount"`
	CreatorShareBps int           `json:"creator_share_bps"`
}

type TransferResponse struct {
	From   GrantResponse `json:"from"`
	To     GrantResponse `json:"to"`
	Amount int           `json:"amount"`
}

type Policy struct {
	CreatorShareBps int `json:"creator_share_bps"`
	DailySoftCap    int `json:"daily_soft_cap"`
}

type Stats struct {
	TotalLedgerEvents    int `json:"total_ledger_events"`
	GrantEvents          int `json:"grant_events"`
	SpendEvents          int `json:"spend_events"`
	RewardCapHits        int `json:"reward_cap_hits"`
	CreatorPlayRewards   int `json:"creator_play_rewards"`
	CreatorRevenueShares int `json:"creator_revenue_shares"`
	CreatorRevenueCoins  int `json:"creator_revenue_coins"`
}

type CreatorPayoutRow struct {
	CreatorID      string `json:"creator_id"`
	GameID         string `json:"game_id"`
	RevenueEvents  int    `json:"revenue_events"`
	RevenueCoins   int    `json:"revenue_coins"`
	LastRevenueAt  int64  `json:"last_revenue_at"`
	RecentSourceID string `json:"recent_source_id,omitempty"`
}

type CreatorPayoutSnapshot struct {
	Items              []CreatorPayoutRow `json:"items"`
	Count              int                `json:"count"`
	Matched            int                `json:"matched"`
	Limit              int                `json:"limit"`
	TotalCreators      int                `json:"total_creators"`
	TotalRevenueEvents int                `json:"total_revenue_events"`
	TotalRevenueCoins  int                `json:"total_revenue_coins"`
}

type LedgerEvent struct {
	ID               string `json:"id"`
	PlayerID         string `json:"player_id"`
	Type             string `json:"type"`
	GameID           string `json:"game_id,omitempty"`
	SourceID         string `json:"source_id,omitempty"`
	SinkID           string `json:"sink_id,omitempty"`
	Delta            int    `json:"delta"`
	BalanceAfter     int    `json:"balance_after"`
	CreatedAt        int64  `json:"created_at"`
	PreviousChecksum string `json:"previous_checksum"`
	Checksum         string `json:"checksum"`
}

type Service interface {
	Balance(ctx context.Context, playerID string) GrantResponse
	EnsurePlayer(ctx context.Context, playerID string, startingBalance int) GrantResponse
	Grant(ctx context.Context, request GrantRequest) GrantResponse
	GrantOnce(ctx context.Context, request GrantRequest) GrantResponse
	GrantCreatorPlayReward(ctx context.Context, request CreatorPlayRewardRequest) (CreatorPlayRewardResponse, error)
	Spend(ctx context.Context, request SpendRequest) (GrantResponse, bool)
	Transfer(ctx context.Context, request TransferRequest) (TransferResponse, bool)
	Ledger(ctx context.Context, playerID string) []LedgerEvent
	Policy() Policy
	Stats(ctx context.Context) Stats
	CreatorPayouts(ctx context.Context, limit int) CreatorPayoutSnapshot
}

type MemoryService struct {
	mu       sync.Mutex
	balances map[string]int
	ledger   map[string][]LedgerEvent
	policy   Policy
}

func NewMemoryService() Service {
	return NewMemoryServiceWithPolicy(DefaultPolicy())
}

func NewMemoryServiceWithPolicy(policy Policy) Service {
	policy = normalizePolicy(policy)
	service := &MemoryService{
		balances: map[string]int{"offline-player": 25},
		ledger:   map[string][]LedgerEvent{},
		policy:   policy,
	}
	service.record("offline-player", LedgerEvent{
		Type:         "system.init",
		SourceID:     "profile_init",
		Delta:        25,
		BalanceAfter: 25,
	})
	return service
}

func DefaultPolicy() Policy {
	return Policy{CreatorShareBps: 1000, DailySoftCap: 400}
}

func (s *MemoryService) Balance(_ context.Context, playerID string) GrantResponse {
	playerID = normalizePlayerID(playerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	return GrantResponse{PlayerID: playerID, Balance: s.balances[playerID]}
}

func (s *MemoryService) EnsurePlayer(_ context.Context, playerID string, startingBalance int) GrantResponse {
	playerID = normalizePlayerID(playerID)
	if startingBalance < 0 {
		startingBalance = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.balances[playerID]; !ok {
		s.balances[playerID] = startingBalance
		s.record(playerID, LedgerEvent{
			Type:         "system.init",
			SourceID:     "profile_init",
			Delta:        startingBalance,
			BalanceAfter: startingBalance,
		})
	}
	return GrantResponse{PlayerID: playerID, Balance: s.balances[playerID]}
}

func (s *MemoryService) Grant(_ context.Context, request GrantRequest) GrantResponse {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	amount := s.cappedGrantAmountLocked(request.PlayerID, request.Amount, time.Now().Unix())
	s.balances[request.PlayerID] += amount
	s.record(request.PlayerID, LedgerEvent{
		Type:         "grant",
		SourceID:     request.SourceID,
		Delta:        amount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	return GrantResponse{
		PlayerID: request.PlayerID,
		Balance:  s.balances[request.PlayerID],
		Delta:    amount,
	}
}

func (s *MemoryService) GrantOnce(_ context.Context, request GrantRequest) GrantResponse {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if request.SourceID != "" && s.hasEventLocked(request.PlayerID, "grant", request.SourceID) {
		return GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID]}
	}
	amount := s.cappedGrantAmountLocked(request.PlayerID, request.Amount, time.Now().Unix())
	s.balances[request.PlayerID] += amount
	s.record(request.PlayerID, LedgerEvent{
		Type:         "grant",
		SourceID:     request.SourceID,
		Delta:        amount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	return GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID], Delta: amount}
}

func (s *MemoryService) Spend(_ context.Context, request SpendRequest) (GrantResponse, bool) {
	request.PlayerID = normalizePlayerID(request.PlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if s.balances[request.PlayerID] < request.Amount {
		return GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID]}, false
	}
	s.balances[request.PlayerID] -= request.Amount
	s.record(request.PlayerID, LedgerEvent{
		Type:         "spend",
		SinkID:       request.SinkID,
		Delta:        -request.Amount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	return GrantResponse{PlayerID: request.PlayerID, Balance: s.balances[request.PlayerID]}, true
}

func (s *MemoryService) Transfer(_ context.Context, request TransferRequest) (TransferResponse, bool) {
	request.FromPlayerID = normalizePlayerID(request.FromPlayerID)
	request.ToPlayerID = normalizePlayerID(request.ToPlayerID)
	if request.Amount < 0 {
		request.Amount = 0
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	response := TransferResponse{
		From:   GrantResponse{PlayerID: request.FromPlayerID, Balance: s.balances[request.FromPlayerID]},
		To:     GrantResponse{PlayerID: request.ToPlayerID, Balance: s.balances[request.ToPlayerID]},
		Amount: request.Amount,
	}
	if request.FromPlayerID == request.ToPlayerID {
		return response, true
	}
	if s.balances[request.FromPlayerID] < request.Amount {
		return response, false
	}
	s.balances[request.FromPlayerID] -= request.Amount
	s.record(request.FromPlayerID, LedgerEvent{
		Type:         "transfer.out",
		SinkID:       request.SinkID,
		Delta:        -request.Amount,
		BalanceAfter: s.balances[request.FromPlayerID],
	})
	s.balances[request.ToPlayerID] += request.Amount
	s.record(request.ToPlayerID, LedgerEvent{
		Type:         "transfer.in",
		SourceID:     request.SourceID,
		Delta:        request.Amount,
		BalanceAfter: s.balances[request.ToPlayerID],
	})
	return TransferResponse{
		From:   GrantResponse{PlayerID: request.FromPlayerID, Balance: s.balances[request.FromPlayerID], Delta: -request.Amount},
		To:     GrantResponse{PlayerID: request.ToPlayerID, Balance: s.balances[request.ToPlayerID], Delta: request.Amount},
		Amount: request.Amount,
	}, true
}

func (s *MemoryService) Ledger(_ context.Context, playerID string) []LedgerEvent {
	playerID = normalizePlayerID(playerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	events := s.ledger[playerID]
	copied := make([]LedgerEvent, len(events))
	copy(copied, events)
	return copied
}

func (s *MemoryService) Policy() Policy {
	return s.policy
}

func (s *MemoryService) record(playerID string, event LedgerEvent) {
	events := s.ledger[playerID]
	event.ID = fmt.Sprintf("%s-%06d", playerID, len(events)+1)
	event.PlayerID = playerID
	event.CreatedAt = time.Now().Unix()
	if len(events) > 0 {
		event.PreviousChecksum = events[len(events)-1].Checksum
	}
	event.Checksum = checksum(event)
	s.ledger[playerID] = append(events, event)
}

func normalizePlayerID(playerID string) string {
	if playerID == "" {
		return "offline-player"
	}
	return playerID
}

func checksum(event LedgerEvent) string {
	event.Checksum = ""
	encoded, err := json.Marshal(event)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(encoded)
	return hex.EncodeToString(sum[:])
}
