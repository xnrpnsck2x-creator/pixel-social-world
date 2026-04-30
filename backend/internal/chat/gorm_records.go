package chat

import (
	"fmt"
	"time"
)

func messageRecordFromMessage(message Message) *MessageRecord {
	return &MessageRecord{
		ID:         message.ID,
		RoomID:     message.RoomID,
		ChannelID:  message.ChannelID,
		SenderID:   message.SenderID,
		SenderName: message.SenderName,
		Body:       message.Body,
		CreatedAt:  message.CreatedAt,
		ActionJSON: encodeAction(message.Action),
	}
}

func (row MessageRecord) toMessage() Message {
	return Message{
		ID:         row.ID,
		RoomID:     row.RoomID,
		ChannelID:  row.ChannelID,
		SenderID:   row.SenderID,
		SenderName: row.SenderName,
		Body:       row.Body,
		CreatedAt:  row.CreatedAt,
		Action:     decodeAction(row.ActionJSON),
	}
}

func reportFromMessage(request ReportRequest, message Message) Report {
	return Report{
		ID:                fmt.Sprintf("report-%d", time.Now().UnixNano()),
		MessageID:         request.MessageID,
		RoomID:            request.RoomID,
		ChannelID:         request.ChannelID,
		ReporterID:        request.ReporterID,
		Reason:            request.Reason,
		Status:            ReportStatusOpen,
		MessageSenderID:   message.SenderID,
		MessageSenderName: message.SenderName,
		MessageBody:       message.Body,
		MessageCreatedAt:  message.CreatedAt,
		CreatedAt:         time.Now().Unix(),
	}
}

func reportRecordFromReport(report Report) *ReportRecord {
	return &ReportRecord{
		ID:                report.ID,
		MessageID:         report.MessageID,
		RoomID:            report.RoomID,
		ChannelID:         report.ChannelID,
		ReporterID:        report.ReporterID,
		Reason:            report.Reason,
		Status:            report.Status,
		MessageSenderID:   report.MessageSenderID,
		MessageSenderName: report.MessageSenderName,
		MessageBody:       report.MessageBody,
		MessageCreatedAt:  report.MessageCreatedAt,
		ReviewerID:        report.ReviewerID,
		ReviewSource:      report.ReviewSource,
		ReviewNote:        report.ReviewNote,
		ReviewedAt:        report.ReviewedAt,
		CreatedAt:         report.CreatedAt,
	}
}

func (row ReportRecord) toReport() Report {
	return Report{
		ID:                row.ID,
		MessageID:         row.MessageID,
		RoomID:            row.RoomID,
		ChannelID:         row.ChannelID,
		ReporterID:        row.ReporterID,
		Reason:            row.Reason,
		Status:            row.Status,
		MessageSenderID:   row.MessageSenderID,
		MessageSenderName: row.MessageSenderName,
		MessageBody:       row.MessageBody,
		MessageCreatedAt:  row.MessageCreatedAt,
		ReviewerID:        row.ReviewerID,
		ReviewSource:      row.ReviewSource,
		ReviewNote:        row.ReviewNote,
		ReviewedAt:        row.ReviewedAt,
		CreatedAt:         row.CreatedAt,
	}
}
