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

type GrantResponse struct {
	PlayerID string `json:"player_id"`
	Balance  int    `json:"balance"`
}

type LedgerEvent struct {
	ID               string `json:"id"`
	PlayerID         string `json:"player_id"`
	Type             string `json:"type"`
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
	Spend(ctx context.Context, request SpendRequest) (GrantResponse, bool)
	Ledger(ctx context.Context, playerID string) []LedgerEvent
}

type MemoryService struct {
	mu       sync.Mutex
	balances map[string]int
	ledger   map[string][]LedgerEvent
}

func NewMemoryService() Service {
	service := &MemoryService{
		balances: map[string]int{"offline-player": 25},
		ledger:   map[string][]LedgerEvent{},
	}
	service.record("offline-player", LedgerEvent{
		Type:         "system.init",
		SourceID:     "profile_init",
		Delta:        25,
		BalanceAfter: 25,
	})
	return service
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
	s.balances[request.PlayerID] += request.Amount
	s.record(request.PlayerID, LedgerEvent{
		Type:         "grant",
		SourceID:     request.SourceID,
		Delta:        request.Amount,
		BalanceAfter: s.balances[request.PlayerID],
	})
	return GrantResponse{
		PlayerID: request.PlayerID,
		Balance:  s.balances[request.PlayerID],
	}
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

func (s *MemoryService) Ledger(_ context.Context, playerID string) []LedgerEvent {
	playerID = normalizePlayerID(playerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	events := s.ledger[playerID]
	copied := make([]LedgerEvent, len(events))
	copy(copied, events)
	return copied
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
