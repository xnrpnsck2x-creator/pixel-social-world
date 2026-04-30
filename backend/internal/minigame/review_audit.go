package minigame

import (
	"context"
	"sort"
	"time"
)

type ReviewAuditEvent struct {
	ID          string `json:"id"`
	GameID      string `json:"game_id"`
	Action      string `json:"action"`
	Status      string `json:"status"`
	Reviewer    string `json:"reviewer"`
	Source      string `json:"source"`
	Note        string `json:"note,omitempty"`
	RequestID   string `json:"request_id,omitempty"`
	CreatedUnix int64  `json:"created_unix"`
}

type ReviewAuditSnapshot struct {
	GameID string             `json:"game_id"`
	Items  []ReviewAuditEvent `json:"items"`
	Total  int                `json:"total,omitempty"`
	Limit  int                `json:"limit,omitempty"`
	Offset int                `json:"offset,omitempty"`
}

func (s *MemoryService) RecordReviewAudit(_ context.Context, event ReviewAuditEvent) error {
	event = normalizeReviewAuditEvent(event)
	s.mu.Lock()
	s.reviewAudit = append(s.reviewAudit, event)
	s.mu.Unlock()
	return nil
}

func (s *MemoryService) ReviewAudit(_ context.Context, gameID string) (ReviewAuditSnapshot, error) {
	s.mu.RLock()
	items := []ReviewAuditEvent{}
	for _, event := range s.reviewAudit {
		if event.GameID == gameID {
			items = append(items, event)
		}
	}
	s.mu.RUnlock()
	sortReviewAudit(items)
	return ReviewAuditSnapshot{GameID: gameID, Items: items, Total: len(items)}, nil
}

func normalizeReviewAuditEvent(event ReviewAuditEvent) ReviewAuditEvent {
	now := time.Now().Unix()
	if event.CreatedUnix <= 0 {
		event.CreatedUnix = now
	}
	if event.ID == "" {
		event.ID = event.GameID + ":" + event.Action + ":" + event.Status + ":" +
			time.Unix(event.CreatedUnix, 0).Format("20060102150405")
	}
	if event.Source == "" {
		event.Source = "admin-api"
	}
	return event
}

func sortReviewAudit(items []ReviewAuditEvent) {
	sort.Slice(items, func(left int, right int) bool {
		if items[left].CreatedUnix == items[right].CreatedUnix {
			return items[left].ID < items[right].ID
		}
		return items[left].CreatedUnix < items[right].CreatedUnix
	})
}
