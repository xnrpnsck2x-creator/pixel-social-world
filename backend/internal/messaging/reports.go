package messaging

import (
	"errors"
	"strings"
	"time"
)

type PrivateReportRequest struct {
	MessageID  string `json:"message_id"`
	ReporterID string `json:"reporter_id"`
	Reason     string `json:"reason"`
}

type PrivateReport struct {
	ID                 string `json:"id"`
	MessageID          string `json:"message_id"`
	ReporterID         string `json:"reporter_id"`
	Reason             string `json:"reason"`
	Status             string `json:"status"`
	MessageSenderID    string `json:"message_sender_id"`
	MessageRecipientID string `json:"message_recipient_id"`
	MessageBody        string `json:"message_body"`
	MessageCreatedAt   int64  `json:"message_created_at"`
	CreatedAt          int64  `json:"created_at"`
}

func normalizePrivateReportRequest(request PrivateReportRequest) (PrivateReportRequest, error) {
	request.MessageID = strings.TrimSpace(request.MessageID)
	request.ReporterID = strings.TrimSpace(request.ReporterID)
	request.Reason = strings.TrimSpace(request.Reason)
	if request.MessageID == "" || request.ReporterID == "" {
		return request, errors.New("private_report_required")
	}
	if request.Reason == "" {
		request.Reason = "player_report"
	}
	return request, nil
}

func privateReportFromMessage(request PrivateReportRequest, message PrivateMessage) PrivateReport {
	return PrivateReport{
		ID:                 newID("pm-report"),
		MessageID:          request.MessageID,
		ReporterID:         request.ReporterID,
		Reason:             request.Reason,
		Status:             "open",
		MessageSenderID:    message.SenderID,
		MessageRecipientID: message.RecipientID,
		MessageBody:        message.Body,
		MessageCreatedAt:   message.CreatedAt,
		CreatedAt:          time.Now().Unix(),
	}
}

func participantCanReport(message PrivateMessage, reporterID string) bool {
	return message.SenderID == reporterID || message.RecipientID == reporterID
}
