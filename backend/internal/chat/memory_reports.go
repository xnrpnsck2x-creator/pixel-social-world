package chat

import (
	"context"
	"errors"
	"sort"
	"time"
)

func (s *MemoryService) Reports(_ context.Context, request ReportListRequest) (ReportDashboardSnapshot, error) {
	limit := normalizeReportLimit(request.Limit)
	s.mu.RLock()
	items := make([]Report, 0, len(s.reports))
	for _, report := range s.reports {
		if request.Status == "" || report.Status == request.Status {
			items = append(items, report)
		}
	}
	s.mu.RUnlock()
	sortReportsNewestFirst(items)
	if len(items) > limit {
		items = items[:limit]
	}
	return ReportDashboardSnapshot{GeneratedAt: time.Now().Unix(), Items: items}, nil
}

func (s *MemoryService) ReviewReport(_ context.Context, request ReportReviewRequest) (Report, error) {
	status, ok := normalizeReportStatus(request.Status)
	if !ok {
		return Report{}, errors.New("invalid_status")
	}
	if request.ReportID == "" {
		return Report{}, errors.New("report_required")
	}
	request.ReviewNote = truncateRunes(request.ReviewNote, maxReportReviewNoteLength)

	s.mu.Lock()
	defer s.mu.Unlock()
	for index := range s.reports {
		if s.reports[index].ID != request.ReportID {
			continue
		}
		s.reports[index].Status = status
		s.reports[index].ReviewerID = request.ReviewerID
		s.reports[index].ReviewSource = normalize(request.ReviewSource, "admin-api")
		s.reports[index].ReviewNote = request.ReviewNote
		s.reports[index].ReviewedAt = time.Now().Unix()
		return s.reports[index], nil
	}
	return Report{}, errors.New("report_not_found")
}

func normalizeReportLimit(limit int) int {
	if limit <= 0 || limit > 100 {
		return 50
	}
	return limit
}

func sortReportsNewestFirst(items []Report) {
	sort.Slice(items, func(left int, right int) bool {
		if items[left].CreatedAt == items[right].CreatedAt {
			return items[left].ID > items[right].ID
		}
		return items[left].CreatedAt > items[right].CreatedAt
	})
}
