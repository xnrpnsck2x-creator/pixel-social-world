package chat

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type ModerationActionRecord struct {
	ID               string `gorm:"primaryKey;size:180"`
	TargetPlayerID   string `gorm:"index;size:120"`
	TargetName       string `gorm:"size:80"`
	Action           string `gorm:"index;size:40"`
	Scope            string `gorm:"index;size:40"`
	RoomID           string `gorm:"index;size:120"`
	Reason           string `gorm:"type:text"`
	ReportID         string `gorm:"index;size:180"`
	ModeratorID      string `gorm:"size:80"`
	Source           string `gorm:"size:80"`
	RequestID        string `gorm:"size:100"`
	CreatedAt        int64  `gorm:"index"`
	ExpiresAt        int64  `gorm:"index"`
	RevokedAt        int64  `gorm:"index"`
	RevokedBy        string `gorm:"size:80"`
	RevocationReason string `gorm:"type:text"`
}

func (s *GormService) ApplyModeration(ctx context.Context, request ModerationActionRequest) (ModerationAction, error) {
	request, err := normalizeModerationRequest(request)
	if err != nil {
		return ModerationAction{}, err
	}
	now := nowUnix()
	action := moderationActionFromRequest(request, now, int(time.Now().UnixNano()%1000000))
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if request.Action == ModerationActionRestore {
			if err := revokeGormModeration(tx, request, now); err != nil {
				return err
			}
		}
		return tx.Create(moderationRecordFromAction(action)).Error
	})
	return action, err
}

func (s *GormService) ModerationActions(ctx context.Context, request ModerationListRequest) (ModerationSnapshot, error) {
	limit := moderationListLimit(request.Limit)
	offset := moderationListOffset(request.Offset)
	now := nowUnix()
	active, err := s.loadModeration(ctx, request, limit, 0, true, now)
	if err != nil {
		return ModerationSnapshot{}, err
	}
	recent, err := s.loadModeration(ctx, request, limit, offset, false, now)
	if err != nil {
		return ModerationSnapshot{}, err
	}
	return ModerationSnapshot{GeneratedAt: now, Active: active, Recent: recent, Limit: limit, Offset: offset}, nil
}

func (s *GormService) activeRestriction(ctx context.Context, playerID string, roomID string) (ModerationAction, bool) {
	var row ModerationActionRecord
	now := nowUnix()
	err := activeModerationQuery(s.db.WithContext(ctx), playerID, roomID, now).
		Order("created_at DESC").
		First(&row).Error
	if err != nil {
		return ModerationAction{}, false
	}
	return row.toModerationAction(), true
}

func (s *GormService) activeModerationCount(ctx context.Context) int {
	var count int64
	now := nowUnix()
	_ = s.db.WithContext(ctx).Model(&ModerationActionRecord{}).
		Where("action IN ?", []string{ModerationActionMute, ModerationActionBan}).
		Where("revoked_at = 0").
		Where("expires_at = 0 OR expires_at > ?", now).
		Count(&count).Error
	return int(count)
}

func (s *GormService) loadModeration(
	ctx context.Context,
	request ModerationListRequest,
	limit int,
	offset int,
	activeOnly bool,
	now int64,
) ([]ModerationAction, error) {
	var rows []ModerationActionRecord
	query := s.db.WithContext(ctx).Order("created_at DESC").Limit(limit).Offset(offset)
	if request.TargetPlayerID != "" {
		query = query.Where("target_player_id = ?", request.TargetPlayerID)
	}
	if request.Action != "" {
		query = query.Where("action = ?", request.Action)
	}
	if activeOnly {
		query = query.Where("action IN ?", []string{ModerationActionMute, ModerationActionBan}).
			Where("revoked_at = 0").
			Where("expires_at = 0 OR expires_at > ?", now)
	}
	if err := query.Find(&rows).Error; err != nil {
		return nil, err
	}
	items := make([]ModerationAction, 0, len(rows))
	for _, row := range rows {
		items = append(items, row.toModerationAction())
	}
	return items, nil
}

func revokeGormModeration(tx *gorm.DB, request ModerationActionRequest, now int64) error {
	query := tx.Model(&ModerationActionRecord{}).
		Where("target_player_id = ?", request.TargetPlayerID).
		Where("action IN ?", []string{ModerationActionMute, ModerationActionBan}).
		Where("revoked_at = 0").
		Where("expires_at = 0 OR expires_at > ?", now)
	if request.Scope == ModerationScopeRoom {
		query = query.Where("room_id = ? OR scope = ?", request.RoomID, ModerationScopeGlobal)
	}
	return query.Updates(map[string]any{
		"revoked_at":        now,
		"revoked_by":        request.ModeratorID,
		"revocation_reason": request.Reason,
	}).Error
}

func activeModerationQuery(db *gorm.DB, playerID string, roomID string, now int64) *gorm.DB {
	return db.Where("target_player_id = ?", playerID).
		Where("action IN ?", []string{ModerationActionMute, ModerationActionBan}).
		Where("revoked_at = 0").
		Where("expires_at = 0 OR expires_at > ?", now).
		Where("scope = ? OR room_id = ?", ModerationScopeGlobal, roomID)
}

func moderationRecordFromAction(action ModerationAction) *ModerationActionRecord {
	return &ModerationActionRecord{
		ID:               action.ID,
		TargetPlayerID:   action.TargetPlayerID,
		TargetName:       action.TargetName,
		Action:           action.Action,
		Scope:            action.Scope,
		RoomID:           action.RoomID,
		Reason:           action.Reason,
		ReportID:         action.ReportID,
		ModeratorID:      action.ModeratorID,
		Source:           action.Source,
		RequestID:        action.RequestID,
		CreatedAt:        action.CreatedAt,
		ExpiresAt:        action.ExpiresAt,
		RevokedAt:        action.RevokedAt,
		RevokedBy:        action.RevokedBy,
		RevocationReason: action.RevocationReason,
	}
}

func (row ModerationActionRecord) toModerationAction() ModerationAction {
	return ModerationAction{
		ID:               row.ID,
		TargetPlayerID:   row.TargetPlayerID,
		TargetName:       row.TargetName,
		Action:           row.Action,
		Scope:            row.Scope,
		RoomID:           row.RoomID,
		Reason:           row.Reason,
		ReportID:         row.ReportID,
		ModeratorID:      row.ModeratorID,
		Source:           row.Source,
		RequestID:        row.RequestID,
		CreatedAt:        row.CreatedAt,
		ExpiresAt:        row.ExpiresAt,
		RevokedAt:        row.RevokedAt,
		RevokedBy:        row.RevokedBy,
		RevocationReason: row.RevocationReason,
	}
}
