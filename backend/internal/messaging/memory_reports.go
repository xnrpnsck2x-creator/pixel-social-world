package messaging

import (
	"context"
	"errors"
)

func (s *MemoryService) ReportPrivate(ctx context.Context, request PrivateReportRequest) (PrivateReport, error) {
	if err := ctx.Err(); err != nil {
		return PrivateReport{}, err
	}
	normalized, err := normalizePrivateReportRequest(request)
	if err != nil {
		return PrivateReport{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, message := range s.private {
		if message.ID != normalized.MessageID {
			continue
		}
		if !participantCanReport(message, normalized.ReporterID) {
			return PrivateReport{}, errors.New("private_message_forbidden")
		}
		report := privateReportFromMessage(normalized, message)
		s.privateReports = append(s.privateReports, report)
		return report, nil
	}
	return PrivateReport{}, errors.New("private_message_not_found")
}
