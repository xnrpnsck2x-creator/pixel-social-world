package messaging

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

type PrivateReportRecord struct {
	ID                 string `gorm:"primaryKey;size:120"`
	MessageID          string `gorm:"index;size:120"`
	ReporterID         string `gorm:"index;size:80"`
	Reason             string `gorm:"size:120"`
	Status             string `gorm:"index;size:40"`
	MessageSenderID    string `gorm:"index;size:80"`
	MessageRecipientID string `gorm:"index;size:80"`
	MessageBody        string `gorm:"type:text"`
	MessageCreatedUnix int64
	CreatedUnix        int64
	CreatedAt          time.Time
}

func (s *GormService) ReportPrivate(ctx context.Context, request PrivateReportRequest) (PrivateReport, error) {
	normalized, err := normalizePrivateReportRequest(request)
	if err != nil {
		return PrivateReport{}, err
	}
	var record PrivateMessageRecord
	err = s.db.WithContext(ctx).First(&record, "id = ?", normalized.MessageID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return PrivateReport{}, errors.New("private_message_not_found")
	}
	if err != nil {
		return PrivateReport{}, err
	}
	message := record.toPrivateMessage()
	if !participantCanReport(message, normalized.ReporterID) {
		return PrivateReport{}, errors.New("private_message_forbidden")
	}
	reportRecord := privateReportRecordFromReport(privateReportFromMessage(normalized, message))
	if err := s.db.WithContext(ctx).Create(reportRecord).Error; err != nil {
		return PrivateReport{}, err
	}
	return reportRecord.toPrivateReport(), nil
}

func privateReportRecordFromReport(report PrivateReport) *PrivateReportRecord {
	return &PrivateReportRecord{
		ID:                 report.ID,
		MessageID:          report.MessageID,
		ReporterID:         report.ReporterID,
		Reason:             report.Reason,
		Status:             report.Status,
		MessageSenderID:    report.MessageSenderID,
		MessageRecipientID: report.MessageRecipientID,
		MessageBody:        report.MessageBody,
		MessageCreatedUnix: report.MessageCreatedAt,
		CreatedUnix:        report.CreatedAt,
	}
}

func (row PrivateReportRecord) toPrivateReport() PrivateReport {
	return PrivateReport{
		ID:                 row.ID,
		MessageID:          row.MessageID,
		ReporterID:         row.ReporterID,
		Reason:             row.Reason,
		Status:             row.Status,
		MessageSenderID:    row.MessageSenderID,
		MessageRecipientID: row.MessageRecipientID,
		MessageBody:        row.MessageBody,
		MessageCreatedAt:   row.MessageCreatedUnix,
		CreatedAt:          row.CreatedUnix,
	}
}
