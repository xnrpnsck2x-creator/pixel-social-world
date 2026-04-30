package gateway

import "pixel-social-world/backend/internal/minigame"

type reviewAuditFilter struct {
	Action string
	Status string
	Source string
	Limit  int
	Offset int
}

func filterReviewAuditSnapshot(
	snapshot minigame.ReviewAuditSnapshot,
	filter reviewAuditFilter,
) minigame.ReviewAuditSnapshot {
	items := make([]minigame.ReviewAuditEvent, 0, len(snapshot.Items))
	for _, item := range snapshot.Items {
		if filter.Action != "" && item.Action != filter.Action {
			continue
		}
		if filter.Status != "" && item.Status != filter.Status {
			continue
		}
		if filter.Source != "" && item.Source != filter.Source {
			continue
		}
		items = append(items, item)
	}
	total := len(items)
	offset := boundedOffset(filter.Offset, total)
	limit := boundedLimit(filter.Limit)
	end := offset + limit
	if end > total {
		end = total
	}
	snapshot.Items = items[offset:end]
	snapshot.Total = total
	snapshot.Limit = limit
	snapshot.Offset = offset
	return snapshot
}

func boundedLimit(limit int) int {
	if limit <= 0 {
		return 100
	}
	if limit > 500 {
		return 500
	}
	return limit
}

func boundedOffset(offset int, total int) int {
	if offset <= 0 {
		return 0
	}
	if offset > total {
		return total
	}
	return offset
}
