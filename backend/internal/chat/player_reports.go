package chat

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const playerReportChannelID = "profile"
const playerReportBody = "player_profile_report"

type PlayerReportRequest struct {
	TargetPlayerID   string `json:"target_player_id"`
	TargetPlayerName string `json:"target_player_name"`
	ReporterID       string `json:"reporter_id"`
	Reason           string `json:"reason"`
	ContextRoomID    string `json:"context_room_id"`
}

func (s *MemoryService) ReportPlayer(_ context.Context, request PlayerReportRequest) (Report, error) {
	report, err := reportFromPlayerRequest(request)
	if err != nil {
		return Report{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	report.ID = fmt.Sprintf("report-%06d", len(s.reports)+1)
	s.reports = append(s.reports, report)
	return report, nil
}

func (s *GormService) ReportPlayer(ctx context.Context, request PlayerReportRequest) (Report, error) {
	report, err := reportFromPlayerRequest(request)
	if err != nil {
		return Report{}, err
	}
	return report, s.db.WithContext(ctx).Create(reportRecordFromReport(report)).Error
}

func reportFromPlayerRequest(request PlayerReportRequest) (Report, error) {
	request.TargetPlayerID = normalize(request.TargetPlayerID, "")
	request.TargetPlayerName = truncateRunes(normalize(request.TargetPlayerName, request.TargetPlayerID), 80)
	request.ReporterID = normalize(request.ReporterID, "")
	request.ContextRoomID = normalize(request.ContextRoomID, defaultRoomID)
	request.Reason = truncateRunes(normalize(request.Reason, "player_profile_report"), maxReportReasonLength)
	if request.TargetPlayerID == "" {
		return Report{}, errors.New("target_player_required")
	}
	if request.ReporterID == "" {
		return Report{}, errors.New("reporter_required")
	}
	if request.TargetPlayerID == request.ReporterID {
		return Report{}, errors.New("cannot_report_self")
	}
	now := time.Now().Unix()
	return Report{
		ID:                fmt.Sprintf("report-%d", time.Now().UnixNano()),
		MessageID:         fmt.Sprintf("profile:%s:%d", request.TargetPlayerID, time.Now().UnixNano()),
		RoomID:            request.ContextRoomID,
		ChannelID:         playerReportChannelID,
		ReporterID:        request.ReporterID,
		Reason:            request.Reason,
		Status:            ReportStatusOpen,
		MessageSenderID:   request.TargetPlayerID,
		MessageSenderName: request.TargetPlayerName,
		MessageBody:       playerReportBody,
		MessageCreatedAt:  now,
		CreatedAt:         now,
	}, nil
}
