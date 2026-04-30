package chat

import (
	"context"
	"sort"
)

func (s *MemoryService) ApplyModeration(_ context.Context, request ModerationActionRequest) (ModerationAction, error) {
	request, err := normalizeModerationRequest(request)
	if err != nil {
		return ModerationAction{}, err
	}
	now := nowUnix()
	s.mu.Lock()
	defer s.mu.Unlock()
	if request.Action == ModerationActionRestore {
		s.revokeActiveModeration(request, now)
	}
	action := moderationActionFromRequest(request, now, len(s.moderationActions)+1)
	s.moderationActions = append(s.moderationActions, action)
	return action, nil
}

func (s *MemoryService) ModerationActions(_ context.Context, request ModerationListRequest) (ModerationSnapshot, error) {
	limit := moderationListLimit(request.Limit)
	offset := moderationListOffset(request.Offset)
	now := nowUnix()
	s.mu.RLock()
	active := make([]ModerationAction, 0, len(s.moderationActions))
	recent := make([]ModerationAction, 0, len(s.moderationActions))
	for _, action := range s.moderationActions {
		if request.TargetPlayerID != "" && action.TargetPlayerID != request.TargetPlayerID {
			continue
		}
		if request.Action != "" && action.Action != request.Action {
			continue
		}
		if activeModeration(action, action.RoomID, now) {
			active = append(active, action)
		}
		recent = append(recent, action)
	}
	s.mu.RUnlock()
	sortModerationNewestFirst(active)
	sortModerationNewestFirst(recent)
	recent = offsetModeration(recent, offset)
	if len(active) > limit {
		active = active[:limit]
	}
	if len(recent) > limit {
		recent = recent[:limit]
	}
	return ModerationSnapshot{GeneratedAt: now, Active: active, Recent: recent, Limit: limit, Offset: offset}, nil
}

func (s *MemoryService) revokeActiveModeration(request ModerationActionRequest, now int64) {
	for index := range s.moderationActions {
		action := &s.moderationActions[index]
		if action.TargetPlayerID != request.TargetPlayerID || !activeModeration(*action, request.RoomID, now) {
			continue
		}
		action.RevokedAt = now
		action.RevokedBy = request.ModeratorID
		action.RevocationReason = request.Reason
	}
}

func (s *MemoryService) activeModerationCount(now int64) int {
	count := 0
	for _, action := range s.moderationActions {
		if activeModeration(action, action.RoomID, now) {
			count++
		}
	}
	return count
}

func sortModerationNewestFirst(items []ModerationAction) {
	sort.Slice(items, func(left int, right int) bool {
		if items[left].CreatedAt == items[right].CreatedAt {
			return items[left].ID > items[right].ID
		}
		return items[left].CreatedAt > items[right].CreatedAt
	})
}

func moderationListOffset(offset int) int {
	if offset < 0 {
		return 0
	}
	return offset
}

func offsetModeration(items []ModerationAction, offset int) []ModerationAction {
	if offset <= 0 {
		return items
	}
	if offset >= len(items) {
		return []ModerationAction{}
	}
	return items[offset:]
}
