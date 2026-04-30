package minigame

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type ReviewAuditRecord struct {
	ID          string `gorm:"primaryKey;size:180"`
	GameID      string `gorm:"index;size:120"`
	Action      string `gorm:"index;size:40"`
	Status      string `gorm:"index;size:40"`
	Reviewer    string `gorm:"size:80"`
	Source      string `gorm:"size:80"`
	Note        string `gorm:"type:text"`
	RequestID   string `gorm:"size:100"`
	CreatedUnix int64  `gorm:"index"`
}

func (s *GormSubmissionService) RecordReviewAudit(
	ctx context.Context,
	event ReviewAuditEvent,
) error {
	event = normalizeReviewAuditEvent(event)
	return s.db.WithContext(ctx).Create(reviewAuditRowFromEvent(event)).Error
}

func (s *GormSubmissionService) ReviewAudit(
	ctx context.Context,
	gameID string,
) (ReviewAuditSnapshot, error) {
	var rows []ReviewAuditRecord
	err := s.db.WithContext(ctx).
		Where("game_id = ?", gameID).
		Order("created_unix asc, id asc").
		Find(&rows).Error
	if err != nil {
		return ReviewAuditSnapshot{}, err
	}
	items := make([]ReviewAuditEvent, 0, len(rows))
	for _, row := range rows {
		items = append(items, row.toEvent())
	}
	return ReviewAuditSnapshot{GameID: gameID, Items: items, Total: len(items)}, nil
}

func reviewAuditRowFromEvent(event ReviewAuditEvent) *ReviewAuditRecord {
	if event.CreatedUnix <= 0 {
		event.CreatedUnix = time.Now().Unix()
	}
	return &ReviewAuditRecord{
		ID:          event.ID,
		GameID:      event.GameID,
		Action:      event.Action,
		Status:      event.Status,
		Reviewer:    event.Reviewer,
		Source:      event.Source,
		Note:        event.Note,
		RequestID:   event.RequestID,
		CreatedUnix: event.CreatedUnix,
	}
}

func (r ReviewAuditRecord) toEvent() ReviewAuditEvent {
	return ReviewAuditEvent{
		ID:          r.ID,
		GameID:      r.GameID,
		Action:      r.Action,
		Status:      r.Status,
		Reviewer:    r.Reviewer,
		Source:      r.Source,
		Note:        r.Note,
		RequestID:   r.RequestID,
		CreatedUnix: r.CreatedUnix,
	}
}

func reviewAuditIgnoreDuplicate(err error) error {
	if err == nil || err == gorm.ErrDuplicatedKey {
		return nil
	}
	return err
}
