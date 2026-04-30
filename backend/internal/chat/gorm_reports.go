package chat

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

func (s *GormService) Reports(ctx context.Context, request ReportListRequest) (ReportDashboardSnapshot, error) {
	var rows []ReportRecord
	query := s.db.WithContext(ctx).Order("created_at DESC").Limit(normalizeReportLimit(request.Limit))
	if request.Status != "" {
		query = query.Where("status = ?", request.Status)
	}
	if err := query.Find(&rows).Error; err != nil {
		return ReportDashboardSnapshot{}, err
	}
	items := make([]Report, 0, len(rows))
	for _, row := range rows {
		items = append(items, row.toReport())
	}
	return ReportDashboardSnapshot{GeneratedAt: time.Now().Unix(), Items: items}, nil
}

func (s *GormService) ReviewReport(ctx context.Context, request ReportReviewRequest) (Report, error) {
	status, ok := normalizeReportStatus(request.Status)
	if !ok {
		return Report{}, errors.New("invalid_status")
	}
	if request.ReportID == "" {
		return Report{}, errors.New("report_required")
	}
	var row ReportRecord
	err := s.db.WithContext(ctx).First(&row, "id = ?", request.ReportID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return Report{}, errors.New("report_not_found")
	}
	if err != nil {
		return Report{}, err
	}
	row.Status = status
	row.ReviewerID = request.ReviewerID
	row.ReviewSource = normalize(request.ReviewSource, "admin-api")
	row.ReviewNote = truncateRunes(request.ReviewNote, maxReportReviewNoteLength)
	row.ReviewedAt = time.Now().Unix()
	if err := s.db.WithContext(ctx).Save(&row).Error; err != nil {
		return Report{}, err
	}
	return row.toReport(), nil
}

func (s *GormService) Stats(ctx context.Context) Stats {
	stats := Stats{
		RejectedRateLimited: s.rejectedRateLimitedCount(),
		ByRoom:              map[string]int{},
		ByChannel:           map[string]int{},
		ReportsByRoom:       map[string]int{},
	}
	stats.TotalMessages = int(countRows(ctx, s.db, &MessageRecord{}))
	stats.TotalReports = int(countRows(ctx, s.db, &ReportRecord{}))
	stats.ModerationActions = int(countRows(ctx, s.db, &ModerationActionRecord{}))
	stats.ActiveModeration = s.activeModerationCount(ctx)
	loadMessageGroups(ctx, s.db, "room_id", stats.ByRoom)
	loadMessageGroups(ctx, s.db, "channel_id", stats.ByChannel)
	loadReportGroups(ctx, s.db, "room_id", stats.ReportsByRoom)
	s.addTransientMessageStats(&stats)
	return stats
}

func (s *GormService) addTransientMessageStats(stats *Stats) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for key, messages := range s.transientMessages {
		roomID, channelID := splitMessageKey(key)
		count := len(messages)
		stats.TotalMessages += count
		stats.ByRoom[roomID] += count
		stats.ByChannel[channelID] += count
	}
}

func (s *GormService) rejectedRateLimitedCount() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.rejectedRateLimited
}

func countRows(ctx context.Context, db *gorm.DB, model any) int64 {
	var count int64
	_ = db.WithContext(ctx).Model(model).Count(&count).Error
	return count
}

func loadMessageGroups(ctx context.Context, db *gorm.DB, column string, target map[string]int) {
	var rows []groupCount
	_ = db.WithContext(ctx).Model(&MessageRecord{}).
		Select(column + " as key, count(*) as count").
		Group(column).
		Scan(&rows).Error
	for _, row := range rows {
		target[row.Key] = row.Count
	}
}

func loadReportGroups(ctx context.Context, db *gorm.DB, column string, target map[string]int) {
	var rows []groupCount
	_ = db.WithContext(ctx).Model(&ReportRecord{}).
		Select(column + " as key, count(*) as count").
		Group(column).
		Scan(&rows).Error
	for _, row := range rows {
		target[row.Key] = row.Count
	}
}

type groupCount struct {
	Key   string
	Count int
}
