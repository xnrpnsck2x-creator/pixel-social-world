package social

import (
	"context"
	"sort"
	"sync"
	"time"
)

type MemoryService struct {
	mu        sync.Mutex
	relations map[string]relationEntry
}

func NewMemoryService() Service {
	return &MemoryService{relations: map[string]relationEntry{}}
}

func (s *MemoryService) Follow(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return RelationshipState{}, err
	}
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.blockedLocked(request.PlayerID, request.TargetPlayerID) {
		return s.stateLocked(request), nil
	}
	entry := s.entryLocked(request.PlayerID, request.TargetPlayerID)
	entry.Following = true
	entry.UpdatedAt = time.Now().Unix()
	s.relations[relationshipKey(request.PlayerID, request.TargetPlayerID)] = entry
	return s.stateLocked(request), nil
}

func (s *MemoryService) Unfollow(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return RelationshipState{}, err
	}
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.entryLocked(request.PlayerID, request.TargetPlayerID)
	entry.Following = false
	entry.UpdatedAt = time.Now().Unix()
	s.relations[relationshipKey(request.PlayerID, request.TargetPlayerID)] = entry
	return s.stateLocked(request), nil
}

func (s *MemoryService) Block(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return RelationshipState{}, err
	}
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.entryLocked(request.PlayerID, request.TargetPlayerID)
	entry.Blocked = true
	entry.Following = false
	entry.UpdatedAt = time.Now().Unix()
	s.relations[relationshipKey(request.PlayerID, request.TargetPlayerID)] = entry
	reverse := s.entryLocked(request.TargetPlayerID, request.PlayerID)
	reverse.Following = false
	reverse.UpdatedAt = entry.UpdatedAt
	s.relations[relationshipKey(request.TargetPlayerID, request.PlayerID)] = reverse
	return s.stateLocked(request), nil
}

func (s *MemoryService) Unblock(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return RelationshipState{}, err
	}
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	entry := s.entryLocked(request.PlayerID, request.TargetPlayerID)
	entry.Blocked = false
	entry.UpdatedAt = time.Now().Unix()
	s.relations[relationshipKey(request.PlayerID, request.TargetPlayerID)] = entry
	return s.stateLocked(request), nil
}

func (s *MemoryService) State(ctx context.Context, request RelationshipRequest) (RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return RelationshipState{}, err
	}
	request, err := normalizeRequest(request)
	if err != nil {
		return RelationshipState{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.stateLocked(request), nil
}

func (s *MemoryService) Following(ctx context.Context, request ListRequest) ([]RelationshipState, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	request, err := normalizeListRequest(request)
	if err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	targets := []string{}
	for key, entry := range s.relations {
		playerID, targetID, ok := splitKey(key)
		if ok && playerID == request.PlayerID && entry.Following {
			targets = append(targets, targetID)
		}
	}
	sort.Strings(targets)
	if len(targets) > request.Limit {
		targets = targets[:request.Limit]
	}
	states := make([]RelationshipState, 0, len(targets))
	for _, targetID := range targets {
		states = append(states, s.stateLocked(RelationshipRequest{
			PlayerID: request.PlayerID, TargetPlayerID: targetID,
		}))
	}
	return states, nil
}

func (s *MemoryService) Blocked(ctx context.Context, playerID string, targetPlayerID string) bool {
	if ctx.Err() != nil {
		return true
	}
	request, err := normalizeRequest(RelationshipRequest{
		PlayerID: playerID, TargetPlayerID: targetPlayerID,
	})
	if err != nil {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.blockedLocked(request.PlayerID, request.TargetPlayerID)
}

func (s *MemoryService) entryLocked(playerID string, targetPlayerID string) relationEntry {
	return s.relations[relationshipKey(playerID, targetPlayerID)]
}

func (s *MemoryService) blockedLocked(playerID string, targetPlayerID string) bool {
	return s.entryLocked(playerID, targetPlayerID).Blocked ||
		s.entryLocked(targetPlayerID, playerID).Blocked
}

func (s *MemoryService) stateLocked(request RelationshipRequest) RelationshipState {
	entry := s.entryLocked(request.PlayerID, request.TargetPlayerID)
	reverse := s.entryLocked(request.TargetPlayerID, request.PlayerID)
	updated := entry.UpdatedAt
	if reverse.UpdatedAt > updated {
		updated = reverse.UpdatedAt
	}
	return RelationshipState{
		PlayerID:       request.PlayerID,
		TargetPlayerID: request.TargetPlayerID,
		Following:      entry.Following,
		FollowedBy:     reverse.Following,
		Blocked:        entry.Blocked,
		BlockedBy:      reverse.Blocked,
		UpdatedAt:      updated,
	}
}

func splitKey(key string) (string, string, bool) {
	for index := 0; index < len(key); index++ {
		if key[index] == 0 {
			return key[:index], key[index+1:], true
		}
	}
	return "", "", false
}
