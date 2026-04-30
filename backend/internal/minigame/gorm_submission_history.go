package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type SubmissionVersionRecord struct {
	GameID      string `gorm:"primaryKey;size:120"`
	Version     string `gorm:"primaryKey;size:40"`
	Author      string `gorm:"index;size:120"`
	Status      string `gorm:"index;size:40"`
	RecordJSON  string
	CreatedUnix int64
	UpdatedUnix int64
}

func (s *GormSubmissionService) SubmissionHistory(
	ctx context.Context,
	id string,
) (SubmissionHistorySnapshot, error) {
	var rows []SubmissionVersionRecord
	if err := s.db.WithContext(ctx).Where("game_id = ?", id).Find(&rows).Error; err != nil {
		return SubmissionHistorySnapshot{}, err
	}
	items := make([]SubmissionVersionSnapshot, 0, len(rows))
	for _, row := range rows {
		item, err := row.toSnapshot()
		if err != nil {
			continue
		}
		items = append(items, item)
	}
	sortSubmissionVersions(items)
	return SubmissionHistorySnapshot{GameID: id, Items: items}, nil
}

func saveSubmissionVersionTx(tx *gorm.DB, record Record) error {
	row, err := submissionVersionRowFromRecord(record)
	if err != nil {
		return err
	}
	var existing SubmissionVersionRecord
	err = tx.First(&existing, "game_id = ? AND version = ?", row.GameID, row.Version).Error
	if err == nil && existing.CreatedUnix > 0 {
		row.CreatedUnix = existing.CreatedUnix
	} else if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}
	return tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "game_id"}, {Name: "version"}},
		UpdateAll: true,
	}).Create(&row).Error
}

func submissionVersionRowFromRecord(record Record) (SubmissionVersionRecord, error) {
	encoded, err := json.Marshal(cloneRecord(record))
	if err != nil {
		return SubmissionVersionRecord{}, err
	}
	now := time.Now().Unix()
	return SubmissionVersionRecord{
		GameID:      record.GameID,
		Version:     submissionVersionKey(record.Version),
		Author:      record.Author,
		Status:      record.Status,
		RecordJSON:  string(encoded),
		CreatedUnix: now,
		UpdatedUnix: now,
	}, nil
}

func (r SubmissionVersionRecord) toSnapshot() (SubmissionVersionSnapshot, error) {
	var record Record
	if err := json.Unmarshal([]byte(r.RecordJSON), &record); err != nil {
		return SubmissionVersionSnapshot{}, err
	}
	return SubmissionVersionSnapshot{
		GameID:      r.GameID,
		Version:     record.Version,
		Author:      r.Author,
		Status:      r.Status,
		CreatedUnix: r.CreatedUnix,
		UpdatedUnix: r.UpdatedUnix,
		Record:      cloneRecord(record),
	}, nil
}
