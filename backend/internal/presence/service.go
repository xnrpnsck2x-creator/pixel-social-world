package presence

import (
	"context"
	"sync"
	"time"
)

const defaultRoomID = "world_town_square"
const defaultPlayerID = "offline-player"

type HeartbeatRequest struct {
	PlayerID    string `json:"player_id"`
	RoomID      string `json:"room_id"`
	DisplayName string `json:"display_name"`
}

type Presence struct {
	PlayerID    string `json:"player_id"`
	RoomID      string `json:"room_id"`
	DisplayName string `json:"display_name"`
	LastSeenAt  int64  `json:"last_seen_at"`
	ExpiresAt   int64  `json:"expires_at"`
}

type Service interface {
	Heartbeat(ctx context.Context, request HeartbeatRequest) (Presence, error)
	RoomMembers(ctx context.Context, roomID string) ([]Presence, error)
	Remove(ctx context.Context, roomID string, playerID string) error
}

type MemoryService struct {
	mu      sync.RWMutex
	ttl     time.Duration
	members map[string]map[string]Presence
}

func NewMemoryService(ttl time.Duration) Service {
	if ttl <= 0 {
		ttl = 30 * time.Second
	}
	return &MemoryService{
		ttl:     ttl,
		members: map[string]map[string]Presence{},
	}
}

func (s *MemoryService) Heartbeat(_ context.Context, request HeartbeatRequest) (Presence, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.PlayerID = normalize(request.PlayerID, defaultPlayerID)
	now := time.Now()
	record := Presence{
		PlayerID:    request.PlayerID,
		RoomID:      request.RoomID,
		DisplayName: normalize(request.DisplayName, "Guest"),
		LastSeenAt:  now.UnixMilli(),
		ExpiresAt:   now.Add(s.ttl).UnixMilli(),
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.members[request.RoomID] == nil {
		s.members[request.RoomID] = map[string]Presence{}
	}
	s.members[request.RoomID][request.PlayerID] = record
	return record, nil
}

func (s *MemoryService) RoomMembers(_ context.Context, roomID string) ([]Presence, error) {
	roomID = normalize(roomID, defaultRoomID)
	now := time.Now().UnixMilli()
	s.mu.Lock()
	defer s.mu.Unlock()
	roomMembers := s.members[roomID]
	members := []Presence{}
	for playerID, record := range roomMembers {
		if record.ExpiresAt <= now {
			delete(roomMembers, playerID)
			continue
		}
		members = append(members, record)
	}
	return members, nil
}

func (s *MemoryService) Remove(_ context.Context, roomID string, playerID string) error {
	roomID = normalize(roomID, defaultRoomID)
	playerID = normalize(playerID, defaultPlayerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.members[roomID], playerID)
	return nil
}

func normalize(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
